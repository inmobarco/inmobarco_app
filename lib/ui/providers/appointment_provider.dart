import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/appointment.dart';
import '../../core/services/notification_service.dart';
import '../../data/services/api_service.dart';

/// Provider para gestionar las citas del calendario.
/// 
/// Maneja la persistencia local de las citas y proporciona
/// métodos para CRUD de citas.
class AppointmentProvider extends ChangeNotifier {
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;

  static const String _storageKey = 'appointments_cache';
  static const String _pendingQueueKey = 'appointments_pending_sync';

  List<Appointment> get appointments => List.unmodifiable(_appointments);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Obtiene las citas para un día específico
  List<Appointment> getAppointmentsForDay(DateTime day) {
    return _appointments.where((appointment) {
      return appointment.dateTime.year == day.year &&
          appointment.dateTime.month == day.month &&
          appointment.dateTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// Obtiene las citas para un rango de fechas
  List<Appointment> getAppointmentsInRange(DateTime start, DateTime end) {
    return _appointments.where((appointment) {
      return appointment.dateTime.isAfter(start.subtract(const Duration(days: 1))) &&
          appointment.dateTime.isBefore(end.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// Obtiene las citas de hoy
  List<Appointment> get todayAppointments {
    final now = DateTime.now();
    return getAppointmentsForDay(now);
  }

  /// Obtiene las próximas citas (no pasadas)
  List<Appointment> get upcomingAppointments {
    final now = DateTime.now();
    return _appointments
        .where((a) => a.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// Carga las citas desde el almacenamiento local
  Future<void> loadAppointments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _appointments = jsonList
            .map((json) => Appointment.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = 'Error al cargar citas: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda las citas en el almacenamiento local
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _appointments.map((a) => a.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error al guardar citas: $e');
    }
  }

  /// Agrega una nueva cita (local + API en background).
  Future<void> addAppointment(Appointment appointment) async {
    // 1. Guardar localmente de inmediato
    _appointments.add(appointment);
    notifyListeners();
    await _saveToStorage();

    // 2. Programar notificación de recordatorio 30 minutos antes
    await notificationService.scheduleAppointmentReminder(appointment);

    // 3. Intentar sincronizar con la API en background
    _syncCreateInBackground(appointment);
  }

  /// Actualiza una cita existente (local + API en background).
  Future<void> updateAppointment(Appointment appointment) async {
    final index = _appointments.indexWhere((a) => a.id == appointment.id);
    if (index != -1) {
      final updated = appointment.copyWith(updatedAt: DateTime.now());
      _appointments[index] = updated;
      notifyListeners();
      await _saveToStorage();

      // Reprogramar notificación con la nueva hora
      await notificationService.rescheduleAppointmentReminder(updated);

      // Intentar sincronizar con la API en background
      _syncUpdateInBackground(updated);
    }
  }

  /// Elimina una cita (local + API en background).
  Future<void> deleteAppointment(String id) async {
    // Obtener serverId antes de borrar
    final appointment = getAppointmentById(id);
    final serverId = appointment?.serverId;

    // Cancelar notificación antes de eliminar
    await notificationService.cancelAppointmentReminder(id);

    _appointments.removeWhere((a) => a.id == id);
    notifyListeners();
    await _saveToStorage();

    // Intentar sincronizar con la API en background
    if (serverId != null) {
      _syncDeleteInBackground(id, serverId);
    }
  }

  /// Obtiene una cita por ID
  Appointment? getAppointmentById(String id) {
    try {
      return _appointments.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Actualiza el estado de una cita
  Future<void> updateAppointmentStatus(String id, AppointmentStatus status) async {
    final appointment = getAppointmentById(id);
    if (appointment != null) {
      // Si se cancela la cita, cancelar la notificación
      if (status == AppointmentStatus.cancelled) {
        await notificationService.cancelAppointmentReminder(id);
      }
      await updateAppointment(appointment.copyWith(status: status));
    }
  }

  /// Obtiene el conteo de citas por día para mostrar indicadores
  Map<DateTime, int> getAppointmentCountByDay() {
    final Map<DateTime, int> counts = {};
    for (final appointment in _appointments) {
      final day = DateTime(
        appointment.dateTime.year,
        appointment.dateTime.month,
        appointment.dateTime.day,
      );
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  /// Limpia el error actual
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Background API sync
  // ---------------------------------------------------------------------------

  /// Intenta crear la cita en la API. Si falla, encola la operación.
  void _syncCreateInBackground(Appointment appointment) async {
    try {
      final response = await ApiService.createAppointment(appointment.toApiJson());

      // Extraer el id generado por el servidor
      final serverId = response['id'] as int?;
      if (serverId != null) {
        // Actualizar la cita local con el serverId
        final index = _appointments.indexWhere((a) => a.id == appointment.id);
        if (index != -1) {
          _appointments[index] = _appointments[index].copyWith(serverId: serverId);
          await _saveToStorage();
          notifyListeners();
          debugPrint('✅ Cita sincronizada con API (serverId: $serverId)');
        }
      }
    } on DioException catch (e) {
      debugPrint('⚠️ Error al sincronizar cita con API: ${e.message}');
      await _enqueuePending('create', appointment.id, appointment.toApiJson());
    } catch (e) {
      debugPrint('⚠️ Error inesperado al sincronizar cita: $e');
      await _enqueuePending('create', appointment.id, appointment.toApiJson());
    }
  }

  /// Intenta actualizar la cita en la API. Si falla, encola la operación.
  void _syncUpdateInBackground(Appointment appointment) async {
    if (appointment.serverId == null) {
      debugPrint('⚠️ No se puede actualizar en API: falta serverId');
      await _enqueuePending('update', appointment.id, appointment.toApiJson());
      return;
    }

    try {
      await ApiService.updateAppointment(
        appointment.serverId!,
        appointment.toApiJson(),
      );
      debugPrint('✅ Cita actualizada en API (serverId: ${appointment.serverId})');
    } on DioException catch (e) {
      debugPrint('⚠️ Error al actualizar cita en API: ${e.message}');
      await _enqueuePending('update', appointment.id, appointment.toApiJson());
    } catch (e) {
      debugPrint('⚠️ Error inesperado al actualizar cita: $e');
      await _enqueuePending('update', appointment.id, appointment.toApiJson());
    }
  }

  /// Intenta eliminar la cita en la API. Si falla, encola la operación.
  void _syncDeleteInBackground(String localId, int serverId) async {
    try {
      await ApiService.deleteAppointment(serverId);
      debugPrint('✅ Cita eliminada de API (serverId: $serverId)');
    } on DioException catch (e) {
      debugPrint('⚠️ Error al eliminar cita en API: ${e.message}');
      await _enqueuePending('delete', localId, {'serverId': serverId});
    } catch (e) {
      debugPrint('⚠️ Error inesperado al eliminar cita: $e');
      await _enqueuePending('delete', localId, {'serverId': serverId});
    }
  }

  // ---------------------------------------------------------------------------
  // Cola de operaciones pendientes
  // ---------------------------------------------------------------------------

  /// Encola una operación que no pudo sincronizarse con la API.
  Future<void> _enqueuePending(
    String action,
    String localId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey);
      final List<dynamic> queue = raw != null ? json.decode(raw) : [];
      queue.add({
        'action': action,
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
}
