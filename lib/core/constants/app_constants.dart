import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  /// Versión de la app, inicializada desde pubspec.yaml vía package_info_plus.
  /// Se carga en main() antes de runApp.
  static String appVersion = '0.0.0';
  
  // URLs - loaded from .env
  static String get baseWebUrl => dotenv.env['INMOBARCO_WEB_BASE_URL'] ?? 'https://ficha.inmobarco.com';
  static String get wasiApiBaseUrl => dotenv.env['WASI_API_URL'] ?? 'https://api.wasi.co/v1';
  static String get apiBaseUrl => dotenv.env['INMOBARCO_API_URL'] ?? 'http://194.163.147.243:8080';
  static String get webhookBaseUrl => dotenv.env['INMOBARCO_WEBHOOK_URL'] ?? 'https://automa-inmobarco-n8n.druysh.easypanel.host';
  
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

  // Timeouts para webhook (payloads grandes con fotos)
  static const Duration webhookConnectTimeout = Duration(seconds: 15);
  static const Duration webhookSendTimeout = Duration(seconds: 120);
  static const Duration webhookReceiveTimeout = Duration(seconds: 60);

  // Límite de advertencia de tamaño de payload (en bytes)
  static const int webhookPayloadWarningSizeBytes = 50 * 1024 * 1024; // 50 MB
  
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
  
  // Property types
  static const List<Map<String, String>> allPropertyTypes = [
    {'id': '1', 'label': 'Casa', 'acronym': 'CS'},
    {'id': '2', 'label': 'Apartamento', 'acronym': 'AP'},
    {'id': '3', 'label': 'Local comercial', 'acronym': 'LC'},
    {'id': '4', 'label': 'Oficina', 'acronym': 'OF'},
    {'id': '5', 'label': 'Lote / Terreno', 'acronym': 'LT'},
    {'id': '6', 'label': 'Lote Comercial', 'acronym': 'LCO'},
    {'id': '7', 'label': 'Finca', 'acronym': 'FI'},
    {'id': '8', 'label': 'Bodega', 'acronym': 'BG'},
    {'id': '10', 'label': 'Chalet', 'acronym': 'CH'},
    {'id': '11', 'label': 'Casa de Campo', 'acronym': 'CC'},
    {'id': '12', 'label': 'Hoteles', 'acronym': 'HT'},
    {'id': '13', 'label': 'Finca - Hoteles', 'acronym': 'FH'},
    {'id': '14', 'label': 'Aparta-Estudio', 'acronym': 'AE'},
    {'id': '15', 'label': 'Consultorio', 'acronym': 'CN'},
    {'id': '16', 'label': 'Edificio', 'acronym': 'ED'},
    {'id': '17', 'label': 'Lote de Playa', 'acronym': 'LP'},
    {'id': '18', 'label': 'Hostal', 'acronym': 'HS'},
    {'id': '19', 'label': 'Condominio', 'acronym': 'CM'},
    {'id': '20', 'label': 'Duplex', 'acronym': 'DX'},
    {'id': '21', 'label': 'Atico', 'acronym': 'AT'},
    {'id': '22', 'label': 'Bungalow', 'acronym': 'BN'},
    {'id': '23', 'label': 'Galpón Industrial', 'acronym': 'GI'},
    {'id': '24', 'label': 'Casa de Playa', 'acronym': 'CP'},
    {'id': '25', 'label': 'Piso', 'acronym': 'PS'},
    {'id': '26', 'label': 'Garaje', 'acronym': 'GJ'},
    {'id': '27', 'label': 'Cortijo', 'acronym': 'CJ'},
    {'id': '28', 'label': 'Cabañas', 'acronym': 'CB'},
    {'id': '29', 'label': 'Isla', 'acronym': 'IS'},
    {'id': '30', 'label': 'Nave Industrial', 'acronym': 'NI'},
    {'id': '31', 'label': 'Campos, Chacras y Quintas', 'acronym': 'CQ'},
    {'id': '32', 'label': 'Terreno', 'acronym': 'TR'},
  ];

  static const Set<String> enabledPropertyTypeIds = {'1', '2', '3', '4', '14'};

  // City center coordinates (lat, lng) for map picker default position
  static const Map<String, List<double>> cityCenterCoordinates = {
    '496': [6.2442, -75.5812],  // Medellín
    '291': [6.1714, -75.5867],  // Envigado
    '698': [6.1517, -75.6167],  // Sabaneta
    '416': [6.1589, -75.6303],  // La Estrella
    '389': [6.1681, -75.5983],  // Itagüí
    '89':  [6.3383, -75.5511],  // Bello
  };

  // Default coordinates (Medellín center)
  static const double defaultLatitude = 6.2442;
  static const double defaultLongitude = -75.5812;

  // Share
  static String getPropertyShareUrl(String codigo) {
    return '$baseWebUrl/?id=$codigo';
  }
}
