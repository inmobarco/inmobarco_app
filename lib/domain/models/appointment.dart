/// Modelo que representa una cita o evento en el calendario.
/// 
/// Puede estar asociada a una propiedad específica y a un cliente.
class Appointment {
  final String id;
  /// ID asignado por el servidor (null si aún no se ha sincronizado).
  final int? serverId;
  final String title;
  final String? description;
  final DateTime dateTime;
  final Duration duration;
  final AppointmentType type;
  final AppointmentStatus status;
  final String? propertyId;
  final String? propertyAddress;
  final String? clientName;
  final String? clientPhone;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Appointment({
    required this.id,
    this.serverId,
    required this.title,
    this.description,
    required this.dateTime,
    this.duration = const Duration(hours: 1),
    this.type = AppointmentType.visit,
    this.status = AppointmentStatus.pending,
    this.propertyId,
    this.propertyAddress,
    this.clientName,
    this.clientPhone,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Crea una copia del objeto con los campos modificados
  Appointment copyWith({
    String? id,
    int? serverId,
    String? title,
    String? description,
    DateTime? dateTime,
    Duration? duration,
    AppointmentType? type,
    AppointmentStatus? status,
    String? propertyId,
    String? propertyAddress,
    String? clientName,
    String? clientPhone,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      status: status ?? this.status,
      propertyId: propertyId ?? this.propertyId,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convierte el objeto a JSON para persistencia local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverId': serverId,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'durationMinutes': duration.inMinutes,
      'type': type.name,
      'status': status.name,
      'propertyId': propertyId,
      'propertyAddress': propertyAddress,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Convierte al formato que espera la API del backend.
  ///
  /// Campos: title, description, appointment_date, duration_minutes,
  ///         client_name, client_phone, appointment_type, status.
  /// El username NO va en el body → el backend lo toma del JWT.
  Map<String, dynamic> toApiJson() {
    return {
      'title': title,
      'description': description,
      'appointment_date': dateTime.toUtc().toIso8601String(),
      'duration_minutes': duration.inMinutes,
      'client_name': clientName,
      'client_phone': clientPhone,
      'appointment_type': type.name,
      'status': status.name,
    };
  }

  /// Crea un objeto desde JSON
  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      serverId: json['serverId'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      dateTime: DateTime.parse(json['dateTime'] as String),
      duration: Duration(minutes: json['durationMinutes'] as int? ?? 60),
      type: AppointmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AppointmentType.visit,
      ),
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      propertyId: json['propertyId'] as String?,
      propertyAddress: json['propertyAddress'] as String?,
      clientName: json['clientName'] as String?,
      clientPhone: json['clientPhone'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  /// Hora de fin de la cita
  DateTime get endTime => dateTime.add(duration);

  /// Verifica si la cita es hoy
  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// Verifica si la cita ya pasó
  bool get isPast => dateTime.isBefore(DateTime.now());

  @override
  String toString() => 'Appointment(id: $id, title: $title, dateTime: $dateTime)';
}

/// Tipos de citas disponibles
enum AppointmentType {
  visit,      // Visita a propiedad
  meeting,    // Reunión con cliente
  signing,    // Firma de contrato
  followUp,   // Seguimiento
  other,      // Otros
}

/// Extensión para obtener información adicional del tipo
extension AppointmentTypeExtension on AppointmentType {
  String get displayName {
    switch (this) {
      case AppointmentType.visit:
        return 'Visita';
      case AppointmentType.meeting:
        return 'Reunión';
      case AppointmentType.signing:
        return 'Firma';
      case AppointmentType.followUp:
        return 'Seguimiento';
      case AppointmentType.other:
        return 'Otro';
    }
  }

  String get icon {
    switch (this) {
      case AppointmentType.visit:
        return '🏠';
      case AppointmentType.meeting:
        return '🤝';
      case AppointmentType.signing:
        return '📝';
      case AppointmentType.followUp:
        return '📞';
      case AppointmentType.other:
        return '📌';
    }
  }
}

/// Estados posibles de una cita
enum AppointmentStatus {
  pending,    // Pendiente
  confirmed,  // Confirmada
  completed,  // Completada
  cancelled,  // Cancelada
  //rescheduled, // Reagendada
}

/// Extensión para obtener información adicional del estado
extension AppointmentStatusExtension on AppointmentStatus {
  String get displayName {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Pendiente';
      case AppointmentStatus.confirmed:
        return 'Confirmada';
      case AppointmentStatus.completed:
        return 'Completada';
      case AppointmentStatus.cancelled:
        return 'Cancelada';
      //case AppointmentStatus.rescheduled:
        //return 'Reagendada';
    }
  }

  int get colorValue {
    switch (this) {
      case AppointmentStatus.pending:
        return 0xFFFFC107; // Amarillo
      case AppointmentStatus.confirmed:
        return 0xFF1B99D3; // Azul primario
      case AppointmentStatus.completed:
        return 0xFF28A745; // Verde
      case AppointmentStatus.cancelled:
        return 0xFFDC3545; // Rojo
      //case AppointmentStatus.rescheduled:
        //return 0xFF6C757D; // Gris
    }
  }
}
