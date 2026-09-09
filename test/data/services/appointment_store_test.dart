import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inmobarco_app/data/services/appointment_store.dart';
import 'package:inmobarco_app/domain/models/appointment.dart';

void main() {
  late AppointmentStore store;

  Appointment sample({String id = 'apt_1', int? serverId, String? title}) =>
      Appointment(
        id: id,
        serverId: serverId,
        title: title ?? 'Visita $id',
        dateTime: DateTime(2026, 4, 1, 10, 0),
        createdAt: DateTime(2026, 3, 15),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = AppointmentStore();
  });

  test('is a singleton so the lock is shared', () {
    expect(AppointmentStore(), same(store));
  });

  group('readAll / writeAll', () {
    test('returns an empty list when there is nothing stored', () async {
      expect(await store.readAll(), isEmpty);
    });

    test('round-trips through the storage key', () async {
      await store.writeAll([sample(), sample(id: 'apt_2', serverId: 7)]);

      final result = await store.readAll();
      expect(result.map((a) => a.id), ['apt_1', 'apt_2']);
      expect(result[1].serverId, 7);

      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString(AppointmentStore.storageKey)!);
      expect(raw, hasLength(2));
    });
  });

  group('upsert', () {
    test('appends a new appointment', () async {
      await store.upsert(sample());
      await store.upsert(sample(id: 'apt_2'));

      expect((await store.readAll()).map((a) => a.id), ['apt_1', 'apt_2']);
    });

    test('replaces the appointment with the same id, keeping order', () async {
      await store.writeAll([sample(), sample(id: 'apt_2')]);

      await store.upsert(sample(title: 'Reagendada'));

      final result = await store.readAll();
      expect(result.map((a) => a.id), ['apt_1', 'apt_2']);
      expect(result.first.title, 'Reagendada');
    });
  });

  group('remove', () {
    test('deletes only the requested appointment', () async {
      await store.writeAll([sample(), sample(id: 'apt_2')]);

      await store.remove('apt_1');

      expect((await store.readAll()).single.id, 'apt_2');
    });

    test('is a no-op for an unknown id', () async {
      await store.writeAll([sample()]);

      await store.remove('nope');

      expect(await store.readAll(), hasLength(1));
    });
  });

  group('serverId', () {
    test('setServerId updates just that appointment', () async {
      await store.writeAll([sample(), sample(id: 'apt_2')]);

      await store.setServerId('apt_1', 55);

      final result = await store.readAll();
      expect(result.firstWhere((a) => a.id == 'apt_1').serverId, 55);
      expect(result.firstWhere((a) => a.id == 'apt_2').serverId, isNull);
    });

    test('findServerId reads it back', () async {
      await store.writeAll([sample(serverId: 12)]);

      expect(await store.findServerId('apt_1'), 12);
      expect(await store.findServerId('missing'), isNull);
    });
  });

  group('concurrencia', () {
    test('serializes concurrent writes instead of clobbering', () async {
      // Sin lock, estos upserts leerían todos la misma lista vacía y solo
      // sobreviviría el último: es exactamente la carrera entre una mutación
      // de la UI y el merge de un pull.
      await Future.wait([
        store.upsert(sample(id: 'a')),
        store.upsert(sample(id: 'b')),
        store.upsert(sample(id: 'c')),
      ]);

      final result = await store.readAll();
      expect(result.map((a) => a.id).toSet(), {'a', 'b', 'c'});
    });

    test('a merge does not lose an appointment added in parallel', () async {
      await store.writeAll([sample(id: 'local', serverId: 1)]);

      // El merge simula un pull: reemplaza la lista por lo que trae el
      // servidor y conserva las locales sin serverId.
      final merge = store.update((current) {
        final unsynced = current.where((a) => a.serverId == null).toList();
        return [sample(id: 'local', serverId: 1, title: 'Del servidor'), ...unsynced];
      });
      final add = store.upsert(sample(id: 'nueva'));

      await Future.wait([merge, add]);

      final result = await store.readAll();
      expect(result.map((a) => a.id).toSet(), {'local', 'nueva'});
    });

    test('a failing operation does not break the queue', () async {
      await expectLater(
        store.update((_) => throw StateError('boom')),
        throwsStateError,
      );

      await store.upsert(sample());
      expect((await store.readAll()).single.id, 'apt_1');
    });
  });
}
