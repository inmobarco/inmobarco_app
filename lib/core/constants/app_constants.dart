import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/global_data_service.dart';

class AppConstants {
  static const String appVersion = '1.7.0';
  
  // URLs - loaded from .env
  static String get baseWebUrl => dotenv.env['INMOBARCO_WEB_BASE_URL'] ?? 'https://ficha.inmobarco.com';
  static String get wasiApiBaseUrl => dotenv.env['WASI_API_URL'] ?? 'https://api.wasi.co/v1';
  
  // API Configuration - loaded from .env
  static String get wasiApiToken => dotenv.env['WASI_API_TOKEN'] ?? '';
  static String get wasiApiId => dotenv.env['WASI_API_ID'] ?? '';

  // Paginación
  static const int pageSize = 100;
  static const int loadMoreThreshold = 200; // pixels from bottom to trigger load more
  
  // Timeouts
  static const Duration apiConnectTimeout = Duration(seconds: 10);
  static const Duration apiSendTimeout = Duration(seconds: 10);
  static const Duration apiReceiveTimeout = Duration(seconds: 15);
  
  // UI - Border Radius
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 8.0;
  static const double inputBorderRadius = 8.0;

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
  
  // Share
  static String getPropertyShareUrl(String codigo) {
    return '$baseWebUrl/?id=$codigo';
  }

  // Features
  static List<Map<String, dynamic>> get features {
    try {
      return List<Map<String, dynamic>>.from(GlobalDataService().features);
    } catch (e) {
      debugPrint('Error accediendo a características: $e');
      return <Map<String, dynamic>>[];
    }
  }
}
