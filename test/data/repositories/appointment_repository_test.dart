import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inmobarco_app/data/repositories/appointment_repository.dart';
import 'package:inmobarco_app/data/services/sync_service.dart';
import 'package:inmobarco_app/domain/models/appointment.dart';

@GenerateMocks([SyncService])
import 'appointment_repository_test.mocks.dart';

void main() {
  late AppointmentRepository repository;
  late MockSyncService mockSyncService;

  Appointment sampleAppointment({String id = 'apt_1', int? serverId}) =>
      Appointment(
        id: id,
        serverId: serverId,
        title: 'Test Visit',
        dateTime: DateTime(2026, 4, 1, 10, 0),
        createdAt: DateTime(2026, 3, 15),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSyncService = MockSyncService();
    // Stub the setOnPullCompleted call in constructor
    when(mockSyncService.setOnPullCompleted(any)).thenReturn(null);
    repository = AppointmentRepository(syncService: mockSyncService);
  });

  group('getAll', () {
    test('returns empty list when no data', () async {
      final result = await repository.getAll();
      expect(result, isEmpty);
    });

    test('returns saved appointments', () async {
      final appointments = [sampleAppointment(), sampleAppointment(id: 'apt_2')];
      await repository.saveAll(appointments);

      final result = await repository.getAll();
      expect(result.length, 2);
      expect(result[0].id, 'apt_1');
      expect(result[1].id, 'apt_2');
    });
  });

  group('saveAll', () {
    test('persists appointments to SharedPreferences', () async {
      final appointments = [sampleAppointment()];
      await repository.saveAll(appointments);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('appointments_cache');
      expect(raw, isNotNull);

      final list = json.decode(raw!) as List;
      expect(list.length, 1);
      expect(list[0]['id'], 'apt_1');
    });

    test('overwrites previous data', () async {
      await repository.saveAll([sampleAppointment(id: 'old')]);
      await repository.saveAll([sampleAppointment(id: 'new')]);

      final result = await repository.getAll();
      expect(result.length, 1);
      expect(result[0].id, 'new');
    });
  });

  group('syncCreate', () {
    // ApiService is static and unmockable. Without dotenv loaded it throws
    // NotInitializedError while resolving the base URL, before opening any
    // socket, so the failure path is deterministic and offline.
    test('enqueues on failure', () async {
      when(mockSyncService.enqueue(
        action: anyNamed('action'),
        localId: anyNamed('localId'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async {});

      final result = await repository.syncCreate(sampleAppointment());

      expect(result, isNull);
      verify(mockSyncService.enqueue(
        action: 'create',
        localId: 'apt_1',
        payload: anyNamed('payload'),
      )).called(1);
    });
  });

  group('syncUpdate', () {
    test('enqueues without hitting the API when serverId is missing', () async {
      when(mockSyncService.enqueue(
        action: anyNamed('action'),
        localId: anyNamed('localId'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async {});

      await repository.syncUpdate(sampleAppointment());

      verify(mockSyncService.enqueue(
        action: 'update',
        localId: 'apt_1',
        payload: anyNamed('payload'),
      )).called(1);
    });
  });

  group('purgeLocalId', () {
    test('delegates to syncService', () async {
      when(mockSyncService.purgeLocalId(any)).thenAnswer((_) async {});

      await repository.purgeLocalId('apt_1');

      verify(mockSyncService.purgeLocalId('apt_1')).called(1);
    });
  });

  group('onDataChanged callback', () {
    test('registers pull callback on construction', () {
      verify(mockSyncService.setOnPullCompleted(any)).called(1);
    });
  });
}
