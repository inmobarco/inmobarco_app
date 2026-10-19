import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_storage.dart';

/// Pone el access token en cada request y lo renueva cuando vence.
///
/// Es un [QueuedInterceptor]: los errores se atienden de a uno. Si varios
/// requests vencen a la vez, solo el primero llama a `/auth/refresh`; los
/// demás encuentran guardado un token distinto al que enviaron y solo
/// reintentan. Si cada uno renovara por su cuenta, el segundo presentaría un
/// refresh token ya rotado y la API cerraría la sesión.
///
/// El refresh y los reintentos salen por [_plainDio], que no tiene este
/// interceptor: si pasaran por aquí, la cola se esperaría a sí misma.
class AuthInterceptor extends QueuedInterceptor {
  final Dio _plainDio;
  final VoidCallback _onSessionEnded;

  AuthInterceptor({
    required Dio plainDio,
    required VoidCallback onSessionEnded,
  })  : _plainDio = plainDio,
        _onSessionEnded = onSessionEnded;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStorage.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response?.statusCode != 401) return handler.next(err);

    // Mientras este request esperaba en la cola, otro ya renovó el token (o
    // se inició sesión de nuevo): basta con reintentar.
    final current = await TokenStorage.accessToken;
    if (current != null && current != _bearerOf(err.requestOptions)) {
      return _retry(err, current, handler);
    }

    switch (_detailOf(response!.data)) {
      case 'token_expired':
        final renewed = await _refresh();
        if (renewed == null) return handler.next(err);
        return _retry(err, renewed, handler);
      case 'token_invalid':
      case 'user_inactive':
        await _endSession();
        return handler.next(err);
      default:
        return handler.next(err);
    }
  }

  /// Canjea el refresh token por un par nuevo y retorna el access token.
  ///
  /// Retorna null si no se pudo. Sin red la sesión sigue intacta y el request
  /// falla como cualquier otro (la cola lo reintentará); solo un 401 de la API
  /// (`refresh_invalid`) da la sesión por terminada.
  Future<String?> _refresh() async {
    final refreshToken = await TokenStorage.refreshToken;
    if (refreshToken == null) {
      // Sesión migrada de la versión anterior: no hay con qué renovar.
      await _endSession();
      return null;
    }
    try {
      final response = await _plainDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access == null || refresh == null) return null;

      // Si se cerró sesión mientras tanto, no se resucita.
      if (await TokenStorage.refreshToken != refreshToken) return null;
      await TokenStorage.save(accessToken: access, refreshToken: refresh);
      debugPrint('🔑 Sesión renovada');
      return access;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _endSession();
      } else {
        debugPrint('⚠️ No se pudo renovar la sesión: ${e.type}');
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Respuesta inesperada de /auth/refresh: $e');
      return null;
    }
  }

  Future<void> _retry(
    DioException err,
    String token,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    options.headers['Authorization'] = 'Bearer $token';
    try {
      handler.resolve(await _plainDio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<void> _endSession() async {
    if (!await TokenStorage.hasSession()) return;
    debugPrint('🔒 La API rechazó la sesión → se cierra');
    await TokenStorage.clear();
    _onSessionEnded();
  }

  static String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  static String? _detailOf(Object? data) {
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    return null;
  }
}
