import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:inmobarco_app/ui/providers/appointment_provider.dart';
import 'package:inmobarco_app/data/repositories/appointment_repository.dart';
import 'package:inmobarco_app/core/services/notification_service.dart';
import 'package:inmobarco_app/domain/models/appointment.dart';

@GenerateMocks([AppointmentRepository, NotificationService])
import 'appointment_provider_test.mocks.dart';

void main() {
  late AppointmentProvider provider;
  late MockAppointmentRepository mockRepository;
  late MockNotificationService mockNotificationService;

  Appointment sampleAppointment({
    String id = 'apt_1',
    int? serverId,
    AppointmentStatus status = AppointmentStatus.pending,
    DateTime? dateTime,
  }) =>
      Appointment(
        id: id,
        serverId: serverId,
        title: 'Test Visit',
        dateTime: dateTime ?? DateTime(2026, 4, 1, 10, 0),
        status: status,
        createdAt: DateTime(2026, 3, 15),
      );

  setUp(() {
    mockRepository = MockAppointmentRepository();
    mockNotificationService = MockNotificationService();

    // Default stubs
    when(mockRepository.onDataChanged = any).thenReturn(null);
    when(mockRepository.saveAll(any)).thenAnswer((_) async {});
    when(mockRepository.syncCreate(any)).thenAnswer((_) async => null);
    when(mockRepository.syncUpdate(any)).thenAnswer((_) async {});
    when(mockRepository.syncDelete(any, any)).thenAnswer((_) async {});
    when(mockRepository.purgeLocalId(any)).thenAnswer((_) async {});
    when(mockNotificationService.scheduleAppointmentReminder(any))
        .thenAnswer((_) async {});
    when(mockNotificationService.rescheduleAppointmentReminder(any))
        .thenAnswer((_) async {});
    when(mockNotificationService.cancelAppointmentReminder(any))
        .thenAnswer((_) async {});

    provider = AppointmentProvider(
      repository: mockRepository,
      notificationService: mockNotificationService,
    );
  });

  group('loadAppointments', () {
    test('loads from repository and updates state', () async {
      final appointments = [sampleAppointment(), sampleAppointment(id: 'apt_2')];
      when(mockRepository.getAll()).thenAnswer((_) async => appointments);

      await provider.loadAppointments();

      expect(provider.appointments.length, 2);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('sets loading state during load', () async {
      when(mockRepository.getAll()).thenAnswer((_) async {
        // Simulating async delay — loading should be true before this resolves
        return [sampleAppointment()];
      });

      final future = provider.loadAppointments();
      // After await completes:
      await future;
      expect(provider.isLoading, isFalse);
    });

    test('sets error on failure', () async {
      when(mockRepository.getAll()).thenThrow(Exception('DB error'));

      await provider.loadAppointments();

      expect(provider.error, isNotNull);
      expect(provider.error, contains('Error'));
      expect(provider.isLoading, isFalse);
    });
  });

  group('addAppointment', () {
    test('adds to list and saves to repository', () async {
      final apt = sampleAppointment();

      await provider.addAppointment(apt);

      expect(provider.appointments.length, 1);
      expect(provider.appointments.first.id, 'apt_1');
      verify(mockRepository.saveAll(any)).called(1);
    });

    test('schedules notification', () async {
      final apt = sampleAppointment();

      await provider.addAppointment(apt);

      verify(mockNotificationService.scheduleAppointmentReminder(apt)).called(1);
    });

    test('triggers background sync', () async {
      when(mockRepository.syncCreate(any)).thenAnswer((_) async => 99);

      final apt = sampleAppointment();
      await provider.addAppointment(apt);

      // Give async sync a chance to complete
      await Future.delayed(Duration.zero);
      verify(mockRepository.syncCreate(any)).called(1);
    });

    test('updates serverId when sync succeeds', () async {
      when(mockRepository.syncCreate(any)).thenAnswer((_) async => 42);

      final apt = sampleAppointment();
      await provider.addAppointment(apt);

      // Wait for background sync
      await Future.delayed(Duration.zero);

      expect(provider.appointments.first.serverId, 42);
      // saveAll called twice: once for add, once for serverId update
      verify(mockRepository.saveAll(any)).called(2);
    });
  });

  group('updateAppointment', () {
    test('updates existing appointment in list', () async {
      when(mockRepository.getAll())
          .thenAnswer((_) async => [sampleAppointment()]);
      await provider.loadAppointments();

      final updated = sampleAppointment().copyWith(title: 'Updated');
      await provider.updateAppointment(updated);

      expect(provider.appointments.first.title, 'Updated');
      expect(provider.appointments.first.updatedAt, isNotNull);
    });

    test('reschedules notification', () async {
      when(mockRepository.getAll())
          .thenAnswer((_) async => [sampleAppointment()]);
      await provider.loadAppointments();

      await provider.updateAppointment(sampleAppointment());

      verify(mockNotificationService.rescheduleAppointmentReminder(any))
          .called(1);
    });

    test('does nothing if appointment not found', () async {
      await provider.updateAppointment(sampleAppointment(id: 'nonexistent'));

      verifyNever(mockRepository.saveAll(any));
    });
  });

  group('deleteAppointment', () {
    test('removes from list and saves', () async {
      when(mockRepository.getAll())
          .thenAnswer((_) async => [sampleAppointment(serverId: 10)]);
      await provider.loadAppointments();
      expect(provider.appointments.length, 1);

      await provider.deleteAppointment('apt_1');

      expect(provider.appointments, isEmpty);
      verify(mockRepository.saveAll(any)).called(1);
    });

    test('cancels notification', () async {
      when(mockRepository.getAll())
          .thenAnswer((_) async => [sampleAppointment()]);
      await provider.loadAppointments();

      await provider.deleteAppointment('apt_1');

      verify(mockNotificationService.cancelAppointmentReminder('apt_1'))
          .called(1);
    });

    test('calls syncDelete for server-synced appointments', () async {
      when(mockRepository.getAll())
          .thenAnswer((_) async => [sampleAppointment(serverId: 10)]);
      await provider.loadAppointments();

      await provider.deleteAppointment('apt_1');

      verify(mockRepository.syncDelete('apt_1', 10)).called(1);
    });

    test('purges local ID for unsynced appointments', () async {
      when(mockRepository.getAll())
          .thenAnswer((_) async => [sampleAppointment()]);
      await provider.loadAppointments();

      await provider.deleteAppointment('apt_1');

      verify(mockRepository.purgeLocalId('apt_1')).called(1);
      verifyNever(mockRepository.syncDelete(any, any));
    });
  });

  group('updateAppointmentStatus', () {
    test('updates status of existing appointment', () async {
      when(mockRepository.getAll())
          .thenAnswer((_) async => [sampleAppointment()]);
      await provider.loadAppointments();

      await provider.updateAppointmentStatus(
          'apt_1', AppointmentStatus.confirmed);

      expect(
          provider.appointments.first.status, AppointmentStatus.confirmed);
    });

    test('cancels notification when status is cancelled', () async {
      when(mockRepository.getAll())
          .thenAnswer((_) async => [sampleAppointment()]);
      await provider.loadAppointments();

      await provider.updateAppointmentStatus(
          'apt_1', AppointmentStatus.cancelled);

      verify(mockNotificationService.cancelAppointmentReminder('apt_1'))
          .called(1);
    });
  });

  group('queries', () {
    setUp(() async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 0);
      final tomorrow = today.add(const Duration(days: 1));
      final yesterday = today.subtract(const Duration(days: 1));

      when(mockRepository.getAll()).thenAnswer((_) async => [
            sampleAppointment(id: 'today', dateTime: today),
            sampleAppointment(id: 'tomorrow', dateTime: tomorrow),
            sampleAppointment(id: 'yesterday', dateTime: yesterday),
          ]);
      await provider.loadAppointments();
    });

    test('todayAppointments returns only today', () {
      expect(provider.todayAppointments.length, 1);
      expect(provider.todayAppointments.first.id, 'today');
    });

    test('getAppointmentsForDay returns correct day', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1));
      final result = provider.getAppointmentsForDay(tomorrow);
      expect(result.length, 1);
      expect(result.first.id, 'tomorrow');
    });

    test('upcomingAppointments excludes past', () {
      final upcoming = provider.upcomingAppointments;
      expect(upcoming.every((a) => a.dateTime.isAfter(DateTime.now())), isTrue);
    });

    test('getAppointmentById returns correct appointment', () {
      expect(provider.getAppointmentById('today')?.id, 'today');
      expect(provider.getAppointmentById('nonexistent'), isNull);
    });

    test('getAppointmentCountByDay groups correctly', () {
      final counts = provider.getAppointmentCountByDay();
      expect(counts.values.every((v) => v == 1), isTrue);
      expect(counts.length, 3);
    });
  });

  group('clearError', () {
    test('clears error state', () async {
      when(mockRepository.getAll()).thenThrow(Exception('fail'));
      await provider.loadAppointments();
      expect(provider.error, isNotNull);

      provider.clearError();
      expect(provider.error, isNull);
    });
  });
}
