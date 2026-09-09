import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../domain/models/appointment.dart';
import '../../core/constants/app_constants.dart';
import 'api_service.dart';
import 'appointment_store.dart';
import 'wasi_api_service.dart';

/// Servicio de sincronización entre almacenamiento local y la API.
///
/// Estrategia:
/// 1. Al abrir la app → fullSync (push local + pull servidor).
/// 2. Mientras la app está **en primer plano** → `Timer.periodic` cada 5 min.
///    En background el timer se detiene y se reanuda al volver, junto con un
///    sync inmediato: no tiene sentido gastar red y batería sincronizando una
///    agenda que nadie está mirando.
/// 3. Si la red cambia de offline → online → fullSync inmediato.
/// 4. El pull es **delta**: `updated_after` con la marca del último sync, así
///    que solo baja lo que cambió (incluidas citas pasadas que se hayan
///    modificado). El primer sync del dispositivo usa `after` para traer la
///    agenda vigente sin arrastrar historia.
/// 5. Antes de procesar la cola se **compacta** para evitar inconsistencias
///    (ej. CREATE + DELETE del mismo localId se cancelan mutuamente).
class SyncService with WidgetsBindingObserver {
  final NotificationService notificationService;
  final AppointmentStore _store;
  WasiApiService? _wasiApi;

  SyncService({
    required this.notificationService,
    AppointmentStore? store,
    WasiApiService? wasiApi,
  })  : _store = store ?? AppointmentStore(),
        _wasiApi = wasiApi;

  /// Entidades que puede llevar la cola.
  static const String entityAppointment = 'appointment';
  static const String entityClient = 'client';
  static const String entityClientNote = 'client_note';

  /// La clave conserva el nombre histórico: la cola empezó siendo solo de
  /// citas y renombrarla dejaría atrás las operaciones ya encoladas.
  static const String _pendingQueueKey = 'appointments_pending_sync';
  static const String _lastSyncKey = 'last_appointments_sync';

  /// Solapamiento del delta: se pide desde un poco antes del último sync para
  /// absorber la diferencia de reloj entre el dispositivo y el servidor.
  static const Duration _deltaOverlap = Duration(minutes: 5);

  /// Intervalo del timer periódico.
  static const Duration _syncInterval = Duration(minutes: 5);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  bool _isBusy = false;
  bool _initialSyncDone = false;

  // ---------------------------------------------------------------------------
  // Inicialización / dispose
  // ---------------------------------------------------------------------------

  /// Inicia la escucha de conectividad + ciclo de vida + timer + sync.
  void startListening() {
    WidgetsBinding.instance.addObserver(this);

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

    // --- Timer periódico (cada 5 min mientras la app esté en primer plano) ---
    _startPeriodicTimer();

    // --- Sync inmediato al arrancar ---
    fullSync();

    debugPrint('📡 SyncService: escuchando red + ciclo de vida + timer cada '
        '${_syncInterval.inMinutes} min');
  }

