import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/apartment.dart';

class CacheService {
  static const String _propertiesKey = 'cached_properties';
  static const String _lastUpdateKey = 'last_update_timestamp';
  static const String _filterKey = 'cached_filter';
  
  // Tiempo de expiración del caché en horas
  static const int _cacheExpirationHours = 6;

  /// Guarda las propiedades en caché
  static Future<void> saveProperties(List<Apartment> properties) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convertir propiedades a JSON
      final propertiesJson = properties.map((apartment) => apartment.toJson()).toList();
      final jsonString = jsonEncode(propertiesJson);
      
      // Guardar propiedades y timestamp
      await prefs.setString(_propertiesKey, jsonString);
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('✅ Propiedades guardadas en caché: ${properties.length}');
    } catch (e) {
      debugPrint('❌ Error guardando propiedades en caché: $e');
    }
  }

  /// Carga las propiedades desde caché
  static Future<List<Apartment>?> loadProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verificar si existe caché
      if (!prefs.containsKey(_propertiesKey)) {
        debugPrint('📭 No hay propiedades en caché');
        return null;
      }

      // Verificar si el caché no ha expirado
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - lastUpdate;
      final cacheAgeHours = cacheAge / (1000 * 60 * 60);

      if (cacheAgeHours > _cacheExpirationHours) {
        debugPrint('⏰ Caché expirado (${cacheAgeHours.toStringAsFixed(1)} horas)');
        await clearCache(); // Limpiar caché expirado
        return null;
      }

      // Cargar propiedades
      final jsonString = prefs.getString(_propertiesKey);
      if (jsonString == null) return null;

      final propertiesJson = jsonDecode(jsonString) as List;
      final properties = propertiesJson
          .map((json) => Apartment.fromJson(json))
          .toList();

      debugPrint('📦 Propiedades cargadas desde caché: ${properties.length}');
      return properties;
    } catch (e) {
      debugPrint('❌ Error cargando propiedades desde caché: $e');
      await clearCache(); // Limpiar caché corrupto
      return null;
    }
  }

  /// Verifica si hay caché válido disponible
  static Future<bool> hasCachedProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (!prefs.containsKey(_propertiesKey)) return false;

      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - lastUpdate;
      final cacheAgeHours = cacheAge / (1000 * 60 * 60);

      return cacheAgeHours <= _cacheExpirationHours;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene la información del caché
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final propertiesCount = await loadProperties();
      
      return {
        'hasCache': await hasCachedProperties(),
        'lastUpdate': DateTime.fromMillisecondsSinceEpoch(lastUpdate),
        'propertiesCount': propertiesCount?.length ?? 0,
        'cacheAgeHours': (DateTime.now().millisecondsSinceEpoch - lastUpdate) / (1000 * 60 * 60),
      };
    } catch (e) {
      return {
        'hasCache': false,
        'lastUpdate': null,
        'propertiesCount': 0,
        'cacheAgeHours': 0,
      };
    }
  }

  /// Limpia el caché de propiedades
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_propertiesKey);
      await prefs.remove(_lastUpdateKey);
      debugPrint('🧹 Caché de propiedades limpiado');
    } catch (e) {
      debugPrint('❌ Error limpiando caché: $e');
    }
  }

  /// Guarda filtros aplicados
  static Future<void> saveFilter(Map<String, dynamic> filterData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_filterKey, jsonEncode(filterData));
    } catch (e) {
      debugPrint('❌ Error guardando filtros: $e');
    }
  }

  /// Carga filtros guardados
  static Future<Map<String, dynamic>?> loadFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterString = prefs.getString(_filterKey);
      if (filterString != null) {
        return jsonDecode(filterString);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error cargando filtros: $e');
      return null;
    }
  }
}
