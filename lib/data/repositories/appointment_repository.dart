import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/appointment.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

/// Repositorio que encapsula la persistencia local y la comunicación
/// con la API para las citas.
///
/// El [AppointmentProvider] delega aquí todo lo que no sea estado de UI.
class AppointmentRepository {
  static const String _storageKey = 'appointments_cache';

  final SyncService _syncService;

  /// Callback que se invoca cuando SyncService completa un pull del servidor
  /// y el repositorio detecta cambios en el caché.
  VoidCallback? onDataChanged;

  AppointmentRepository({required SyncService syncService})
      : _syncService = syncService {
    _syncService.setOnPullCompleted(_onPullCompleted);
  }

  // ---------------------------------------------------------------------------
  // Lectura
  // ---------------------------------------------------------------------------

  /// Lee todas las citas del almacenamiento local.
  Future<List<Appointment>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .map((j) => Appointment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Escritura local
  // ---------------------------------------------------------------------------

  /// Persiste la lista completa de citas en SharedPreferences.
  Future<void> saveAll(List<Appointment> appointments) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = appointments.map((a) => a.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }

  // ---------------------------------------------------------------------------
  // Sync con API (fire-and-forget, encola si falla)
  // ---------------------------------------------------------------------------

  /// Intenta crear la cita en la API. Retorna el serverId si tuvo éxito.
  /// Si falla, encola la operación para retry posterior.
  Future<int?> syncCreate(Appointment appointment) async {
    try {
      final response =
          await ApiService.createAppointment(appointment.toApiJson());
      final serverId = response['id'] as int?;
      if (serverId != null) {
        debugPrint('✅ Cita sincronizada con API (serverId: $serverId)');
      }
      return serverId;
    } on DioException catch (e) {
      debugPrint('⚠️ Error al sincronizar cita con API: ${e.message}');
      await _enqueueCreate(appointment);
      return null;
    } catch (e) {
      debugPrint('⚠️ Error inesperado al sincronizar cita: $e');
      await _enqueueCreate(appointment);
      return null;
    }
  }

  /// Intenta actualizar la cita en la API.
  /// Si falla, encola la operación para retry posterior.
  Future<void> syncUpdate(Appointment appointment) async {
    if (appointment.serverId == null) {
      debugPrint('⚠️ No se puede actualizar en API: falta serverId');
      await _enqueueUpdate(appointment);
      return;
    }

    try {
      await ApiService.updateAppointment(
        appointment.serverId!,
        appointment.toApiJson(),
      );
      debugPrint(
          '✅ Cita actualizada en API (serverId: ${appointment.serverId})');
    } on DioException catch (e) {
      debugPrint('⚠️ Error al actualizar cita en API: ${e.message}');
      await _enqueueUpdate(appointment);
    } catch (e) {
      debugPrint('⚠️ Error inesperado al actualizar cita: $e');
      await _enqueueUpdate(appointment);
    }
  }

  /// Intenta eliminar la cita en la API.
  /// Si falla, encola la operación para retry posterior.
  Future<void> syncDelete(String localId, int serverId) async {
    try {
      await ApiService.deleteAppointment(serverId);
      debugPrint('✅ Cita eliminada de API (serverId: $serverId)');
    } on DioException catch (e) {
      debugPrint('⚠️ Error al eliminar cita en API: ${e.message}');
      await _enqueueDelete(localId, serverId);
    } catch (e) {
      debugPrint('⚠️ Error inesperado al eliminar cita: $e');
      await _enqueueDelete(localId, serverId);
    }
  }

  /// Purga operaciones pendientes de un localId que nunca llegó al servidor.
  Future<void> purgeLocalId(String localId) async {
    await _syncService.purgeLocalId(localId);
  }

  // ---------------------------------------------------------------------------
  // Helpers de encolamiento
  // ---------------------------------------------------------------------------

  Future<void> _enqueueCreate(Appointment appointment) async {
    await _syncService.enqueue(
      action: 'create',
      localId: appointment.id,
      payload: appointment.toApiJson(),
    );
  }

  Future<void> _enqueueUpdate(Appointment appointment) async {
    await _syncService.enqueue(
      action: 'update',
      localId: appointment.id,
      payload: appointment.toApiJson(),
    );
  }

  Future<void> _enqueueDelete(String localId, int serverId) async {
    await _syncService.enqueue(
      action: 'delete',
      localId: localId,
      payload: {'serverId': serverId},
    );
  }

  // ---------------------------------------------------------------------------
  // Pull callback
  // ---------------------------------------------------------------------------

  void _onPullCompleted() {
    onDataChanged?.call();
  }
}
