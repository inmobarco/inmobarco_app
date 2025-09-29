import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/apartment.dart';

class CacheService {
  static const String _propertiesKey = 'cached_properties';
  static const String _lastUpdateKey = 'last_update_timestamp';
  static const String _filterKey = 'cached_filter';
  static const String _propertiesFileName = 'properties_cache.json'; // Archivo persistente para búsquedas
  
  // Tiempo de expiración del caché en horas
  static const int _cacheExpirationHours = 6;


  /// Guarda las propiedades en caché
  static Future<void> saveProperties(List<Apartment> properties) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convertir propiedades a JSON
      final propertiesJson = properties.map((apartment) => apartment.toJson()).toList();
      final jsonString = jsonEncode(propertiesJson);
      // Guardar timestamp (solo timestamp en prefs; datos en archivo)
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      await _writePropertiesFile(jsonString); // Archivo es la fuente canónica
      
      debugPrint('✅ Propiedades guardadas en caché: ${properties.length}');
    } catch (e) {
      debugPrint('❌ Error guardando propiedades en caché: $e');
    }
  }

  /// Carga las propiedades desde caché
  static Future<List<Apartment>?> loadProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileJson = await _readPropertiesFile();
      bool hasFile = fileJson != null;

      // Migración: si no hay archivo pero existe entrada antigua en prefs, migrar a archivo.
      if (!hasFile && prefs.containsKey(_propertiesKey)) {
        final legacy = prefs.getString(_propertiesKey);
        if (legacy != null) {
          await _writePropertiesFile(legacy);
          // Opcional: limpiar JSON duplicado antiguo para evitar incongruencias
          await prefs.remove(_propertiesKey);
          debugPrint('� Migradas propiedades desde prefs al archivo.');
        }
      }

      // Releer tras posible migración
      final effectiveFileJson = hasFile ? fileJson : await _readPropertiesFile();
      if (effectiveFileJson == null) {
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

      // Ya tenemos effectiveFileJson válido aquí
      final propertiesJson = jsonDecode(effectiveFileJson) as List;
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
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      if (lastUpdate == 0) return false;
      final fileJson = await _readPropertiesFile();
      if (fileJson == null) return false;
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
      final fileInfo = await _getPropertiesFileInfo();
      
      return {
        'hasCache': await hasCachedProperties(),
        'lastUpdate': DateTime.fromMillisecondsSinceEpoch(lastUpdate),
        'propertiesCount': propertiesCount?.length ?? 0,
        'cacheAgeHours': (DateTime.now().millisecondsSinceEpoch - lastUpdate) / (1000 * 60 * 60),
        'filePath': fileInfo['path'],
        'fileSizeKB': fileInfo['sizeKB'],
      };
    } catch (e) {
      return {
        'hasCache': false,
        'lastUpdate': null,
        'propertiesCount': 0,
        'cacheAgeHours': 0,
        'filePath': null,
        'fileSizeKB': 0,
      };
    }
  }

  /// Limpia el caché de propiedades
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUpdateKey);
      // Borrar archivo persistente
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_propertiesFileName');
        if (await file.exists()) await file.delete();
      } catch (_) {}
      debugPrint('🧹 Caché de propiedades limpiado');
    } catch (e) {
      debugPrint('❌ Error limpiando caché: $e');
    }
  }


  // ================= Archivo de propiedades para búsquedas =================
  static Future<void> _writePropertiesFile(String jsonString) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_propertiesFileName');
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('⚠️ No se pudo escribir archivo de propiedades: $e');
    }
  }

  static Future<String?> _readPropertiesFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_propertiesFileName');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ No se pudo leer archivo de propiedades: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _getPropertiesFileInfo() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_propertiesFileName');
      if (await file.exists()) {
        final bytes = await file.length();
        return {
          'path': file.path,
          'sizeKB': (bytes / 1024).toStringAsFixed(1),
        };
      }
      return {'path': null, 'sizeKB': '0.0'};
    } catch (e) {
      return {'path': null, 'sizeKB': '0.0'};
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
