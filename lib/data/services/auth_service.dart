import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user.dart';

/// Servicio de autenticación contra el backend
class AuthService {
  static const String _baseUrl = 'http://194.163.147.243:8080';
  static const String _loginEndpoint = '/login';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Intenta autenticar al usuario con las credenciales proporcionadas
  /// Retorna el User si es exitoso, o lanza una excepción si falla
  static Future<User> login(String username, String password) async {
    try {
      final response = await _dio.post(
        _loginEndpoint,
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      debugPrint('🔐 Login response status: ${response.statusCode}');
      final jsonString = const JsonEncoder.withIndent('  ').convert(response.data);
      debugPrint('🔐 Login response JSON:\n$jsonString');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        
        if (data['status'] == 'ok') {
          // Guardar el token JWT en SharedPreferences
          final accessToken = data['access_token'] as String?;
          if (accessToken != null && accessToken.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('access_token', accessToken);
            debugPrint('🔑 Token JWT guardado en SharedPreferences');
          } else {
            debugPrint('⚠️ No se recibió access_token en la respuesta');
          }

          return User.fromJson(data);
        } else {
          throw AuthException(data['message'] ?? 'Error de autenticación');
        }
      } else {
        throw AuthException('Error del servidor (${response.statusCode})');
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException en login: ${e.type} - ${e.message}');
      
      if (e.response?.statusCode == 401) {
        throw AuthException('Usuario o contraseña incorrectos');
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw AuthException('Tiempo de espera agotado. Intenta de nuevo.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw AuthException('Error de conexión. Verifica tu internet.');
      }
      
      throw AuthException('Error de conexión');
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('❌ Error en login: $e');
      throw AuthException('Error inesperado');
    }
  }
}

/// Excepción personalizada para errores de autenticación
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
