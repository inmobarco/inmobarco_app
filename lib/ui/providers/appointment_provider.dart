import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/appointment.dart';

/// Provider para gestionar las citas del calendario.
/// 
/// Maneja la persistencia local de las citas y proporciona
/// métodos para CRUD de citas.
class AppointmentProvider extends ChangeNotifier {
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;

  static const String _storageKey = 'appointments_cache';

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

  /// Agrega una nueva cita
  Future<void> addAppointment(Appointment appointment) async {
    _appointments.add(appointment);
    notifyListeners();
    await _saveToStorage();
  }

  /// Actualiza una cita existente
  Future<void> updateAppointment(Appointment appointment) async {
    final index = _appointments.indexWhere((a) => a.id == appointment.id);
    if (index != -1) {
      _appointments[index] = appointment.copyWith(
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      await _saveToStorage();
    }
  }

  /// Elimina una cita
  Future<void> deleteAppointment(String id) async {
    _appointments.removeWhere((a) => a.id == id);
    notifyListeners();
    await _saveToStorage();
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
}
