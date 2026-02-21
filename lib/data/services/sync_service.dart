import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Servicio de sincronización entre almacenamiento local y la API.
///
/// Estrategia:
/// 1. Al abrir la app → vacía la cola de pendientes.
/// 2. Mientras la app está abierta → `Timer.periodic` cada 5 min.
/// 3. Si la red cambia de offline → online → intenta vaciar de inmediato.
/// 4. Antes de procesar la cola se **compacta** para evitar inconsistencias
///    (ej. CREATE + DELETE del mismo localId se cancelan mutuamente).
class SyncService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  SyncService._();
  static final SyncService instance = SyncService._();

  static const String _pendingQueueKey = 'appointments_pending_sync';
  static const String _appointmentsCacheKey = 'appointments_cache';

  /// Intervalo del timer periódico.
  static const Duration _syncInterval = Duration(minutes: 5);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  bool _isSyncing = false;

  // ---------------------------------------------------------------------------
  // Inicialización / dispose
  // ---------------------------------------------------------------------------

  /// Inicia la escucha de conectividad + timer periódico + sync inmediato.
  void startListening() {
    // --- Escucha de cambios de red ---
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final hasConnection = results.any(
          (r) => r != ConnectivityResult.none,
        );
        if (hasConnection) {
          debugPrint('🌐 Red disponible → vaciando cola pendiente');
          syncPendingQueue();
        }
      },
    );

    // --- Timer periódico (cada 5 min mientras la app está abierta) ---
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_syncInterval, (_) {
      debugPrint('⏰ Timer periódico → intentando sincronizar cola');
      syncPendingQueue();
    });

    // --- Vaciado inmediato al arrancar ---
    syncPendingQueue();

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
  // Delta sync (futuro)
  // ---------------------------------------------------------------------------
  // Future<void> deltaSync() async { ... }
}
