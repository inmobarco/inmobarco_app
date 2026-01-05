import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../../domain/models/appointment.dart';

/// Servicio singleton para gestionar notificaciones locales.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio de notificaciones.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar zonas horarias
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Bogota'));

      // Configuración de Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Configuración de iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Solicitar permiso de alarmas exactas en Android
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
      await androidPlugin?.requestNotificationsPermission();

      _isInitialized = true;
      debugPrint('NotificationService inicializado correctamente');
    } catch (e) {
      debugPrint('Error inicializando NotificationService: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notificación tocada: ${response.payload}');
    // Aquí puedes navegar a la cita específica usando el payload (appointmentId)
  }

  /// Programa una notificación de recordatorio 30 minutos antes de la cita.
  Future<void> scheduleAppointmentReminder(Appointment appointment) async {
    if (!_isInitialized) {
      debugPrint('NotificationService no inicializado');
      return;
    }

    // No programar notificación para citas canceladas
    if (appointment.status == AppointmentStatus.cancelled) {
      debugPrint('Cita cancelada, no se programa notificación: ${appointment.title}');
      return;
    }

    // Calcular la hora del recordatorio (30 minutos antes)
    final reminderTime = appointment.dateTime.subtract(const Duration(minutes: 30));
    
    // No programar si el recordatorio ya pasó
    if (reminderTime.isBefore(DateTime.now())) {
      debugPrint('La hora del recordatorio ya pasó para: ${appointment.title}');
      return;
    }

    // Convertir a TZDateTime
    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    // Usar el hash del ID como notification ID (debe ser int)
    final notificationId = appointment.id.hashCode;

    // Configuración de la notificación
    const androidDetails = AndroidNotificationDetails(
      'appointment_reminders',
      'Recordatorios de Citas',
      channelDescription: 'Notificaciones de recordatorio 30 minutos antes de las citas',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Construir el mensaje
    final timeStr = '${appointment.dateTime.hour.toString().padLeft(2, '0')}:${appointment.dateTime.minute.toString().padLeft(2, '0')}';
    final title = '${appointment.type.icon} Recordatorio de Cita';
    String body = '${appointment.title} en 30 minutos ($timeStr)';
    
    if (appointment.clientName != null && appointment.clientName!.isNotEmpty) {
      body += '\nCliente: ${appointment.clientName}';
    }

    try {
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: appointment.id,
      );
      
      debugPrint('Notificación programada para ${appointment.title} a las $scheduledDate');
    } catch (e) {
      debugPrint('Error programando notificación: $e');
    }
  }

  /// Cancela la notificación de recordatorio de una cita.
  Future<void> cancelAppointmentReminder(String appointmentId) async {
    if (!_isInitialized) return;
    
    try {
      final notificationId = appointmentId.hashCode;
      await _notifications.cancel(notificationId);
      debugPrint('Notificación cancelada para cita: $appointmentId');
    } catch (e) {
      debugPrint('Error cancelando notificación: $e');
    }
  }

  /// Reprograma la notificación de una cita (cancela y vuelve a programar).
  Future<void> rescheduleAppointmentReminder(Appointment appointment) async {
    await cancelAppointmentReminder(appointment.id);
    await scheduleAppointmentReminder(appointment);
  }

  /// Muestra una notificación instantánea de prueba.
  Future<void> showTestNotification() async {
    if (!_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Pruebas',
      channelDescription: 'Canal de pruebas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      0,
      '✅ Notificación de Prueba',
      'Las notificaciones están funcionando correctamente',
      notificationDetails,
    );
  }

  /// Verifica si tiene permisos de notificación.
  Future<bool> hasPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final hasNotificationPermission = await androidPlugin.areNotificationsEnabled() ?? false;
      return hasNotificationPermission;
    }
    return true; // En iOS asumimos que sí
  }

  /// Solicita permisos de notificación.
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Obtiene las notificaciones pendientes.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) return [];
    return await _notifications.pendingNotificationRequests();
  }
}

/// Instancia global del servicio de notificaciones.
final notificationService = NotificationService();
