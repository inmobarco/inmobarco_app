import 'package:flutter_test/flutter_test.dart';
import 'package:inmobarco_app/domain/models/maintenance_request.dart';

void main() {
  // Elemento del listado tal como lo documenta GET /staff/maintenance/requests.
  final listItem = <String, dynamic>{
    'id': 67,
    'ticket': 'MNT-000067',
    'status': 'recibida',
    'priority': 'alta',
    'responsible_party': 'arrendatario',
    'needs_review': false,
    'review_reason': null,
    'reporter_name': 'Ana Gómez',
    'reporter_phone': '3001234567',
    'client_type': 'arrendatario',
    'contract_number': '845A',
    'contract_verified': true,
    'property_address': 'Cra 43 #30-10',
    'city': 'Sabaneta',
    'unit': 'Torre 2',
    'apt_num': '502',
    'category_code': 'electrico',
    'category_label': 'Eléctrico',
    'subcategory_code': 'tomas',
    'subcategory_label': 'Tomacorrientes',
    'description_preview': 'No funciona el toma de la cocina',
    'is_happening_now': true,
    'entry_authorization': 'Con portería',
    'assigned_user_id': null,
    'assigned_user_name': null,
    'attachment_count': 3,
    'submitted_at': '2026-10-19T14:00:00Z',
    'closed_at': null,
    'created_at': '2026-10-19T14:00:05Z',
    'updated_at': '2026-10-19T15:00:00Z',
    'is_active': true,
  };

  group('MaintenanceRequest.fromJson', () {
    test('parses a list item', () {
      final r = MaintenanceRequest.fromJson(listItem);

      expect(r.id, 67);
      expect(r.ticket, 'MNT-000067');
      expect(r.statusLabel, 'Recibida');
      expect(r.priorityLabel, 'Alta');
      expect(r.responsiblePartyLabel, 'Arrendatario');
      expect(r.description, 'No funciona el toma de la cocina');
      expect(r.categoryText, 'Eléctrico · Tomacorrientes');
      expect(r.fullAddress, 'Cra 43 #30-10, Torre 2, Apto 502');
      expect(r.isUnassigned, isTrue);
      expect(r.attachmentCount, 3);
      expect(r.isHappeningNow, isTrue);
      expect(r.createdAt, DateTime.utc(2026, 10, 19, 14, 0, 5));
      expect(r.closedAt, isNull);
      expect(r.reporterEmail, isNull);
    });

    test('detail prefers full description and reads detail-only fields', () {
      final r = MaintenanceRequest.fromJson({
        ...listItem,
        'description': 'Descripción completa',
        'reporter_document': '1037000000',
        'reporter_email': 'ana@example.com',
        'available_days': ['lunes', 'miércoles'],
        'time_slot': 'mañana',
        'consent_accepted': true,
        'assigned_user_id': 7,
        'assigned_user_name': 'Juan Pérez',
      });

      expect(r.description, 'Descripción completa');
      expect(r.reporterDocument, '1037000000');
      expect(r.availableDays, 'lunes, miércoles');
      expect(r.consentAccepted, isTrue);
      expect(r.assignedUserId, 7);
      expect(r.isUnassigned, isFalse);
    });

    test('tolerates missing optional fields and unknown codes', () {
      final r = MaintenanceRequest.fromJson({
        'id': 1,
        'status': 'otro_estado',
        'priority': '',
        'property_address': '  ',
      });

      expect(r.ticket, '#1');
      expect(r.statusLabel, 'Otro estado');
      expect(r.propertyAddress, isNull);
      expect(r.fullAddress, '');
      expect(r.categoryText, '');
      expect(r.isActive, isTrue);
    });
  });

  group('MaintenanceRequest.matchesQuery', () {
    final r = MaintenanceRequest.fromJson(listItem);

    test('matches ticket, name, address, city and contract', () {
      expect(r.matchesQuery('mnt-000067'), isTrue);
      expect(r.matchesQuery('ana'), isTrue);
      expect(r.matchesQuery('cra 43'), isTrue);
      expect(r.matchesQuery('SABANETA'), isTrue);
      expect(r.matchesQuery('845a'), isTrue);
      expect(r.matchesQuery('  '), isTrue);
    });

    test('ignores other fields', () {
      expect(r.matchesQuery('cocina'), isFalse);
      expect(r.matchesQuery('envigado'), isFalse);
    });
  });

  group('MaintenanceAttachment', () {
    Map<String, dynamic> attachment({
      String contentType = 'image/jpeg',
      String? expiresAt = '2026-10-20T15:30:00Z',
    }) =>
        {
          'id': 1,
          'request_id': 67,
          'phase': 'despues',
          'position': 1,
          'original_name': 'foto.jpg',
          'content_type': contentType,
          'size_bytes': 1572864,
          'url': 'https://r2.example/foto.jpg',
          'download_url': 'https://r2.example/foto.jpg?download',
          'url_expires_at': expiresAt,
        };

    test('parses and labels', () {
      final a = MaintenanceAttachment.fromJson(attachment());
      expect(a.phaseLabel, 'Después');
      expect(a.isImage, isTrue);
      expect(a.sizeText, '1.5 MB');
    });

    test('svg and pdf are not shown as images', () {
      expect(
        MaintenanceAttachment.fromJson(attachment(contentType: 'image/svg+xml'))
            .isImage,
        isFalse,
      );
      expect(
        MaintenanceAttachment.fromJson(
          attachment(contentType: 'application/pdf'),
        ).isImage,
        isFalse,
      );
    });

    test('url expires with a safety margin', () {
      final a = MaintenanceAttachment.fromJson(attachment());
      expect(a.isUrlExpired(DateTime.utc(2026, 10, 20, 15, 0)), isFalse);
      expect(a.isUrlExpired(DateTime.utc(2026, 10, 20, 15, 29, 45)), isTrue);
      expect(a.isUrlExpired(DateTime.utc(2026, 10, 20, 16, 0)), isTrue);
    });

    test('missing expiry counts as expired', () {
      final a = MaintenanceAttachment.fromJson(attachment(expiresAt: null));
      expect(a.isUrlExpired(), isTrue);
    });
  });

  group('MaintenanceEvent', () {
    MaintenanceEvent event(Map<String, dynamic> fields) =>
        MaintenanceEvent.fromJson({'id': 1, 'request_id': 67, ...fields});

    test('status change', () {
      final e = event({
        'event_type': 'cambio_estado',
        'from_status': 'recibida',
        'to_status': 'programada',
        'note': 'Visita el jueves',
        'actor_name': 'Juan Pérez',
        'actor_label': 'api',
      });
      expect(e.title, 'Estado: Recibida → Programada');
      expect(e.detail, 'Visita el jueves');
      expect(e.actorText, 'Juan Pérez');
    });

    test('assignment with null from', () {
      final e = event({
        'event_type': 'asignacion',
        'metadata': {'from': null, 'to': 'Juan Pérez'},
      });
      expect(e.title, 'Responsable: Sin asignar → Juan Pérez');
    });

    test('field update maps known values', () {
      final e = event({
        'event_type': 'actualizacion',
        'metadata': {'field': 'priority', 'from': 'media', 'to': 'urgente'},
      });
      expect(e.title, 'Prioridad: Media → Urgente');
    });

    test('needs_review update shows the reason', () {
      final e = event({
        'event_type': 'actualizacion',
        'metadata': {
          'field': 'needs_review',
          'from': false,
          'to': true,
          'reason': 'Contrato no coincide',
        },
      });
      expect(e.title, 'Requiere revisión: No → Sí');
      expect(e.detail, 'Contrato no coincide');
    });

    test('unknown types render generically', () {
      final e = event({
        'event_type': 'recordatorio_enviado',
        'metadata': 'not a map',
        'actor_label': 'n8n',
      });
      expect(e.title, 'Recordatorio enviado');
      expect(e.metadata, isNull);
      expect(e.actorText, 'n8n');
    });
  });
}
