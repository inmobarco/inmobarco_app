import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente HTTP centralizado que incluye el token JWT en cada solicitud
/// y expone métodos para interactuar con la API de Inmobarco.
///
/// Uso:
/// ```dart
/// final dio = await ApiService.getInstance();
/// final response = await dio.get('/endpoint');
/// ```
class ApiService {
  static const String _baseUrl = 'http://194.163.147.243:8080';

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
}
