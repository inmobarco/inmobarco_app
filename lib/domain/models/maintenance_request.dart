/// Solicitudes de mantenimiento (`/staff/maintenance/requests`), solo lectura.
///
/// El listado y el detalle comparten [MaintenanceRequest]: los campos que solo
/// trae el detalle (documento, correo, disponibilidad, descripción completa)
/// quedan en null cuando el objeto viene del listado.
library;

/// Estados de la solicitud, en el orden del flujo.
class MaintenanceStatus {
  MaintenanceStatus._();

  static const recibida = 'recibida';
  static const enRevision = 'en_revision';
  static const esperandoAprobacion = 'esperando_aprobacion';
  static const programada = 'programada';
  static const enEjecucion = 'en_ejecucion';
  static const resuelta = 'resuelta';
  static const cerrada = 'cerrada';
  static const cancelada = 'cancelada';

  /// Lo que se muestra por defecto. `cancelada` nunca se pide.
  static const active = [
    recibida,
    enRevision,
    esperandoAprobacion,
    programada,
    enEjecucion,
    resuelta,
  ];

  static const labels = <String, String>{
    recibida: 'Recibida',
    enRevision: 'En revisión',
    esperandoAprobacion: 'Esperando aprobación',
    programada: 'Programada',
    enEjecucion: 'En ejecución',
    resuelta: 'Resuelta',
    cerrada: 'Cerrada',
    cancelada: 'Cancelada',
  };

  static String label(String? status) =>
      labels[status] ?? _humanize(status ?? '');
}

class MaintenancePriority {
  MaintenancePriority._();

  static const baja = 'baja';
  static const media = 'media';
  static const alta = 'alta';
  static const urgente = 'urgente';

  /// De mayor a menor, que es como se filtra en la práctica.
  static const all = [urgente, alta, media, baja];

  static const labels = <String, String>{
    baja: 'Baja',
    media: 'Media',
    alta: 'Alta',
    urgente: 'Urgente',
  };

  static String label(String? priority) =>
      labels[priority] ?? _humanize(priority ?? '');
}

const _responsiblePartyLabels = <String, String>{
  'propietario': 'Propietario',
  'arrendatario': 'Arrendatario',
  'inmobiliaria': 'Inmobiliaria',
};

