import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/appointment.dart';
import 'api_service.dart';

/// Servicio de sincronización entre almacenamiento local y la API.
///
/// Responsabilidades:
/// - **Cola de pendientes**: almacena operaciones (create / update / delete)
///   que fallaron por falta de conexión y las reintenta automáticamente
///   cuando vuelve la conectividad.
/// - **Delta sync** (futuro): descargará solo los cambios desde la última
///   sincronización usando un timestamp `last_synced_at`.
/// - **Resolución de conflictos** (futuro): server-wins.
class SyncService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  SyncService._();
  static final SyncService instance = SyncService._();

  static const String _pendingQueueKey = 'appointments_pending_sync';
  static const String _appointmentsCacheKey = 'appointments_cache';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  // ---------------------------------------------------------------------------
  // Inicialización / dispose
  // ---------------------------------------------------------------------------

  /// Inicia la escucha de cambios de conectividad.
  ///
  /// Cuando la red vuelve, intenta vaciar la cola de pendientes.
  void startListening() {
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
    debugPrint('📡 SyncService: escuchando cambios de conectividad');
  }

  /// Detiene la escucha de cambios de conectividad.
  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
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
  /// Cada operación que se ejecuta con éxito se elimina de la cola.
  /// Las que continúan fallando se mantienen para el siguiente intento.
  Future<void> syncPendingQueue() async {
    if (_isSyncing) return;     // Evitar ejecuciones simultáneas
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey);
      if (raw == null || raw.isEmpty) {
        _isSyncing = false;
        return;
      }

      final List<dynamic> queue = json.decode(raw);
      if (queue.isEmpty) {
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
                // Quitar serverId del payload si estaba ahí como metadato
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

  /// Intenta resolver el `serverId` de una cita local, buscando primero en el
  /// cache de citas y luego en el propio payload.
  Future<int?> _resolveServerId(
    String localId,
    Map<String, dynamic> payload,
  ) async {
    // 1. Buscar en el payload (viene en delete, a veces en update)
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
