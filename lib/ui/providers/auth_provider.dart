import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/api_service.dart';

/// Provider de autenticación para gestionar el estado de sesión en toda la app
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

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

  /// Carga la sesión guardada en caché al iniciar la app
  Future<void> loadSession() async {
    try {
      final userData = await CacheService.loadAuthSession();
      if (userData != null) {
        _user = User.fromJson(userData);
        debugPrint('✅ Sesión cargada desde caché: ${_user?.username}');
        notifyListeners();
      }
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
      await CacheService.saveAuthSession(user.toJson());
      
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

  /// Cierra la sesión actual
  Future<void> logout() async {
    await CacheService.clearAuthSession();
    // Limpiar el token JWT
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    debugPrint('🔑 Token JWT eliminado');
    ApiService.reset();
    _user = null;
    notifyListeners();
  }

  /// Limpia el error actual
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
