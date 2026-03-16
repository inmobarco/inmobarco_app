import 'package:flutter_test/flutter_test.dart';
import 'package:inmobarco_app/domain/models/appointment.dart';

void main() {
  Appointment sampleAppointment() => Appointment(
        id: 'local_1',
        serverId: 42,
        title: 'Visita Apto 301',
        description: 'Visita con cliente',
        dateTime: DateTime(2026, 3, 20, 10, 30),
        duration: const Duration(minutes: 45),
        type: AppointmentType.visit,
        status: AppointmentStatus.confirmed,
        propertyId: 'prop_123',
        propertyAddress: 'Cra 43A #1-50',
        clientName: 'María López',
        clientPhone: '3001234567',
        notes: 'Llevar llaves',
        createdAt: DateTime(2026, 3, 15, 8, 0),
        updatedAt: DateTime(2026, 3, 16, 9, 0),
      );

  group('Appointment.toJson / fromJson roundtrip', () {
    test('preserves all fields', () {
      final original = sampleAppointment();
      final json = original.toJson();
      final restored = Appointment.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.serverId, original.serverId);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.dateTime, original.dateTime);
      expect(restored.duration, original.duration);
      expect(restored.type, original.type);
      expect(restored.status, original.status);
      expect(restored.propertyId, original.propertyId);
      expect(restored.propertyAddress, original.propertyAddress);
      expect(restored.clientName, original.clientName);
      expect(restored.clientPhone, original.clientPhone);
      expect(restored.notes, original.notes);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('handles null optional fields', () {
      final minimal = Appointment(
        id: 'min_1',
        title: 'Test',
        dateTime: DateTime(2026, 4, 1),
        createdAt: DateTime(2026, 3, 15),
      );
      final json = minimal.toJson();
      final restored = Appointment.fromJson(json);

      expect(restored.serverId, isNull);
      expect(restored.description, isNull);
      expect(restored.propertyId, isNull);
      expect(restored.clientName, isNull);
      expect(restored.notes, isNull);
      expect(restored.updatedAt, isNull);
      expect(restored.type, AppointmentType.visit);
      expect(restored.status, AppointmentStatus.pending);
    });
  });

  group('Appointment.toApiJson', () {
    test('produces correct API format', () {
      final apt = sampleAppointment();
      final apiJson = apt.toApiJson();

      expect(apiJson['title'], 'Visita Apto 301');
      expect(apiJson['description'], 'Visita con cliente');
      expect(apiJson['appointment_date'], isA<String>());
      expect(apiJson['duration_minutes'], 45);
      expect(apiJson['client_name'], 'María López');
      expect(apiJson['client_phone'], '3001234567');
      expect(apiJson['appointment_type'], 'visit');
      expect(apiJson['status'], 'confirmed');
      // Should NOT contain local-only fields
      expect(apiJson.containsKey('id'), isFalse);
      expect(apiJson.containsKey('serverId'), isFalse);
      expect(apiJson.containsKey('propertyId'), isFalse);
      expect(apiJson.containsKey('notes'), isFalse);
    });
  });

  group('Appointment.fromApiJson', () {
    test('parses server response correctly', () {
      final serverJson = {
        'id': 99,
        'title': 'Reunión Firma',
        'description': 'Firma del contrato',
        'appointment_date': '2026-03-20T15:30:00.000Z',
        'duration_minutes': 60,
        'appointment_type': 'signing',
        'status': 'pending',
        'client_name': 'Carlos Pérez',
        'client_phone': '3109876543',
        'created_at': '2026-03-10T10:00:00.000Z',
        'updated_at': '2026-03-11T12:00:00.000Z',
      };

      final apt = Appointment.fromApiJson(serverJson);

      expect(apt.id, 'srv_99');
      expect(apt.serverId, 99);
      expect(apt.title, 'Reunión Firma');
      expect(apt.description, 'Firma del contrato');
      expect(apt.duration.inMinutes, 60);
      expect(apt.type, AppointmentType.signing);
      expect(apt.status, AppointmentStatus.pending);
      expect(apt.clientName, 'Carlos Pérez');
      expect(apt.clientPhone, '3109876543');
      expect(apt.createdAt, isNotNull);
      expect(apt.updatedAt, isNotNull);
    });

    test('handles unknown type/status with defaults', () {
      final serverJson = {
        'id': 1,
        'title': 'Test',
        'appointment_date': '2026-03-20T10:00:00.000Z',
        'appointment_type': 'unknown_type',
        'status': 'unknown_status',
        'created_at': '2026-03-10T10:00:00.000Z',
      };

      final apt = Appointment.fromApiJson(serverJson);

      expect(apt.type, AppointmentType.visit); // default
      expect(apt.status, AppointmentStatus.pending); // default
    });

    test('handles missing optional fields', () {
      final serverJson = {
        'id': 2,
        'title': 'Minimal',
        'appointment_date': '2026-04-01T10:00:00.000Z',
        'appointment_type': 'visit',
        'status': 'pending',
      };

      final apt = Appointment.fromApiJson(serverJson);

      expect(apt.description, isNull);
      expect(apt.clientName, isNull);
      expect(apt.clientPhone, isNull);
      expect(apt.updatedAt, isNull);
    });
  });

  group('Appointment.copyWith', () {
    test('changes specified fields', () {
      final original = sampleAppointment();
      final copy = original.copyWith(
        title: 'Updated Title',
        status: AppointmentStatus.cancelled,
      );

      expect(copy.title, 'Updated Title');
      expect(copy.status, AppointmentStatus.cancelled);
      // Unchanged
      expect(copy.id, original.id);
      expect(copy.serverId, original.serverId);
      expect(copy.dateTime, original.dateTime);
      expect(copy.clientName, original.clientName);
    });

    test('no changes returns equivalent object', () {
      final original = sampleAppointment();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.status, original.status);
    });
  });

  group('Appointment computed properties', () {
    test('endTime adds duration to dateTime', () {
      final apt = sampleAppointment();
      expect(apt.endTime, DateTime(2026, 3, 20, 11, 15));
    });

    test('isToday returns true for today', () {
      final now = DateTime.now();
      final apt = sampleAppointment().copyWith(
        dateTime: DateTime(now.year, now.month, now.day, 14, 0),
      );
      expect(apt.isToday, isTrue);
    });

    test('isToday returns false for other days', () {
      final apt = sampleAppointment().copyWith(
        dateTime: DateTime(2099, 1, 1),
      );
      expect(apt.isToday, isFalse);
    });

    test('isPast returns true for past dates', () {
      final apt = sampleAppointment().copyWith(
        dateTime: DateTime(2020, 1, 1),
      );
      expect(apt.isPast, isTrue);
    });

    test('isPast returns false for future dates', () {
      final apt = sampleAppointment().copyWith(
        dateTime: DateTime(2099, 1, 1),
      );
      expect(apt.isPast, isFalse);
    });

    test('toString contains id and title', () {
      final apt = sampleAppointment();
      expect(apt.toString(), contains('local_1'));
      expect(apt.toString(), contains('Visita Apto 301'));
    });
  });

  group('AppointmentType extension', () {
    test('displayName returns Spanish labels', () {
      expect(AppointmentType.visit.displayName, 'Visita');
      expect(AppointmentType.meeting.displayName, 'Reunión');
      expect(AppointmentType.signing.displayName, 'Firma');
      expect(AppointmentType.followUp.displayName, 'Seguimiento');
      expect(AppointmentType.other.displayName, 'Otro');
    });

    test('icon returns emoji for each type', () {
      expect(AppointmentType.visit.icon, '🏠');
      expect(AppointmentType.signing.icon, '📝');
    });
  });

  group('AppointmentStatus extension', () {
    test('displayName returns Spanish labels', () {
      expect(AppointmentStatus.pending.displayName, 'Pendiente');
      expect(AppointmentStatus.confirmed.displayName, 'Confirmada');
      expect(AppointmentStatus.completed.displayName, 'Completada');
      expect(AppointmentStatus.cancelled.displayName, 'Cancelada');
    });

    test('colorValue returns distinct colors', () {
      final colors = AppointmentStatus.values.map((s) => s.colorValue).toSet();
      expect(colors.length, AppointmentStatus.values.length);
    });
  });
}
