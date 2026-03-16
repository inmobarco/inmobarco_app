import 'package:flutter/foundation.dart';
import '../../domain/models/appointment.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/appointment_repository.dart';

/// Provider para gestionar las citas del calendario.
///
/// Maneja el estado de UI y delega la persistencia y sincronización
/// al [AppointmentRepository].
class AppointmentProvider extends ChangeNotifier {
  final AppointmentRepository _repository;
  final NotificationService _notificationService;

  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;

  List<Appointment> get appointments => List.unmodifiable(_appointments);
  bool get isLoading => _isLoading;
  String? get error => _error;

  AppointmentProvider({
    required AppointmentRepository repository,
    required NotificationService notificationService,
  })  : _repository = repository,
       _notificationService = notificationService {
    _repository.onDataChanged = _reloadFromStorage;
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

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
      return appointment.dateTime
              .isAfter(start.subtract(const Duration(days: 1))) &&
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

  /// Obtiene una cita por ID
  Appointment? getAppointmentById(String id) {
    try {
      return _appointments.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
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

  // ---------------------------------------------------------------------------
  // Carga
  // ---------------------------------------------------------------------------

  /// Carga las citas desde el almacenamiento local
  Future<void> loadAppointments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _appointments = await _repository.getAll();
    } catch (e) {
      _error = 'Error al cargar citas: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Agrega una nueva cita (local + API en background).
  Future<void> addAppointment(Appointment appointment) async {
    _appointments.add(appointment);
    notifyListeners();
    await _repository.saveAll(_appointments);

    // Programar notificación de recordatorio 30 minutos antes
    await _notificationService.scheduleAppointmentReminder(appointment);

    // Sincronizar con la API en background
    _syncCreateInBackground(appointment);
  }

  /// Actualiza una cita existente (local + API en background).
  Future<void> updateAppointment(Appointment appointment) async {
    final index = _appointments.indexWhere((a) => a.id == appointment.id);
    if (index != -1) {
      final updated = appointment.copyWith(updatedAt: DateTime.now());
      _appointments[index] = updated;
      notifyListeners();
      await _repository.saveAll(_appointments);

      // Reprogramar notificación con la nueva hora
      await _notificationService.rescheduleAppointmentReminder(updated);

      // Sincronizar con la API en background
      _repository.syncUpdate(updated);
    }
  }

  /// Elimina una cita (local + API en background).
  Future<void> deleteAppointment(String id) async {
    final appointment = getAppointmentById(id);
    final serverId = appointment?.serverId;

    // Cancelar notificación antes de eliminar
    await _notificationService.cancelAppointmentReminder(id);

    _appointments.removeWhere((a) => a.id == id);
    notifyListeners();
    await _repository.saveAll(_appointments);

    if (serverId != null) {
      _repository.syncDelete(id, serverId);
    } else {
      await _repository.purgeLocalId(id);
    }
  }

  /// Actualiza el estado de una cita
  Future<void> updateAppointmentStatus(
      String id, AppointmentStatus status) async {
    final appointment = getAppointmentById(id);
    if (appointment != null) {
      if (status == AppointmentStatus.cancelled) {
        await _notificationService.cancelAppointmentReminder(id);
      }
      await updateAppointment(appointment.copyWith(status: status));
    }
  }

  /// Limpia el error actual
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers internos
  // ---------------------------------------------------------------------------

  /// Intenta crear en API; si tiene éxito, actualiza el serverId local.
  void _syncCreateInBackground(Appointment appointment) async {
    final serverId = await _repository.syncCreate(appointment);
    if (serverId != null) {
      final index = _appointments.indexWhere((a) => a.id == appointment.id);
      if (index != -1) {
        _appointments[index] =
            _appointments[index].copyWith(serverId: serverId);
        await _repository.saveAll(_appointments);
        notifyListeners();
      }
    }
  }

  /// Recarga las citas desde storage sin mostrar loading.
  /// Se invoca cuando SyncService completa un pull del servidor.
  Future<void> _reloadFromStorage() async {
    try {
      final newList = await _repository.getAll();

      if (!_appointmentListEquals(_appointments, newList)) {
        _appointments = newList;
        notifyListeners();
        debugPrint(
            '🔄 AppointmentProvider: recargado tras pull (${_appointments.length} citas)');
      } else {
        debugPrint(
            '⏭️ AppointmentProvider: sin cambios tras pull, skip rebuild');
      }
    } catch (e) {
      debugPrint('❌ Error al recargar citas tras pull: $e');
    }
  }

  /// Compara dos listas de citas de forma ligera.
  bool _appointmentListEquals(List<Appointment> a, List<Appointment> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].serverId != b[i].serverId ||
          a[i].title != b[i].title ||
          a[i].status != b[i].status ||
          a[i].dateTime != b[i].dateTime ||
          a[i].updatedAt != b[i].updatedAt) {
        return false;
      }
    }
    return true;
  }
}
