import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/user.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/token_storage.dart';

/// Provider de autenticación para gestionar el estado de sesión en toda la app
class AuthProvider extends ChangeNotifier {
  final CacheService _cacheService;
  final Future<void> Function(String refreshToken) _revokeSession;

  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider({
    required CacheService cacheService,
    Future<void> Function(String refreshToken)? revokeSession,
  })  : _cacheService = cacheService,
        _revokeSession = revokeSession ?? AuthService.logout;

  /// Usuario autenticado actual (null si no hay sesión)
  User? get user => _user;

  /// Indica si el usuario está logueado
  bool get isLoggedIn => _user != null;

  /// Indica si hay una operación de autenticación en progreso
  bool get isLoading => _isLoading;

  /// Mensaje de error de la última operación (null si no hay error)
  String? get error => _error;

  /// Nombre para mostrar en la UI (vacío si no hay sesión)
  String get displayName => _user?.firstName ?? '';

  /// Nombre completo del usuario
  String get fullName => _user?.fullName ?? '';

  /// Carga la sesión guardada en caché al iniciar la app.
  ///
  /// No sale a la red: si el access token venció, el primer request lo
  /// renueva solo. Basta con que haya tokens guardados.
  Future<void> loadSession() async {
    try {
      final userData = await _cacheService.loadAuthSession();
      if (userData == null) return;
      if (!await TokenStorage.hasSession()) {
        // Perfil sin tokens: no hay sesión que retomar.
        debugPrint('🔒 Perfil guardado sin tokens → se descarta');
        await _cacheService.clearOnLogout();
        return;
      }
      _user = User.fromJson(userData);
      debugPrint('✅ Sesión cargada desde caché: ${_user?.username}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error cargando sesión: $e');
    }
  }

  /// Intenta iniciar sesión con las credenciales proporcionadas
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await AuthService.login(username, password);
      _user = user;

      // Guardar sesión en caché
      await _cacheService.saveAuthSession(user.toJson());

      debugPrint('✅ Login exitoso: ${user.username}');
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error inesperado';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cierra la sesión actual.
  ///
  /// Los tokens se borran primero y siempre; la revocación en el servidor va
  /// aparte y sin esperar, para que cerrar sesión sin red no se quede colgado.
  /// Si la sesión la terminó la API, los tokens ya no están y no hay nada que
  /// revocar.
  Future<void> logout() async {
    final refreshToken = await TokenStorage.refreshToken;
    await TokenStorage.clear();
    if (refreshToken != null) unawaited(_revokeSession(refreshToken));

    // Todo lo del asesor se va (clientes, bitácoras, residenciales,
    // características, borrador, perfil, rutero). Se conservan propiedades,
    // ciudades y filtros, que es lo que la app sigue mostrando sin sesión.
    await _cacheService.clearOnLogout();
    _user = null;
    notifyListeners();
  }

  /// Limpia el error actual
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
