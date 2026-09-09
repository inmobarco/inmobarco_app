import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inmobarco_app/core/services/notification_service.dart';
import 'package:inmobarco_app/data/services/appointment_store.dart';
import 'package:inmobarco_app/data/services/sync_service.dart';
import 'package:inmobarco_app/domain/models/appointment.dart';

@GenerateMocks([NotificationService])
import 'sync_service_test.mocks.dart';

/// `SyncService` habla con el `ApiService` estático. Sin dotenv cargado, toda
/// salida a la red lanza `NotInitializedError` al resolver la URL base — antes
/// de abrir un socket — así que la cola se puede ejercitar sin red: las
/// operaciones que llegan a la API fallan de forma determinista y quedan
/// pendientes, y las que la compactación descarta nunca la alcanzan.
void main() {
  late SyncService sync;
  late AppointmentStore store;

  Appointment sample({String id = 'apt_1', int? serverId}) => Appointment(
        id: id,
        serverId: serverId,
        title: 'Visita',
        dateTime: DateTime(2026, 4, 1, 10, 0),
        createdAt: DateTime(2026, 3, 15),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = AppointmentStore();
    sync = SyncService(
      notificationService: MockNotificationService(),
      store: store,
    );
  });

  group('enqueue', () {
    test('stamps the entity so the queue can hold more than appointments',
        () async {
      await sync.enqueue(
        action: 'create',
        localId: 'apt_1',
        payload: const {'title': 'Visita'},
      );
      await sync.enqueue(
        entity: SyncService.entityClient,
        action: 'create',
        localId: 'client_3001234567',
        payload: const {'first_name': 'Ana'},
      );

      final prefs = await SharedPreferences.getInstance();
      final queue = json.decode(
          prefs.getString('appointments_pending_sync')!) as List<dynamic>;

      expect(queue, hasLength(2));
      expect(queue[0]['entity'], SyncService.entityAppointment);
      expect(queue[1]['entity'], SyncService.entityClient);
      expect(await sync.pendingCount, 2);
    });
  });

  group('compactación', () {
    test('cancels a CREATE + DELETE of the same appointment', () async {
      await sync.enqueue(
        action: 'create',
        localId: 'apt_1',
        payload: const {'title': 'Visita'},
      );
      await sync.enqueue(
        action: 'delete',
        localId: 'apt_1',
        payload: const {},
      );

      await sync.syncPendingQueue();

      // Se creó y se borró estando sin red: no hay nada que enviar, y la cola
      // queda vacía sin llegar a la API.
      expect(await sync.pendingCount, 0);
    });

    test('does not merge CRM payloads with appointment rules', () async {
      // El payload de crear un cliente en WASI no tiene la forma del de
      // actualizarlo, así que fusionarlos produciría un cuerpo inválido.
      await sync.enqueue(
        entity: SyncService.entityClient,
        action: 'create',
        localId: 'client_1',
        payload: const {'first_name': 'Ana', 'cell_phone': '3001234567'},
      );
      await sync.enqueue(
        entity: SyncService.entityClient,
        action: 'update',
        localId: 'client_1',
        payload: const {'id_client': 1, 'first_name': 'Ana María'},
      );

      await sync.syncPendingQueue();

      // Ambas siguen pendientes y por separado: sin red no salieron, pero
      // tampoco se fusionaron.
      final prefs = await SharedPreferences.getInstance();
      final queue = json.decode(
          prefs.getString('appointments_pending_sync')!) as List<dynamic>;
      expect(queue, hasLength(2));
      expect(queue[0]['action'], 'create');
      expect(queue[1]['action'], 'update');
    });

    test('a queued CRM operation survives a failed attempt', () async {
      await sync.enqueue(
        entity: SyncService.entityClientNote,
        action: 'create',
        localId: 'note_1',
        payload: const {'id_client_wasi': 1, 'note': 'Llamada', 'note_type': 'llamada'},
      );

      await sync.syncPendingQueue();

      expect(await sync.pendingCount, 1);
    });
  });

  group('purgeLocalId', () {
    test('drops every pending operation of that appointment', () async {
      await sync.enqueue(
          action: 'create', localId: 'apt_1', payload: const {});
      await sync.enqueue(
          action: 'update', localId: 'apt_1', payload: const {});
      await sync.enqueue(
          action: 'create', localId: 'apt_2', payload: const {});

      await sync.purgeLocalId('apt_1');

      expect(await sync.pendingCount, 1);
    });
  });

  group('resetForLogout', () {
    test('clears appointments, queue and the delta mark', () async {
      SharedPreferences.setMockInitialValues({
        'last_appointments_sync': DateTime(2026, 5, 1).millisecondsSinceEpoch,
      });
      await store.writeAll([sample(serverId: 10), sample(id: 'apt_2')]);
      await sync.enqueue(
          action: 'update', localId: 'apt_2', payload: const {});

      await sync.resetForLogout();

      // La agenda es del asesor, no del dispositivo.
      expect(await store.readAll(), isEmpty);
      expect(await sync.pendingCount, 0);
      // Y sin la marca, el primer sync del siguiente asesor vuelve a ser
      // completo en vez de un delta que nunca traería su agenda.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('last_appointments_sync'), isNull);
    });
  });
}
