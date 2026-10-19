import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/user.dart';
import 'token_storage.dart';

/// Servicio de autenticación contra el backend
class AuthService {
  static String get _baseUrl => AppConstants.apiBaseUrl;
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
      final deviceLabel = await _deviceLabel();
      final response = await _dio.post(
        _loginEndpoint,
        data: {
          'username': username,
          'password': password,
          if (deviceLabel != null) 'device_label': deviceLabel,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      // Sin volcar la respuesta: trae los tokens y logcat se lee en release.
      debugPrint('🔐 Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['status'] == 'ok') {
          final accessToken = data['access_token'] as String?;
          if (accessToken == null || accessToken.isEmpty) {
            throw AuthException('El servidor no entregó la sesión');
          }
          await TokenStorage.save(
            accessToken: accessToken,
            refreshToken: data['refresh_token'] as String?,
          );

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

  /// Revoca el refresh token en el servidor.
  ///
  /// No usa el access token: debe poder cerrarse sesión aunque ya haya
  /// vencido. Los errores se ignoran; quien llama ya borró los tokens.
  static Future<void> logout(String refreshToken) async {
    try {
      await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      debugPrint('🔑 Sesión revocada en el servidor');
    } catch (e) {
      debugPrint('⚠️ No se pudo revocar la sesión en el servidor: $e');
    }
  }

  /// Nombre del dispositivo para identificar la sesión (p. ej. "Samsung
  /// SM-A546E"). Opcional: si falla, el login sigue sin él.
  static Future<String?> _deviceLabel() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final brand = info.manufacturer.isEmpty
          ? ''
          : '${info.manufacturer[0].toUpperCase()}${info.manufacturer.substring(1)}';
      final label = '$brand ${info.model}'.trim();
      return label.isEmpty ? null : label;
    } catch (_) {
      return null;
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
