import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../domain/models/appointment.dart';
import 'api_service.dart';

/// Servicio de sincronización entre almacenamiento local y la API.
///
/// Estrategia:
/// 1. Al abrir la app → fullSync (push local + pull servidor).
/// 2. Mientras la app está abierta → `Timer.periodic` cada 5 min.
/// 3. Si la red cambia de offline → online → fullSync inmediato.
/// 4. Antes de procesar la cola se **compacta** para evitar inconsistencias
///    (ej. CREATE + DELETE del mismo localId se cancelan mutuamente).
class SyncService {
  final NotificationService notificationService;

  SyncService({required this.notificationService});

  static const String _pendingQueueKey = 'appointments_pending_sync';
  static const String _appointmentsCacheKey = 'appointments_cache';

  /// Intervalo del timer periódico.
  static const Duration _syncInterval = Duration(minutes: 5);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  bool _isSyncing = false;
  bool _initialSyncDone = false;

  // ---------------------------------------------------------------------------
  // Inicialización / dispose
  // ---------------------------------------------------------------------------

  /// Inicia la escucha de conectividad + timer periódico + sync inmediato.
  void startListening() {
    // --- Escucha de cambios de red ---
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        // Ignorar el primer evento (estado actual al suscribirse),
        // ya que el sync inmediato al arrancar ya lo cubre.
        if (!_initialSyncDone) {
          _initialSyncDone = true;
          return;
        }

        final hasConnection = results.any(
          (r) => r != ConnectivityResult.none,
        );
        if (hasConnection) {
          debugPrint('🌐 Red disponible → fullSync');
          fullSync();
        }
      },
    );

    // --- Timer periódico (cada 5 min mientras la app está abierta) ---
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_syncInterval, (_) {
      debugPrint('⏰ Timer periódico → fullSync');
      fullSync();
    });

    // --- Sync inmediato al arrancar ---
    fullSync();

    debugPrint('📡 SyncService: escuchando red + timer cada ${_syncInterval.inMinutes} min');
  }

  /// Detiene escucha de red y timer periódico.
  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Cola de pendientes
  // ---------------------------------------------------------------------------

  /// Encola una operación que no pudo sincronizarse con la API.
  Future<void> enqueue({
    required String action,
    required String localId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey);
      final List<dynamic> queue = raw != null ? json.decode(raw) : [];
      queue.add({
        'action': action,        // 'create' | 'update' | 'delete'
        'localId': localId,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_pendingQueueKey, json.encode(queue));
      debugPrint('📋 Operación encolada ($action) para cita $localId');
    } catch (e) {
      debugPrint('❌ Error al encolar operación pendiente: $e');
    }
  }

  /// Elimina de la cola todas las operaciones pendientes para un [localId].
  ///
  /// Se usa cuando se elimina localmente una cita que nunca llegó al servidor
  /// (sin serverId), para limpiar cualquier CREATE/UPDATE pendiente.
  Future<void> purgeLocalId(String localId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> queue = json.decode(raw);
      final before = queue.length;
      queue.removeWhere((op) => (op as Map<String, dynamic>)['localId'] == localId);

      if (queue.length < before) {
        if (queue.isEmpty) {
          await prefs.remove(_pendingQueueKey);
        } else {
          await prefs.setString(_pendingQueueKey, json.encode(queue));
        }
        debugPrint('🧹 Purgadas ${before - queue.length} operación(es) pendientes '
            'de cita $localId');
      }
    } catch (e) {
      debugPrint('❌ Error al purgar cola para $localId: $e');
    }
  }

  /// Procesa todas las operaciones pendientes de la cola.
  ///
  /// Flujo:
  /// 1. Lee la cola de SharedPreferences.
  /// 2. **Compacta** para eliminar operaciones redundantes/contradictorias.
  /// 3. Ejecuta cada operación restante contra la API (en orden).
  /// 4. Las que fallan se mantienen para el siguiente ciclo.
  Future<void> syncPendingQueue() async {
    if (_isSyncing) return; // Evitar ejecuciones simultáneas
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey);
      if (raw == null || raw.isEmpty) {
        _isSyncing = false;
        return;
      }

      List<dynamic> queue = json.decode(raw);
      if (queue.isEmpty) {
        _isSyncing = false;
        return;
      }

      // ── Compactar la cola antes de procesar ──
      queue = _compactQueue(queue.cast<Map<String, dynamic>>());

      if (queue.isEmpty) {
        await prefs.remove(_pendingQueueKey);
        debugPrint('✅ Cola compactada quedó vacía, nada que sincronizar');
        _isSyncing = false;
        return;
      }

      debugPrint('🔄 Procesando ${queue.length} operaciones pendientes…');

      final List<Map<String, dynamic>> remaining = [];

      for (final item in queue) {
        final op = item as Map<String, dynamic>;
        final action = op['action'] as String;
        final localId = op['localId'] as String;
        final payload = Map<String, dynamic>.from(op['payload'] as Map);

        try {
          switch (action) {
            case 'create':
              final response = await ApiService.createAppointment(payload);
              final serverId = response['id'] as int?;
              if (serverId != null) {
                await _updateLocalServerId(localId, serverId);
              }
              debugPrint('✅ Pendiente CREATE sincronizado (serverId: $serverId)');
              break;

            case 'update':
              final serverId = await _resolveServerId(localId, payload);
              if (serverId != null) {
                payload.remove('serverId');
                await ApiService.updateAppointment(serverId, payload);
                debugPrint('✅ Pendiente UPDATE sincronizado (serverId: $serverId)');
              } else {
                debugPrint('⚠️ No se pudo resolver serverId para UPDATE de $localId');
                remaining.add(op);
              }
              break;

            case 'delete':
              final serverId = payload['serverId'] as int?;
              if (serverId != null) {
                await ApiService.deleteAppointment(serverId);
                debugPrint('✅ Pendiente DELETE sincronizado (serverId: $serverId)');
              } else {
                // serverId null → la cita nunca llegó al servidor y ya fue
                // eliminada localmente. Nada que hacer.
                debugPrint('ℹ️ DELETE sin serverId → ignorado (nunca existió en servidor)');
              }
              break;

            default:
              debugPrint('⚠️ Acción desconocida en cola: $action');
          }
        } on DioException catch (e) {
          debugPrint('⚠️ Reintento fallido ($action): ${e.message}');
          remaining.add(op);
        } catch (e) {
          debugPrint('⚠️ Error inesperado en reintento ($action): $e');
          remaining.add(op);
        }
      }

      // Guardar solo las operaciones que siguen fallando
      if (remaining.isEmpty) {
        await prefs.remove(_pendingQueueKey);
        debugPrint('✅ Cola de pendientes vacía');
      } else {
        await prefs.setString(_pendingQueueKey, json.encode(remaining));
        debugPrint('📋 ${remaining.length} operaciones aún pendientes');
      }
    } catch (e) {
      debugPrint('❌ Error general al procesar cola pendiente: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Cantidad de operaciones pendientes en la cola.
  Future<int> get pendingCount async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingQueueKey);
    if (raw == null) return 0;
    final List<dynamic> queue = json.decode(raw);
    return queue.length;
  }

  // ---------------------------------------------------------------------------
  // Compactación de cola
  // ---------------------------------------------------------------------------

  /// Reduce la cola eliminando operaciones redundantes o contradictorias.
  ///
  /// Reglas (se evalúan por `localId`):
  ///
  /// | Cola contiene               | Resultado                              |
  /// |-----------------------------|----------------------------------------|
  /// | CREATE  → DELETE            | Ambas se eliminan (nunca existió)      |
  /// | CREATE  → UPDATE(s)         | Se fusionan en un solo CREATE          |
  /// | UPDATE  → UPDATE            | Se fusionan en un solo UPDATE          |
  /// | CREATE  → UPDATE(s) → DELETE| Todas se eliminan                      |
  /// | DELETE (suelto)             | Se mantiene tal cual                   |
  ///
  /// El orden de la cola se respeta: las operaciones se procesan por `localId`
  /// y se reconstruyen en el orden original del primer item de cada grupo.
  List<Map<String, dynamic>> _compactQueue(List<Map<String, dynamic>> queue) {
    // Agrupar por localId preservando orden de aparición
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final List<String> insertionOrder = [];

    for (final op in queue) {
      final localId = op['localId'] as String;
      if (!groups.containsKey(localId)) {
        groups[localId] = [];
        insertionOrder.add(localId);
      }
      groups[localId]!.add(op);
    }

    final List<Map<String, dynamic>> compacted = [];

    for (final localId in insertionOrder) {
      final ops = groups[localId]!;
      final actions = ops.map((o) => o['action'] as String).toList();

      // ¿Contiene un DELETE?
      final hasDelete = actions.contains('delete');
      // ¿Empieza con CREATE?
      final startsWithCreate = actions.first == 'create';

      if (startsWithCreate && hasDelete) {
        // CREATE → ... → DELETE: la cita se creó y se borró offline
        // → no enviar nada al servidor.
        debugPrint('🗑️ Compactación: CREATE+DELETE cancelados para $localId');
        continue;
      }

      if (startsWithCreate) {
        // CREATE → UPDATE(s): fusionar los UPDATE en el payload del CREATE.
        final createOp = Map<String, dynamic>.from(ops.first);
        final createPayload = Map<String, dynamic>.from(createOp['payload'] as Map);

        for (int i = 1; i < ops.length; i++) {
          if (ops[i]['action'] == 'update') {
            final updatePayload = Map<String, dynamic>.from(ops[i]['payload'] as Map);
            createPayload.addAll(updatePayload);
          }
        }

        createOp['payload'] = createPayload;
        compacted.add(createOp);
        debugPrint('🔀 Compactación: CREATE + ${ops.length - 1} UPDATE(s) fusionados para $localId');
        continue;
      }

      if (!hasDelete && actions.every((a) => a == 'update')) {
        // UPDATE → UPDATE(s): fusionar en un solo UPDATE.
        final firstOp = Map<String, dynamic>.from(ops.first);
        final mergedPayload = Map<String, dynamic>.from(firstOp['payload'] as Map);

        for (int i = 1; i < ops.length; i++) {
          final updatePayload = Map<String, dynamic>.from(ops[i]['payload'] as Map);
          mergedPayload.addAll(updatePayload);
        }

        firstOp['payload'] = mergedPayload;
        compacted.add(firstOp);
        if (ops.length > 1) {
          debugPrint('🔀 Compactación: ${ops.length} UPDATEs fusionados para $localId');
        }
        continue;
      }

      // Para cualquier otro caso, mantener las operaciones tal cual
      compacted.addAll(ops);
    }

    if (compacted.length != queue.length) {
      debugPrint('📦 Cola compactada: ${queue.length} → ${compacted.length} operaciones');
    }

    return compacted;
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  /// Actualiza el `serverId` de una cita local después de que el backend
  /// la creó exitosamente.
  Future<void> _updateLocalServerId(String localId, int serverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appointmentsCacheKey);
      if (raw == null) return;

      final List<dynamic> list = json.decode(raw);
      bool updated = false;

      for (int i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        if (item['id'] == localId) {
          item['serverId'] = serverId;
          updated = true;
          break;
        }
      }

      if (updated) {
        await prefs.setString(_appointmentsCacheKey, json.encode(list));
        debugPrint('💾 serverId $serverId guardado para cita local $localId');
      }
    } catch (e) {
      debugPrint('❌ Error actualizando serverId local: $e');
    }
  }

  /// Intenta resolver el `serverId` de una cita local.
  Future<int?> _resolveServerId(
    String localId,
    Map<String, dynamic> payload,
  ) async {
    // 1. Buscar en el payload
    if (payload.containsKey('serverId')) {
      return payload['serverId'] as int?;
    }

    // 2. Buscar en el caché local
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appointmentsCacheKey);
      if (raw != null) {
        final List<dynamic> list = json.decode(raw);
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          if (map['id'] == localId && map['serverId'] != null) {
            return map['serverId'] as int;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // ---------------------------------------------------------------------------
  // Full sync: push + pull
  // ---------------------------------------------------------------------------

  /// Ejecuta una sincronización completa:
  /// 1. **Push** — vacía la cola de pendientes (local → servidor).
  /// 2. **Pull** — descarga citas del servidor y las fusiona con las locales.
  Future<void> fullSync() async {
    await syncPendingQueue();
    await pullFromServer();
  }

  // ---------------------------------------------------------------------------
  // Pull: descargar citas del servidor
  // ---------------------------------------------------------------------------

  /// Descarga las citas del servidor y las fusiona con el caché local.
  ///
  /// Reglas de merge:
  /// - Cita existe en servidor y local (mismo serverId) → actualiza la local
  ///   con los datos del servidor (server-wins).
  /// - Cita existe solo en servidor → la agrega localmente.
  /// - Cita existe solo en local sin serverId → la mantiene (aún no se
  ///   sincronizó, está en cola pendiente).
  /// - Cita existe solo en local con serverId → fue eliminada desde el
  ///   servidor/admin → la elimina localmente.
  Future<void> pullFromServer() async {
    try {
      // Delta sync: solo traer citas desde hoy a las 00:00 local
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final serverList = await ApiService.getAppointments(after: today);
      debugPrint('📥 GET /appointments?after=${today.toUtc().toIso8601String()} '
          '→ ${serverList.length} citas del servidor');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appointmentsCacheKey);
      final List<Appointment> localList = (raw != null && raw.isNotEmpty)
          ? (json.decode(raw) as List<dynamic>)
              .map((j) => Appointment.fromJson(j as Map<String, dynamic>))
              .toList()
          : [];

      // Mapas de lookup
      final Map<int, Appointment> localByServerId = {};
      final List<Appointment> localWithoutServerId = [];
      for (final a in localList) {
        if (a.serverId != null) {
          localByServerId[a.serverId!] = a;
        } else {
          localWithoutServerId.add(a);
        }
      }

      final Set<int> serverIds = {};
      final List<Appointment> merged = [];

      // 1. Procesar citas del servidor
      for (final serverJson in serverList) {
        final sId = serverJson['id'] as int;
        serverIds.add(sId);

        // Si el servidor marca la cita como "deleted", eliminarla localmente
        final serverStatus = (serverJson['status'] as String?)?.toLowerCase();
        if (serverStatus == 'deleted') {
          final localMatch = localByServerId[sId];
          if (localMatch != null) {
            debugPrint('🗑️ Cita local ${localMatch.id} (serverId: $sId) '
                'eliminada: status "deleted" en servidor');
            // Cancelar notificación de la cita eliminada
            await notificationService.cancelAppointmentReminder(localMatch.id);
          }
          continue;
        }

        final serverAppointment = Appointment.fromApiJson(serverJson);

        final localMatch = localByServerId[sId];
        if (localMatch != null) {
          // Existe local → actualizar con datos del servidor (conservar id local)
          final updatedLocal = serverAppointment.copyWith(id: localMatch.id);
          merged.add(updatedLocal);
          // Reprogramar notificación si la fecha/hora cambió
          if (localMatch.dateTime != serverAppointment.dateTime) {
            await notificationService.rescheduleAppointmentReminder(updatedLocal);
            debugPrint('🔔 Notificación reprogramada para cita ${localMatch.id}');
          }
        } else {
          // Solo en servidor → agregar como nueva + programar notificación
          merged.add(serverAppointment);
          await notificationService.scheduleAppointmentReminder(serverAppointment);
          debugPrint('🔔 Notificación programada para nueva cita ${serverAppointment.id}');
        }
      }

      // 2. Mantener citas locales que aún no tienen serverId
      //    (aún no se sincronizaron, probablemente en cola pendiente)
      merged.addAll(localWithoutServerId);

      // 3. Citas locales con serverId que NO vinieron en la respuesta
      //    → con delta sync puede ser que simplemente no se incluyeron;
      //      las mantenemos localmente para no perder datos.
      for (final entry in localByServerId.entries) {
        if (!serverIds.contains(entry.key)) {
          merged.add(entry.value);
          debugPrint('ℹ️ Cita local ${entry.value.id} (serverId: ${entry.key}) '
              'no vino del servidor, se mantiene localmente');
        }
      }

      // Guardar el resultado
      final jsonList = merged.map((a) => a.toJson()).toList();
      await prefs.setString(_appointmentsCacheKey, json.encode(jsonList));
      debugPrint('💾 ${merged.length} citas guardadas tras merge '
          '(${localWithoutServerId.length} locales sin sync)');

      // Notificar al callback para que el provider recargue
      _onPullCompleted?.call();
    } on DioException catch (e) {
      debugPrint('⚠️ Error al descargar citas del servidor: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error inesperado en pullFromServer: $e');
    }
  }

  /// Callback que se ejecuta tras un pull exitoso para que el provider
  /// recargue sus datos desde SharedPreferences.
  VoidCallback? _onPullCompleted;

  /// Registra un callback para ser notificado cuando pullFromServer termina.
  void setOnPullCompleted(VoidCallback callback) {
    _onPullCompleted = callback;
  }

  // ---------------------------------------------------------------------------
  // Delta sync (futuro)
  // ---------------------------------------------------------------------------
  // Future<void> deltaSync() async { ... }
}
