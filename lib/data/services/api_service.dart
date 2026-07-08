import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// Cliente HTTP centralizado que incluye el token JWT en cada solicitud
/// y expone métodos para interactuar con la API de Inmobarco.
///
/// Uso:
/// ```dart
/// final dio = await ApiService.getInstance();
/// final response = await dio.get('/endpoint');
/// ```
class ApiService {
  static String get _baseUrl => AppConstants.apiBaseUrl;

  static Dio? _instance;

  /// Retorna una instancia de Dio configurada con el interceptor de autenticación.
  static Future<Dio> getInstance() async {
    if (_instance != null) return _instance!;

    _instance = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor que agrega el token JWT a cada solicitud
    _instance!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            debugPrint('🔑 Token JWT agregado a la solicitud: ${options.path}');
          }
          handler.next(options);
        },
      ),
    );

    return _instance!;
  }

  /// Resetea la instancia (útil tras logout para forzar re-lectura del token).
  static void reset() {
    _instance = null;
  }

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
  /// Si se proporciona [after], solo devuelve citas cuyo `appointment_date` es
  /// posterior a esa fecha (delta sync).
  /// Retorna la lista de mapas tal como viene del servidor.
  static Future<List<Map<String, dynamic>>> getAppointments({DateTime? after}) async {
    final dio = await getInstance();
    final Map<String, dynamic> queryParams = {};
    if (after != null) {
      queryParams['after'] = after.toUtc().toIso8601String();
    }
    final response = await dio.get(
      '/appointments',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    debugPrint('📅 GET /appointments${after != null ? '?after=${queryParams['after']}' : ''} → ${response.statusCode}');
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
    final response = await dio.get('/crm/clients/latest-notes');
    debugPrint('👥 GET /crm/clients/latest-notes → ${response.statusCode}');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }
}
