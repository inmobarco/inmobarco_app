import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../core/services/global_data_service.dart';
import '../data/services/sync_service.dart';
import 'providers/appointment_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/client_provider.dart';

/// Cierra la sesión del asesor y borra todo lo suyo del dispositivo.
///
/// Con [expired] es el cierre forzado: la API ya rechazó la sesión, así que la
/// cola de citas no se puede enviar y se descarta.
Future<void> endSession(BuildContext context, {bool expired = false}) async {
  final auth = context.read<AuthProvider>();
  final clients = context.read<ClientProvider>();
  final sync = context.read<SyncService>();
  final appointments = context.read<AppointmentProvider>();
  final globalData = context.read<GlobalDataService>();

  clients.clear();
  globalData.clearEmployeeData();
  // El orden importa: en el cierre voluntario la cola se vacía con el token
  // del asesor que se va, así que va antes del logout.
  await sync.resetForLogout(flush: !expired);
  await appointments.loadAppointments();
  await auth.logout();
}
