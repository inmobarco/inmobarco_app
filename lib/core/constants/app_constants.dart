import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // URLs - loaded from .env
  static String get baseWebUrl => dotenv.env['INMOBARCO_WEB_BASE_URL'] ?? 'https://ficha.inmobarco.com';
  static String get arrendasoftApiBaseUrl => dotenv.env['ARRENDASOFT_API_BASE_URL'] ?? 'https://api.arrendasoft.co/v2';
  
  // API Configuration - loaded from .env
  static String get defaultApiKey => dotenv.env['ARRENDASOFT_API_KEY'] ?? '';
  
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
}
