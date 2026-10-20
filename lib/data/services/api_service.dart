import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';

/// Cliente HTTP centralizado que incluye el token JWT en cada solicitud
/// y expone métodos para interactuar con la API de Inmobarco.
///
/// La renovación del token vencido la hace [AuthInterceptor]: las pantallas
/// no ven un 401 salvo que la sesión haya terminado de verdad.
///
/// Uso:
/// ```dart
/// final dio = await ApiService.getInstance();
/// final response = await dio.get('/endpoint');
/// ```
class ApiService {
  static String get _baseUrl => AppConstants.apiBaseUrl;

  static Dio? _instance;

  /// Se llama cuando la API da la sesión por terminada (refresh vencido o
  /// revocado, usuario inactivo), con los tokens ya borrados. Lo conecta
  /// `main.dart` para limpiar los datos del asesor y mandar al login.
  static VoidCallback? onSessionEnded;

  /// Retorna una instancia de Dio configurada con el interceptor de autenticación.
  static Future<Dio> getInstance() async {
    if (_instance != null) return _instance!;

    final options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    );
    _instance = Dio(options)
      ..interceptors.add(AuthInterceptor(
        plainDio: Dio(options),
        onSessionEnded: () => onSessionEnded?.call(),
      ));

    return _instance!;
  }

  /// Indica si hay una sesión guardada.
  ///
  /// Los endpoints de este backend requieren sesión: llamarlos sin token solo
  /// produce 401 (o un timeout de 10 s si el servidor no responde), así que
  /// quien sincroniza debe consultar esto antes de salir a la red.
  static Future<bool> hasSession() => TokenStorage.hasSession();

  // ---------------------------------------------------------------------------
  // Appointments API
  // ---------------------------------------------------------------------------

  /// Crea una cita en el servidor.
  ///
  /// Retorna el mapa completo de la respuesta (incluye el `id` generado por el backend).
  static Future<Map<String, dynamic>> createAppointment(Map<String, dynamic> body) async {
    final dio = await getInstance();
    final response = await dio.post('/appointments', data: body);
    debugPrint('📅 POST /appointments → ${response.statusCode}');
    return response.data as Map<String, dynamic>;
  }

  /// Actualiza una cita existente en el servidor.
  ///
  /// [id] es el ID del servidor (no el local).
  /// [body] contiene solo los campos que cambiaron.
  static Future<Map<String, dynamic>> updateAppointment(int id, Map<String, dynamic> body) async {
    final dio = await getInstance();
    final response = await dio.put('/appointments/$id', data: body);
    debugPrint('📅 PUT /appointments/$id → ${response.statusCode}');
    return response.data as Map<String, dynamic>;
  }

  /// Elimina una cita del servidor.
  static Future<void> deleteAppointment(int id) async {
    final dio = await getInstance();
    final response = await dio.delete('/appointments/$id');
    debugPrint('📅 DELETE /appointments/$id → ${response.statusCode}');
  }

  /// Obtiene las citas del usuario autenticado.
  ///
  /// - [after] filtra por `appointment_date` posterior a esa fecha. Se usa
  ///   para el arranque en frío: trae la agenda vigente sin arrastrar años de
  ///   historia.
  /// - [updatedAfter] filtra por `updated_at` posterior a esa fecha. Es el
  ///   delta sync: trae solo lo que cambió desde el último sync, incluidas
  ///   citas pasadas que un admin haya modificado.
  ///
  /// Retorna la lista de mapas tal como viene del servidor.
  static Future<List<Map<String, dynamic>>> getAppointments({
    DateTime? after,
    DateTime? updatedAfter,
  }) async {
    final dio = await getInstance();
    final Map<String, dynamic> queryParams = {};
    if (after != null) {
      queryParams['after'] = after.toUtc().toIso8601String();
    }
    if (updatedAfter != null) {
      queryParams['updated_after'] = updatedAfter.toUtc().toIso8601String();
    }
    final response = await dio.get(
      '/appointments',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    debugPrint('📅 GET /appointments'
        '${queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}'}'
        ' → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Residential Complexes API
  // ---------------------------------------------------------------------------

  /// Obtiene las ciudades habilitadas (allowlist) desde el backend.
  ///
  /// Mapea cada elemento a `{id, name}` usando `city_id_wasi` / `city_name`,
  /// que es lo que consume el resto de la app (el `id` es el id de ciudad WASI).
  static Future<List<Map<String, dynamic>>> getAllowedCities() async {
    final dio = await getInstance();
    final response = await dio.get('/inventory/allowed-cities');
    debugPrint('🏙️ GET /inventory/allowed-cities → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map((c) => {
              'id': c['city_id_wasi']?.toString() ?? '',
              'name': c['city_name']?.toString() ?? '',
            })
        .where((c) => (c['id'] as String).isNotEmpty)
        .toList();
  }

  /// Obtiene las unidades residenciales disponibles.
  ///
  /// Retorna la lista de mapas tal como viene del servidor.
  static Future<List<Map<String, dynamic>>> getResidentialComplexes() async {
    final dio = await getInstance();
    final response = await dio.get('/inventory/residential-complexes');
    debugPrint('🏢 GET /inventory/residential-complexes → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Crea un residencial. Obligatorios: name, address, id_city, id_zone, stratum.
  static Future<Map<String, dynamic>> createResidentialComplex(
      Map<String, dynamic> body) async {
    final dio = await getInstance();
    final response = await dio.post('/inventory/residential-complexes', data: body);
    debugPrint('🏢 POST /inventory/residential-complexes → ${response.statusCode}');
    return response.data as Map<String, dynamic>;
  }

  /// Actualiza un residencial. Campos enviables: admin_phone, admin_email,
  /// front_desk_phone, stratum, latitude, longitude.
  static Future<Map<String, dynamic>> updateResidentialComplex(
      int id, Map<String, dynamic> body) async {
    final dio = await getInstance();
    final response = await dio.put('/inventory/residential-complexes/$id', data: body);
    debugPrint('🏢 PUT /inventory/residential-complexes/$id → ${response.statusCode}');
    return response.data as Map<String, dynamic>;
  }

  /// Elimina un residencial del servidor.
  static Future<void> deleteResidentialComplex(int id) async {
    final dio = await getInstance();
    final response = await dio.delete('/inventory/residential-complexes/$id');
    debugPrint('🏢 DELETE /inventory/residential-complexes/$id → ${response.statusCode}');
  }

  // ---------------------------------------------------------------------------
  // Scheduling API (solo lectura)
  // ---------------------------------------------------------------------------

  /// Obtiene las rutas de prospección del asesor autenticado.
  ///
  /// El `advisor_id` sale del JWT: no se puede pedir la agenda de otro asesor
  /// por esta vía. La app solo visualiza rutas, nunca las modifica.
  ///
  /// Sin [dayOfWeek] trae la semana completa (lunes a sábado) agrupada por
  /// día, que es lo que permite cachearla y cambiar de día sin volver a la red.
  static Future<List<Map<String, dynamic>>> getAdvisorRoutes({
    int? dayOfWeek,
  }) async {
    final dio = await getInstance();
    final response = await dio.get(
      '/scheduling/routes',
      queryParameters: dayOfWeek != null ? {'day_of_week': dayOfWeek} : null,
    );
    debugPrint('🗺️ GET /scheduling/routes'
        '${dayOfWeek == null ? '' : '?day_of_week=$dayOfWeek'}'
        ' → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Maintenance API (solo lectura, roles admin y manager)
  // ---------------------------------------------------------------------------

  /// Lista solicitudes de mantenimiento, ordenadas por `created_at` DESC.
  ///
  /// [assignedUserId] y [unassigned] no se pueden combinar (la API da 422):
  /// para ver "mías o sin responsable" se hacen dos llamadas.
  static Future<List<Map<String, dynamic>>> getMaintenanceRequests({
    List<String>? statuses,
    int? assignedUserId,
    bool unassigned = false,
    int limit = 500,
  }) async {
    assert(assignedUserId == null || !unassigned);
    final dio = await getInstance();
    final queryParams = <String, dynamic>{
      if (statuses != null && statuses.isNotEmpty) 'status': statuses.join(','),
      'assigned_user_id': ?assignedUserId,
      if (unassigned) 'unassigned': true,
      'limit': limit,
    };
    final response = await dio.get(
      '/staff/maintenance/requests',
      queryParameters: queryParams,
    );
    debugPrint('🔧 GET /staff/maintenance/requests'
        '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        ' → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Detalle completo de una solicitud (incluye datos personales del
  /// reportante que el listado omite).
  static Future<Map<String, dynamic>> getMaintenanceRequest(int id) async {
    final dio = await getInstance();
    final response = await dio.get('/staff/maintenance/requests/$id');
    debugPrint('🔧 GET /staff/maintenance/requests/$id → ${response.statusCode}');
    return response.data as Map<String, dynamic>;
  }

  /// Adjuntos de una solicitud con URLs firmadas que caducan a los 15 min:
  /// no se cachean, se vuelven a pedir cuando vencen.
  static Future<List<Map<String, dynamic>>> getMaintenanceAttachments(
      int id) async {
    final dio = await getInstance();
    final response =
        await dio.get('/staff/maintenance/requests/$id/attachments');
    debugPrint('🔧 GET /staff/maintenance/requests/$id/attachments'
        ' → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Bitácora de una solicitud, de la más antigua a la más reciente.
  static Future<List<Map<String, dynamic>>> getMaintenanceEvents(int id) async {
    final dio = await getInstance();
    final response = await dio.get('/staff/maintenance/requests/$id/events');
    debugPrint('🔧 GET /staff/maintenance/requests/$id/events'
        ' → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // CRM API
  // ---------------------------------------------------------------------------

  /// Obtiene la propiedad dummy del asesor autenticado (scoping por JWT).
  ///
  /// Retorna `{id_property_wasi, property_label}`; ese id se usa como filtro
  /// en WASI para traer los clientes del asesor.
  static Future<Map<String, dynamic>> getAdvisorMap() async {
    final dio = await getInstance();
    final response = await dio.get('/crm/advisor-map');
    debugPrint('👥 GET /crm/advisor-map → ${response.statusCode}: ${response.data}');
    return response.data as Map<String, dynamic>;
  }

  /// Obtiene las notas de un cliente (por su id de WASI).
  static Future<List<Map<String, dynamic>>> getClientNotes(int idClientWasi) async {
    final dio = await getInstance();
    final response = await dio.get('/crm/clients/$idClientWasi/notes');
    debugPrint('👥 GET /crm/clients/$idClientWasi/notes → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Obtiene la última nota de cada cliente del asesor.
  static Future<List<Map<String, dynamic>>> getLatestClientNotes() async {
    final dio = await getInstance();
    final response = await dio.get('/crm/latest-notes');
    debugPrint('👥 GET /crm/latest-notes → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Crea una nota en la bitácora de un cliente.
  ///
  /// El advisor_id lo deriva el backend del JWT.
  static Future<Map<String, dynamic>> createClientNote(
      int idClientWasi, String note, String noteType) async {
    final dio = await getInstance();
    final response = await dio.post('/crm/clients/$idClientWasi/notes', data: {
      'note': note,
      'note_type': noteType,
    });
    debugPrint('👥 POST /crm/clients/$idClientWasi/notes → ${response.statusCode}');
    // El backend retorna la nota creada envuelta en una lista
    final data = response.data;
    if (data is List && data.isNotEmpty) {
      return data.first as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}
