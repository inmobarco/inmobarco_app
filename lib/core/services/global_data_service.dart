import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../constants/app_constants.dart';

class GlobalDataService {
  static final GlobalDataService _instance = GlobalDataService._internal();
  factory GlobalDataService() => _instance;
  GlobalDataService._internal();

  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _features = [];
  List<Map<String, dynamic>> _residentialComplexes = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getter para acceder a las ciudades desde cualquier parte
  List<Map<String, dynamic>> get cities => _cities;
  List<Map<String, dynamic>> get features => _features;
  List<Map<String, dynamic>> get residentialComplexes => _residentialComplexes;
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
      
      // Cargar ciudades
      debugPrint('🏙️ Cargando ciudades...');
  final fetchedCities = await apiService.getCities();
  _cities = AppConstants.filterAllowedCities(fetchedCities);
      
      debugPrint('✅ Ciudades cargadas: ${_cities.length}');
      if (_cities.isNotEmpty) {
        debugPrint('📍 Primera ciudad: ${_cities.first}');
      }

      // Cargar características
      debugPrint('🧩 Cargando características...');
      _features = await apiService.getFeatures();
      debugPrint('✅ Características cargadas: ${_features.length}');
      if (_features.isNotEmpty) {
        debugPrint('🔖 Primera característica: ${_features.first['name']} (${_features.first['category']})');
      }
      
      // Cargar unidades residenciales desde API propia
      debugPrint('🏢 Cargando unidades residenciales...');
      try {
        _residentialComplexes = await ApiService.getResidentialComplexes();
        debugPrint('✅ Unidades residenciales cargadas: ${_residentialComplexes.length}');
      } catch (e) {
        debugPrint('⚠️ Error cargando unidades residenciales (no bloqueante): $e');
        _residentialComplexes = [];
      }

      _isInitialized = true;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error cargando datos globales: $e');
      debugPrint('Stack trace: $stackTrace');
      // En caso de error, inicializar con lista vacía
      _cities = [];
      _features = [];
      _residentialComplexes = [];
      _isInitialized = false; // Permitir reintento
    } finally {
      _isLoading = false;
    }
  }

  /// Refresca los datos globales
  Future<void> refresh() async {
    _isInitialized = false;
    await initialize();
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
