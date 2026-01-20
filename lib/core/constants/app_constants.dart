import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/global_data_service.dart';

class AppConstants {
  static const String appVersion = '1.7.0';
  // URLs - loaded from .env
  static String get baseWebUrl => dotenv.env['INMOBARCO_WEB_BASE_URL'] ?? 'https://ficha.inmobarco.com';
  static String get arrendasoftApiBaseUrl => dotenv.env['ARRENDASOFT_API_BASE_URL'] ?? 'https://api.arrendasoft.co/v2';
  static String get wasiApiBaseUrl => dotenv.env['WASI_API_URL'] ?? 'https://api.wasi.co/v1';
  
  // API Configuration - loaded from .env
  static String get defaultApiKey => dotenv.env['ARRENDASOFT_API_KEY'] ?? '';
  static String get wasiApiToken => dotenv.env['WASI_API_TOKEN'] ?? '';
  static String get wasiApiId => dotenv.env['WASI_API_ID'] ?? '';

  // City allowlist
  static const Set<String> allowedCityIds = {
    '291', // Envigado
    '496', // Medellín
    '698', // Sabaneta
    '416', // La Estrella
    '389', // Itagüí
    '89', // Bello
  };

  static bool isCityAllowed(String? cityId) {
    if (allowedCityIds.isEmpty) return true;
    if (cityId == null || cityId.isEmpty) return false;
    return allowedCityIds.contains(cityId);
  }

  static List<Map<String, dynamic>> filterAllowedCities(List<Map<String, dynamic>> cities) {
    if (cities.isEmpty) return const <Map<String, dynamic>>[];
    if (allowedCityIds.isEmpty) {
      return List<Map<String, dynamic>>.from(cities);
    }
    return cities
        .where((city) => isCityAllowed(city['id']?.toString()))
        .map((city) => Map<String, dynamic>.from(city))
        .toList();
  }
  
  // Global Data Access - Ciudades disponibles globalmente
  static GlobalDataService get globalData => GlobalDataService();
  static List<Map<String, dynamic>> get cities {
    try {
      return filterAllowedCities(GlobalDataService().cities);
    } catch (e) {
      debugPrint('Error accediendo a ciudades: $e');
      return <Map<String, dynamic>>[];
    }
  }
  static List<String> get cityNames {
    try {
      return cities
          .map((city) => city['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error accediendo a nombres de ciudades: $e');
      return <String>[];
    }
  }
  
  // Paginación
  static const int defaultPageSize = 20;
  static const int loadMoreThreshold = 200; // pixels from bottom to trigger load more
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 15);
  
  // Cache
  static const Duration imageCacheDuration = Duration(days: 7);
  
  // Share
  static String getPropertyShareUrl(String codigo) {
    return '$baseWebUrl/?id=$codigo';
  }
  
  // Validation
  static const double minPrice = 0;
  static const double maxPrice = 10000000000; // 10 mil millones
  static const double minArea = 0;
  static const double maxArea = 10000; // 10,000 m²
  
  // UI
  static const double cardBorderRadius = 12;
  static const double buttonBorderRadius = 8;
  static const double inputBorderRadius = 8;
  
  // Error Messages
  static const String genericErrorMessage = 'Ha ocurrido un error inesperado';
  static const String networkErrorMessage = 'Error de conexión. Verifica tu conexión a internet';
  static const String noDataMessage = 'No hay datos disponibles';
  static const String noPropertiesMessage = 'No se encontraron propiedades';

  // Features
  static List<Map<String, dynamic>> get features {
    try {
      return List<Map<String, dynamic>>.from(GlobalDataService().features);
    } catch (e) {
      debugPrint('Error accediendo a características: $e');
      return <Map<String, dynamic>>[];
    }
  }
  static List<String> get featureNames {
    try {
      return GlobalDataService().featureNames;
    } catch (e) {
      debugPrint('Error accediendo a nombres de características: $e');
      return <String>[];
    }
  }
}
