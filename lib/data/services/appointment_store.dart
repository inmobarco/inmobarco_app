import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/appointment.dart';

/// Almacenamiento local de citas y **único escritor** de la clave
/// `appointments_cache`.
///
/// Todas las operaciones de lectura-modificación-escritura se serializan en un
/// lock interno, de modo que las mutaciones de la UI y los merges de
/// [SyncService] no puedan sobrescribirse entre sí.
///
/// Es un singleton a propósito: dos instancias serían dos locks y la garantía
/// dejaría de existir.
class AppointmentStore {
  AppointmentStore._();

  static final AppointmentStore _instance = AppointmentStore._();

  factory AppointmentStore() => _instance;

  static const String storageKey = 'appointments_cache';

  Future<void> _lock = Future<void>.value();

  /// Lee todas las citas guardadas.
  Future<List<Appointment>> readAll() => _synchronized(_readUnlocked);

  /// Reemplaza por completo la lista guardada.
  Future<void> writeAll(List<Appointment> appointments) =>
      _synchronized(() => _writeUnlocked(appointments));

  /// Lectura-modificación-escritura atómica.
  ///
  /// [transform] recibe la lista actual del disco y devuelve la nueva. Debe ser
  /// síncrona y pura: cualquier efecto secundario (notificaciones, red) va
  /// **después** de que este futuro se complete, nunca dentro del lock.
  Future<List<Appointment>> update(
    List<Appointment> Function(List<Appointment> current) transform,
  ) {
    return _synchronized(() async {
      final next = transform(await _readUnlocked());
      await _writeUnlocked(next);
      return next;
    });
  }

  /// Inserta la cita o reemplaza la existente con el mismo `id`.
  Future<void> upsert(Appointment appointment) => update((current) {
        final index = current.indexWhere((a) => a.id == appointment.id);
        if (index == -1) return [...current, appointment];
        return [...current]..[index] = appointment;
      });

  /// Elimina la cita con ese `id` local.
  Future<void> remove(String localId) =>
      update((current) => current.where((a) => a.id != localId).toList());

  /// Guarda el `serverId` que asignó el backend a una cita local.
  Future<void> setServerId(String localId, int serverId) => update((current) {
        final index = current.indexWhere((a) => a.id == localId);
        if (index == -1) return current;
        return [...current]..[index] =
            current[index].copyWith(serverId: serverId);
      });

  /// Busca el `serverId` de una cita local (null si no tiene o no existe).
  Future<int?> findServerId(String localId) async {
    final all = await readAll();
    for (final appointment in all) {
      if (appointment.id == localId) return appointment.serverId;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  Future<List<Appointment>> _readUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];

    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((j) => Appointment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeUnlocked(List<Appointment> appointments) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = appointments.map((a) => a.toJson()).toList();
    await prefs.setString(storageKey, json.encode(jsonList));
  }

  /// Encola [action] detrás de la operación anterior. Un fallo no rompe la
  /// cadena: el siguiente en la cola se ejecuta igual.
  Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }
}
