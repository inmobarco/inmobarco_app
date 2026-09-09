import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../constants/app_constants.dart';

class GlobalDataService {
  GlobalDataService({required CacheService cacheService})
      : _cacheService = cacheService;

  final CacheService _cacheService;

  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _features = [];
  List<Map<String, dynamic>> _residentialComplexes = [];
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getter para acceder a las ciudades desde cualquier parte
  List<Map<String, dynamic>> get cities => _cities;
  List<Map<String, dynamic>> get features => _features;
  List<Map<String, dynamic>> get residentialComplexes => _residentialComplexes;
  List<Map<String, dynamic>> get zones => _zones;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// Inicializa los datos globales al arrancar la aplicación
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🌍 GlobalDataService ya inicializado');
      return; // Ya inicializado
    }
    
    _isLoading = true;
    
    try {
      debugPrint('🌍 Iniciando carga de datos globales...');
      
      // Verificar que las variables de entorno estén cargadas
      if (AppConstants.wasiApiToken.isEmpty) {
        debugPrint('❌ WASI API Token no está disponible');
        throw Exception('WASI API Token no configurado');
      }
      
      // Crear instancia del servicio API
      final apiService = WasiApiService(
        apiToken: AppConstants.wasiApiToken,
        companyId: AppConstants.wasiApiId,
      );
      
      // Cargar ciudades: primero desde caché (arranque instantáneo), luego
      // refrescar en background si está vencido o no hay caché.
      debugPrint('🏙️ Cargando ciudades...');
      final cached = await _cacheService.loadAllowedCities();
      if (cached != null) {
        _cities = cached.data;
        debugPrint('📦 Ciudades desde caché: ${_cities.length} (stale: ${cached.isStale})');
      }
      if (cached == null) {
        // Arranque en frío sin caché: esperar para tener ciudades listas.
        await _refreshAllowedCities();
      } else if (cached.isStale) {
        // Hay caché servible: refrescar en background sin bloquear el arranque.
        _refreshAllowedCities();
      }

      // Cargar características
      debugPrint('🧩 Cargando características...');
      _features = await apiService.getFeatures();
      debugPrint('✅ Características cargadas: ${_features.length}');
      if (_features.isNotEmpty) {
        debugPrint('🔖 Primera característica: ${_features.first['name']} (${_features.first['category']})');
      }
      
      // Cargar unidades residenciales + zonas
      await _loadResidentialsAndZones(apiService);

      _isInitialized = true;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error cargando datos globales: $e');
      debugPrint('Stack trace: $stackTrace');
      // En caso de error, inicializar con lista vacía
      _cities = [];
      _features = [];
      _residentialComplexes = [];
      _zones = [];
      _isInitialized = false; // Permitir reintento
    } finally {
      _isLoading = false;
    }
  }

  /// Refresca los datos globales
  Future<void> refresh() async {
    _isInitialized = false;
    await initialize();
    await _refreshAllowedCities();
  }

  /// Refresca las ciudades habilitadas desde el backend y actualiza el caché.
  /// Si el backend falla, conserva las ciudades ya cargadas (last-known-good).
  Future<void> _refreshAllowedCities() async {
    if (!await ApiService.hasSession()) {
      debugPrint('🔒 Sin sesión → se conservan las ciudades en caché');
      return;
    }
    try {
      final fresh = await ApiService.getAllowedCities();
      if (fresh.isNotEmpty) {
        _cities = fresh;
        await _cacheService.saveAllowedCities(fresh);
        debugPrint('✅ Ciudades refrescadas desde backend: ${fresh.length}');
      }
    } catch (e) {
      debugPrint('⚠️ Error refrescando ciudades (se conserva caché): $e');
    }
  }

  /// Carga unidades residenciales y las zonas (barrios) de sus ciudades.
  Future<void> _loadResidentialsAndZones(WasiApiService api) async {
    if (!await ApiService.hasSession()) {
      debugPrint('🔒 Sin sesión → se omiten residenciales y zonas');
      return;
    }
    debugPrint('🏢 Cargando unidades residenciales...');
    try {
      _residentialComplexes = await ApiService.getResidentialComplexes();
      debugPrint('✅ Unidades residenciales cargadas: ${_residentialComplexes.length}');
    } catch (e) {
      debugPrint('⚠️ Error cargando unidades residenciales (no bloqueante): $e');
      _residentialComplexes = [];
    }

    try {
      final cityIds = _residentialComplexes
          .map((c) => c['id_city']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final results = await Future.wait(cityIds.map(api.getZonesByCity));
      _zones = results.expand((z) => z).toList();
      debugPrint('✅ Zonas cargadas: ${_zones.length}');
    } catch (e) {
      debugPrint('⚠️ Error cargando zonas (no bloqueante): $e');
      _zones = [];
    }
  }

  /// Recarga solo los residenciales y sus zonas (tras crear/editar/eliminar).
  Future<void> reloadResidentials() async {
    final api = WasiApiService(
      apiToken: AppConstants.wasiApiToken,
      companyId: AppConstants.wasiApiId,
    );
    await _loadResidentialsAndZones(api);
  }

  /// Busca una ciudad por nombre
  Map<String, dynamic>? findCityByName(String name) {
    try {
      return _cities.firstWhere(
        (city) => city['name']?.toString().toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Obtiene nombres de ciudades como lista de strings
  List<String> get cityNames {
    return _cities.map((city) => city['name'] as String).toList();
  }

  /// Filtra ciudades por texto
  List<String> filterCities(String query) {
    if (query.isEmpty) return cityNames;
    
    return cityNames.where((cityName) {
      return cityName.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  /// Obtiene los nombres de características disponibles
  List<String> get featureNames {
    return _features
        .map((feature) => feature['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Filtra características por texto
  List<Map<String, dynamic>> filterFeatures(String query) {
    if (query.isEmpty) {
      return List<Map<String, dynamic>>.from(_features);
    }

    final lowerQuery = query.toLowerCase();
    return _features
        .where((feature) => feature['name']?.toString().toLowerCase().contains(lowerQuery) ?? false)
        .map((feature) => Map<String, dynamic>.from(feature))
        .toList();
  }
}