String _humanize(String code) {
  if (code.isEmpty) return '';
  final text = code.replaceAll('_', ' ');
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

DateTime? _parseDate(dynamic raw) =>
    raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

String? _nonEmpty(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

class MaintenanceRequest {
  final int id;
  final String ticket;
  final String status;
  final String priority;
  final String? responsibleParty;
  final bool needsReview;
  final String? reviewReason;

  final String? reporterName;
  final String? reporterPhone;
  final String? clientType;

  final String? contractNumber;
  final bool contractVerified;
  final String? propertyAddress;
  final String? city;
  final String? unit;
  final String? aptNum;

  final String? categoryLabel;
  final String? subcategoryLabel;

  /// `description_preview` en el listado, `description` en el detalle.
  final String? description;
  final bool isHappeningNow;
  final String? entryAuthorization;

  final int? assignedUserId;
  final String? assignedUserName;
  final int attachmentCount;

  final DateTime? submittedAt;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  // Solo en el detalle.
  final String? reporterDocument;
  final String? reporterEmail;
  final String? availableDays;
  final String? timeSlot;
  final String? availabilityNotes;
  final bool? consentAccepted;
  final String? consentPolicyVersion;
  final DateTime? consentAcceptedAt;

  const MaintenanceRequest({
    required this.id,
    required this.ticket,
    required this.status,
    required this.priority,
    this.responsibleParty,
    this.needsReview = false,
    this.reviewReason,
    this.reporterName,
    this.reporterPhone,
    this.clientType,
    this.contractNumber,
    this.contractVerified = false,
    this.propertyAddress,
    this.city,
    this.unit,
    this.aptNum,
    this.categoryLabel,
    this.subcategoryLabel,
    this.description,
    this.isHappeningNow = false,
    this.entryAuthorization,
    this.assignedUserId,
    this.assignedUserName,
    this.attachmentCount = 0,
    this.submittedAt,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.reporterDocument,
    this.reporterEmail,
    this.availableDays,
    this.timeSlot,
    this.availabilityNotes,
    this.consentAccepted,
    this.consentPolicyVersion,
    this.consentAcceptedAt,
  });

  factory MaintenanceRequest.fromJson(Map<String, dynamic> json) {
    return MaintenanceRequest(
      id: (json['id'] as num).toInt(),
      ticket: _nonEmpty(json['ticket']) ?? '#${json['id']}',
      status: (json['status'] as String?) ?? '',
      priority: (json['priority'] as String?) ?? '',
      responsibleParty: _nonEmpty(json['responsible_party']),
      needsReview: json['needs_review'] == true,
      reviewReason: _nonEmpty(json['review_reason']),
      reporterName: _nonEmpty(json['reporter_name']),
      reporterPhone: _nonEmpty(json['reporter_phone']),
      clientType: _nonEmpty(json['client_type']),
      contractNumber: _nonEmpty(json['contract_number']),
      contractVerified: json['contract_verified'] == true,
      propertyAddress: _nonEmpty(json['property_address']),
      city: _nonEmpty(json['city']),
      unit: _nonEmpty(json['unit']),
      aptNum: _nonEmpty(json['apt_num']),
      categoryLabel: _nonEmpty(json['category_label'] ?? json['category_code']),
      subcategoryLabel: _nonEmpty(
        json['subcategory_label'] ?? json['subcategory_code'],
      ),
      description: _nonEmpty(
        json['description'] ?? json['description_preview'],
      ),
      isHappeningNow: json['is_happening_now'] == true,
      entryAuthorization: _nonEmpty(json['entry_authorization']),
      assignedUserId: (json['assigned_user_id'] as num?)?.toInt(),
      assignedUserName: _nonEmpty(json['assigned_user_name']),
      attachmentCount: (json['attachment_count'] as num?)?.toInt() ?? 0,
      submittedAt: _parseDate(json['submitted_at']),
      closedAt: _parseDate(json['closed_at']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      isActive: json['is_active'] != false,
      reporterDocument: _nonEmpty(json['reporter_document']),
      reporterEmail: _nonEmpty(json['reporter_email']),
      // El formulario puede mandar los días como lista o como texto.
      availableDays: json['available_days'] is List
          ? _nonEmpty((json['available_days'] as List).join(', '))
          : _nonEmpty(json['available_days']),
      timeSlot: _nonEmpty(json['time_slot']),
      availabilityNotes: _nonEmpty(json['availability_notes']),
      consentAccepted: json['consent_accepted'] as bool?,
      consentPolicyVersion: _nonEmpty(json['consent_policy_version']),
      consentAcceptedAt: _parseDate(json['consent_accepted_at']),
    );
  }

  static List<MaintenanceRequest> listFromJson(
    List<Map<String, dynamic>> data,
  ) => data.map(MaintenanceRequest.fromJson).toList();

  String get statusLabel => MaintenanceStatus.label(status);
  String get priorityLabel => MaintenancePriority.label(priority);
  String? get responsiblePartyLabel => responsibleParty == null
      ? null
      : _responsiblePartyLabels[responsibleParty] ??
            _humanize(responsibleParty!);

  bool get isUnassigned => assignedUserId == null;

  /// "Eléctrico · Tomacorrientes", o lo que haya.
  String get categoryText =>
      [categoryLabel, subcategoryLabel].whereType<String>().join(' · ');

  /// Dirección con unidad y apartamento, sin la ciudad.
  String get fullAddress {
    final parts = <String>[
      ?propertyAddress,
      ?unit,
      if (aptNum != null) 'Apto $aptNum',
    ];
    return parts.join(', ');
  }

  /// Búsqueda local sobre los mismos campos que el parámetro `q` de la API.
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      ticket,
      reporterName,
      propertyAddress,
      city,
      contractNumber,
    ].whereType<String>().any((field) => field.toLowerCase().contains(q));
  }
}

class MaintenanceAttachment {
  final int id;
  final String phase;
  final int position;
  final String? originalName;
  final String? contentType;
  final int? sizeBytes;
  final String? url;
  final String? downloadUrl;
  final DateTime? urlExpiresAt;

  const MaintenanceAttachment({
    required this.id,
    required this.phase,
    required this.position,
    this.originalName,
    this.contentType,
    this.sizeBytes,
    this.url,
    this.downloadUrl,
    this.urlExpiresAt,
  });

  factory MaintenanceAttachment.fromJson(Map<String, dynamic> json) {
    return MaintenanceAttachment(
      id: (json['id'] as num).toInt(),
      phase: (json['phase'] as String?) ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      originalName: _nonEmpty(json['original_name']),
      contentType: _nonEmpty(json['content_type']),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      url: _nonEmpty(json['url']),
      downloadUrl: _nonEmpty(json['download_url']),
      urlExpiresAt: _parseDate(json['url_expires_at']),
    );
  }

  static List<MaintenanceAttachment> listFromJson(
    List<Map<String, dynamic>> data,
  ) => data.map(MaintenanceAttachment.fromJson).toList();

  static const phaseLabels = <String, String>{
    'antes': 'Antes',
    'despues': 'Después',
    'soportes': 'Soportes',
  };

  String get phaseLabel => phaseLabels[phase] ?? _humanize(phase);

  String get displayName => originalName ?? 'Archivo $position';

  /// SVG queda fuera a propósito: la API lo fuerza a descarga.
  bool get isImage =>
      (contentType?.startsWith('image/') ?? false) &&
      contentType != 'image/svg+xml';

  /// La URL firmada dura 15 min. Se da un margen para que no caduque entre
  /// que se toca el archivo y el navegador lo pide.
  bool isUrlExpired([DateTime? now]) {
    if (url == null || urlExpiresAt == null) return true;
    return !(now ?? DateTime.now()).isBefore(
      urlExpiresAt!.subtract(const Duration(seconds: 30)),
    );
  }

  String? get sizeText {
    final bytes = sizeBytes;
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MaintenanceEvent {
  final int id;
  final String eventType;
  final String? fromStatus;
  final String? toStatus;
  final String? note;
  final Map<String, dynamic>? metadata;
  final String? actorLabel;
  final String? actorName;
  final DateTime? createdAt;

  const MaintenanceEvent({
    required this.id,
    required this.eventType,
    this.fromStatus,
    this.toStatus,
    this.note,
    this.metadata,
    this.actorLabel,
    this.actorName,
    this.createdAt,
  });

  factory MaintenanceEvent.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    return MaintenanceEvent(
      id: (json['id'] as num).toInt(),
      eventType: (json['event_type'] as String?) ?? '',
      fromStatus: _nonEmpty(json['from_status']),
      toStatus: _nonEmpty(json['to_status']),
      note: _nonEmpty(json['note']),
      metadata: metadata is Map ? Map<String, dynamic>.from(metadata) : null,
      actorLabel: _nonEmpty(json['actor_label']),
      actorName: _nonEmpty(json['actor_name']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static List<MaintenanceEvent> listFromJson(List<Map<String, dynamic>> data) =>
      data.map(MaintenanceEvent.fromJson).toList();

  /// Quién lo hizo: el nombre del usuario o, si vino de otra fuente (web,
  /// n8n, sistema), esa etiqueta.
  String get actorText => actorName ?? actorLabel ?? 'Sistema';

  /// Título de una línea. Los tipos que no se conocen se muestran con su
  /// código legible en vez de fallar: otras fuentes pueden crear los suyos.
  String get title {
    switch (eventType) {
      case 'cambio_estado':
        if (fromStatus == null && toStatus != null) {
          return 'Estado: ${MaintenanceStatus.label(toStatus)}';
        }
        return 'Estado: ${MaintenanceStatus.label(fromStatus)} → '
            '${MaintenanceStatus.label(toStatus)}';
      case 'nota':
        return 'Nota';
      case 'asignacion':
        return 'Responsable: ${_metaValue('from', empty: 'Sin asignar')} → '
            '${_metaValue('to', empty: 'Sin asignar')}';
      case 'actualizacion':
        final field = metadata?['field']?.toString();
        if (field == null) return 'Actualización';
        return '${_fieldLabels[field] ?? _humanize(field)}: '
            '${_fieldValue(field, metadata?['from'])} → '
            '${_fieldValue(field, metadata?['to'])}';
      default:
        return eventType.isEmpty ? 'Evento' : _humanize(eventType);
    }
  }

  /// Texto adicional bajo el título (nota o motivo de revisión).
  String? get detail {
    if (eventType == 'actualizacion' && metadata?['field'] == 'needs_review') {
      final reason = _nonEmpty(metadata?['reason']);
      return [?reason, ?note].join('\n').ifEmptyNull;
    }
    return note;
  }

  String _metaValue(String key, {required String empty}) =>
      _nonEmpty(metadata?[key]) ?? empty;

  static const _fieldLabels = <String, String>{
    'priority': 'Prioridad',
    'responsible_party': 'Responsable del costo',
    'needs_review': 'Requiere revisión',
    'review_reason': 'Motivo de revisión',
  };

  static String _fieldValue(String field, dynamic value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Sí' : 'No';
    final text = value.toString();
    switch (field) {
      case 'priority':
        return MaintenancePriority.label(text);
      case 'responsible_party':
        return _responsiblePartyLabels[text] ?? _humanize(text);
      case 'status':
        return MaintenanceStatus.label(text);
    }
    return text;
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
