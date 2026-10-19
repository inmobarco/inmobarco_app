import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tokens de sesión del backend propio, en almacenamiento cifrado (Keystore).
///
/// El refresh token dura 90 días y equivale a tener la sesión abierta, por eso
/// no va en SharedPreferences. Se guarda además una copia en memoria: el
/// interceptor lee el access token en cada request y el Keystore es lento.
class TokenStorage {
  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  /// Clave de SharedPreferences donde las versiones anteriores guardaban el
  /// access token (sin refresh token).
  static const String _legacyAccessKey = 'access_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String? _access;
  static String? _refresh;
  static Future<void>? _loading;

  static Future<void> _ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
    } catch (e) {
      // Keystore inutilizable (p. ej. datos restaurados en otro equipo): no
      // hay sesión que se pueda retomar.
      debugPrint('⚠️ No se pudieron leer los tokens: $e');
      _access = null;
      _refresh = null;
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }

    // Migración: el access token de la versión anterior sigue sirviendo hasta
    // que venza; como no trae refresh token, ahí la app pedirá login.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyAccessKey);
    if (legacy != null) {
      if (_access == null && legacy.isNotEmpty) {
        _access = legacy;
        await _write(_accessKey, legacy);
      }
      await prefs.remove(_legacyAccessKey);
    }
  }

  static Future<String?> get accessToken async {
    await _ensureLoaded();
    return _access;
  }

  static Future<String?> get refreshToken async {
    await _ensureLoaded();
    return _refresh;
  }

  /// Indica si hay una sesión que el backend todavía podría aceptar.
  static Future<bool> hasSession() async {
    await _ensureLoaded();
    return _refresh != null || _access != null;
  }

  /// Reemplaza los dos tokens. La API entrega siempre el par completo.
  static Future<void> save({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _ensureLoaded();
    _access = accessToken;
    _refresh = refreshToken;
    await _write(_accessKey, accessToken);
    await _write(_refreshKey, refreshToken);
  }

  /// Borra los dos tokens.
  static Future<void> clear() async {
    await _ensureLoaded();
    _access = null;
    _refresh = null;
    await _write(_accessKey, null);
    await _write(_refreshKey, null);
  }

  /// Si el disco falla, la copia en memoria mantiene la sesión hasta que se
  /// cierre la app.
  static Future<void> _write(String key, String? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar $key: $e');
    }
  }

  /// Olvida la copia en memoria para que el próximo acceso relea el disco.
  @visibleForTesting
  static void resetForTest() {
    _access = null;
    _refresh = null;
    _loading = null;
  }
}