  /// Detiene escucha de red, ciclo de vida y timer periódico.
  void stopListening() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_syncInterval, (_) {
      debugPrint('⏰ Timer periódico → fullSync');
      fullSync();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('▶️ App en primer plano → timer + fullSync');
        _startPeriodicTimer();
        fullSync();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        debugPrint('⏸️ App en background → timer de sync detenido');
        _periodicTimer?.cancel();
        _periodicTimer = null;
      case AppLifecycleState.inactive:
        break; // Transitorio (llamada entrante, cambio de app): no tocar nada
    }
  }

  // ---------------------------------------------------------------------------
  // Cola de pendientes
  // ---------------------------------------------------------------------------

  /// Encola una operación que no pudo sincronizarse con la API.
  Future<void> enqueue({
    required String action,
    required String localId,
    required Map<String, dynamic> payload,
    String entity = entityAppointment,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey);
      final List<dynamic> queue = raw != null ? json.decode(raw) : [];
      queue.add({
        'entity': entity,        // 'appointment' | 'client' | 'client_note'
        'action': action,        // 'create' | 'update' | 'delete'
        'localId': localId,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_pendingQueueKey, json.encode(queue));
      debugPrint('📋 Operación encolada ($entity/$action) para $localId');
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
  Future<void> syncPendingQueue() => _withLock(_pushPendingQueue);

  Future<void> _pushPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey);
      if (raw == null || raw.isEmpty) return;

      List<dynamic> queue = json.decode(raw);
      if (queue.isEmpty) return;

      // ── Compactar la cola antes de procesar ──
      queue = _compactQueue(queue.cast<Map<String, dynamic>>());

      if (queue.isEmpty) {
        await prefs.remove(_pendingQueueKey);
        debugPrint('✅ Cola compactada quedó vacía, nada que sincronizar');
        return;
      }

      debugPrint('🔄 Procesando ${queue.length} operaciones pendientes…');

      final List<Map<String, dynamic>> remaining = [];
      var crmSynced = false;

      for (final item in queue) {
        final op = item as Map<String, dynamic>;
        // Las operaciones encoladas por versiones anteriores no traen entidad.
        final entity = op['entity'] as String? ?? entityAppointment;
        final action = op['action'] as String;
        final localId = op['localId'] as String;
        final payload = Map<String, dynamic>.from(op['payload'] as Map);

        try {
          if (entity != entityAppointment) {
            await _processCrmOperation(entity, action, payload);
            crmSynced = true;
            continue;
          }

          switch (action) {
            case 'create':
              final response = await ApiService.createAppointment(payload);
              final serverId = response['id'] as int?;
              if (serverId != null) {
                await _store.setServerId(localId, serverId);
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

      if (crmSynced) _onCrmSynced?.call();

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
    }
  }

  /// Limpia el estado de citas al cerrar sesión.
  ///
  /// Las citas son del asesor, no del dispositivo: si otro inicia sesión aquí,
  /// no puede heredar la agenda anterior. Y la marca del delta debe irse con
  /// ellas, porque si no el primer sync del nuevo asesor pediría solo cambios
  /// recientes y nunca traería su agenda completa.
  ///
  /// Antes de borrar intenta vaciar la cola, que aún tiene el token del asesor
  /// que se va; si no hay red, esas operaciones se pierden (es la única forma
  /// de no enviarlas después con la sesión de otra persona).
  Future<void> resetForLogout() async {
    try {
      await _withLock(_pushPendingQueue);
    } catch (e) {
      debugPrint('⚠️ No se pudo vaciar la cola antes del logout: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getString(_pendingQueueKey);
      if (pending != null && pending.isNotEmpty && pending != '[]') {
        debugPrint('⚠️ Se descartan operaciones pendientes al cerrar sesión');
      }
      await prefs.remove(_pendingQueueKey);
      await prefs.remove(_lastSyncKey);
      await _store.writeAll([]);
      debugPrint('🧹 Estado de citas limpiado al cerrar sesión');
    } catch (e) {
      debugPrint('❌ Error limpiando el estado de citas: $e');
    }
  }

  /// Ejecuta una operación de CRM encolada (clientes y bitácora).
  ///
  /// Lanza si falla, para que el llamador la deje en la cola y la reintente.
  Future<void> _processCrmOperation(
    String entity,
    String action,
    Map<String, dynamic> payload,
  ) async {
    final api = _wasiApi ??= WasiApiService(
      apiToken: AppConstants.wasiApiToken,
      companyId: AppConstants.wasiApiId,
    );

    if (entity == entityClient && action == 'create') {
      final idClient = await api.createClient(
        firstName: payload['first_name'] as String,
        cellPhone: payload['cell_phone'] as String,
        lastName: payload['last_name'] as String?,
        email: payload['email'] as String?,
        query: payload['query'] as String?,
      );
      final propertyId = payload['id_property'] as String?;
      if (propertyId != null && propertyId.isNotEmpty) {
        await api.addPropertyToClient(idClient, propertyId);
      }
      debugPrint('✅ Pendiente CREATE de cliente sincronizado ($idClient)');
      return;
    }

    if (entity == entityClient && action == 'update') {
      final idClient = payload.remove('id_client')?.toString();
      if (idClient == null || idClient.isEmpty) {
        throw StateError('UPDATE de cliente sin id_client');
      }
      await api.updateClient(idClient, payload);
      debugPrint('✅ Pendiente UPDATE de cliente sincronizado ($idClient)');
      return;
    }

    if (entity == entityClientNote && action == 'create') {
      final idClient = int.tryParse(payload['id_client_wasi']?.toString() ?? '');
      if (idClient == null) {
        throw StateError('Nota pendiente sin id_client_wasi');
      }
      await ApiService.createClientNote(
        idClient,
        payload['note'] as String? ?? '',
        payload['note_type'] as String? ?? 'nota',
      );
      debugPrint('✅ Pendiente CREATE de nota sincronizado ($idClient)');
      return;
    }

    throw StateError('Operación desconocida en cola: $entity/$action');
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
    // Agrupar por entidad + localId preservando orden de aparición
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final List<String> insertionOrder = [];

    for (final op in queue) {
      final entity = op['entity'] as String? ?? entityAppointment;
      final key = '$entity/${op['localId']}';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        insertionOrder.add(key);
      }
      groups[key]!.add(op);
    }

    final List<Map<String, dynamic>> compacted = [];

    for (final key in insertionOrder) {
      final ops = groups[key]!;
      final localId = ops.first['localId'] as String;
      final entity = ops.first['entity'] as String? ?? entityAppointment;

      // Las reglas de fusión asumen payloads del mismo formato, y el de crear
      // un cliente en WASI no tiene la forma del de actualizarlo. Fuera de
      // las citas, la cola se procesa tal cual.
      if (entity != entityAppointment) {
        compacted.addAll(ops);
        continue;
      }

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

  /// Intenta resolver el `serverId` de una cita local.
  Future<int?> _resolveServerId(
    String localId,
    Map<String, dynamic> payload,
  ) async {
    // 1. Buscar en el payload
    if (payload.containsKey('serverId')) {
      return payload['serverId'] as int?;
    }

    // 2. Buscar en el almacenamiento local
    try {
      return await _store.findServerId(localId);
    } catch (_) {
      return null;
    }
  }

  /// Serializa las sincronizaciones: si ya hay una en curso, esta se descarta.
  ///
  /// Cubre push y pull, no solo la cola: el timer periódico y el evento de
  /// conectividad pueden dispararse a la vez.
  Future<void> _withLock(Future<void> Function() action) async {
    if (_isBusy) {
      debugPrint('⏭️ Sincronización ya en curso → se omite esta ejecución');
      return;
    }
    _isBusy = true;
    try {
      await action();
    } finally {
      _isBusy = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Full sync: push + pull
  // ---------------------------------------------------------------------------

  /// Ejecuta una sincronización completa:
  /// 1. **Push** — vacía la cola de pendientes (local → servidor).
  /// 2. **Pull** — descarga citas del servidor y las fusiona con las locales.
  Future<void> fullSync() async {
    if (!await ApiService.hasSession()) {
      debugPrint('🔒 Sin sesión activa → se omite la sincronización de citas');
      return;
    }
    await _withLock(() async {
      await _pushPendingQueue();
      await _pullFromServer();
    });
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
  Future<void> pullFromServer() => _withLock(_pullFromServer);

  Future<void> _pullFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_lastSyncKey);

      // Marca del sync que empieza ahora. Se toma ANTES de la petición: si el
      // servidor cambia algo mientras respondemos, entra en el próximo delta
      // en vez de perderse.
      final syncStartedAt = DateTime.now();

      final List<Map<String, dynamic>> serverList;
      if (lastSyncMs == null) {
        // Primer sync del dispositivo: la agenda vigente, sin historia.
        final today = DateTime(
            syncStartedAt.year, syncStartedAt.month, syncStartedAt.day);
        serverList = await ApiService.getAppointments(after: today);
        debugPrint('📥 Sync inicial (after=hoy) → ${serverList.length} citas');
      } else {
        // Delta: solo lo que cambió, con solapamiento por desfase de reloj.
        final updatedAfter =
            DateTime.fromMillisecondsSinceEpoch(lastSyncMs).subtract(_deltaOverlap);
        serverList = await ApiService.getAppointments(updatedAfter: updatedAfter);
        debugPrint('📥 Delta desde ${updatedAfter.toIso8601String()} '
            '→ ${serverList.length} citas cambiadas');
      }

      // Efectos secundarios diferidos: las notificaciones se ejecutan fuera
      // del lock del store, con el merge ya persistido.
      final List<String> remindersToCancel = [];
      final List<Appointment> remindersToSchedule = [];
      final List<Appointment> remindersToReschedule = [];
      int unsyncedCount = 0;

      // Merge atómico: leer + fusionar + escribir dentro del lock del store,
      // para que una mutación de la UI en paralelo no se pierda.
      final merged = await _store.update((localList) {
        remindersToCancel.clear();
        remindersToSchedule.clear();
        remindersToReschedule.clear();

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
        unsyncedCount = localWithoutServerId.length;

        final Set<int> serverIds = {};
        final List<Appointment> result = [];

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
              remindersToCancel.add(localMatch.id);
            }
            continue;
          }

          final serverAppointment = Appointment.fromApiJson(serverJson);
          final localMatch = localByServerId[sId];

          if (localMatch != null) {
            // Existe local → actualizar con datos del servidor (conservar id local)
            final updatedLocal = serverAppointment.copyWith(id: localMatch.id);
            result.add(updatedLocal);
            // Reprogramar notificación si la fecha/hora cambió
            if (localMatch.dateTime != serverAppointment.dateTime) {
              remindersToReschedule.add(updatedLocal);
            }
          } else {
            // Solo en servidor → agregar como nueva + programar notificación
            result.add(serverAppointment);
            remindersToSchedule.add(serverAppointment);
          }
        }

        // 2. Mantener citas locales que aún no tienen serverId
        //    (aún no se sincronizaron, probablemente en cola pendiente)
        result.addAll(localWithoutServerId);

        // 3. Citas locales con serverId que NO vinieron en la respuesta
        //    → en un delta eso significa "sin cambios", así que se mantienen
        //      tal cual. Un borrado desde el servidor llega como status
        //      "deleted" dentro del propio delta (paso 1).
        for (final entry in localByServerId.entries) {
          if (!serverIds.contains(entry.key)) {
            result.add(entry.value);
            debugPrint('ℹ️ Cita local ${entry.value.id} (serverId: ${entry.key}) '
                'no vino del servidor, se mantiene localmente');
          }
        }

        return result;
      });

      debugPrint('💾 ${merged.length} citas guardadas tras merge '
          '($unsyncedCount locales sin sync)');

      // La marca se guarda solo si el pull llegó completo: si algo falla, el
      // próximo delta vuelve a pedir desde la misma fecha.
      await prefs.setInt(_lastSyncKey, syncStartedAt.millisecondsSinceEpoch);

      // Notificaciones, ya fuera del lock
      for (final localId in remindersToCancel) {
        await notificationService.cancelAppointmentReminder(localId);
      }
      for (final appointment in remindersToReschedule) {
        await notificationService.rescheduleAppointmentReminder(appointment);
        debugPrint('🔔 Notificación reprogramada para cita ${appointment.id}');
      }
      for (final appointment in remindersToSchedule) {
        await notificationService.scheduleAppointmentReminder(appointment);
        debugPrint('🔔 Notificación programada para nueva cita ${appointment.id}');
      }

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

  VoidCallback? _onCrmSynced;

  /// Registra un callback para cuando se sincroniza una operación de CRM
  /// pendiente, y la lista de clientes deja de reflejar el estado real.
  void setOnCrmSynced(VoidCallback callback) {
    _onCrmSynced = callback;
  }

  // ---------------------------------------------------------------------------
  // Delta sync (futuro)
  // ---------------------------------------------------------------------------
  // Future<void> deltaSync() async { ... }
}
