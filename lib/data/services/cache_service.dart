import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/apartment.dart';
import '../../domain/models/client.dart';

/// Resultado de una lectura de caché: los datos y si ya superaron su TTL.
///
/// Los cachés no se borran al vencer: entregan el último valor conocido
/// marcado como `isStale` para que la app pueda pintar algo de inmediato y
/// refrescar en segundo plano. Sin red y con caché vencido, mostrar datos
/// viejos es mejor que mostrar una pantalla vacía.
class CachedResult<T> {
  const CachedResult({required this.data, required this.isStale});

  final T data;
  final bool isStale;
}

class CacheService {
  static const String _propertiesKey = 'cached_properties';
  static const String _lastUpdateKey = 'last_update_timestamp';
  static const String _filterKey = 'cached_filter';
  static const String _propertiesFileName = 'properties_cache.json'; // Archivo persistente para búsquedas
  static const String _addPropertyDraftFileName = 'add_property_draft.json'; // Borrador formulario nueva propiedad
  static const String _userProfileFileName = 'user_profile.json';
  static const String _authSessionFileName = 'auth_session.json'; // Sesión de autenticación
  static const String _appVersionKey = 'cached_app_version';
  static const String _allowedCitiesFileName = 'allowed_cities_cache.json'; // Ciudades habilitadas
  static const String _allowedCitiesUpdateKey = 'last_allowed_cities_update';
  static const String _clientsFileName = 'clients_cache.json'; // Clientes CRM (desde WASI)
  static const String _clientsUpdateKey = 'last_clients_update';
  static const String _advisorMapFileName = 'advisor_map_cache.json'; // Propiedad dummy del asesor (sin TTL)

  // Tiempo de expiración del caché en horas
  static const int _cacheExpirationHours = 6;

  // Tiempo de expiración del caché de ciudades (minutos)
  static const int _allowedCitiesExpirationMinutes = 10;

  CacheService();

  /// Guarda las propiedades en caché
  Future<void> saveProperties(List<Apartment> properties) async {
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

  /// Carga las propiedades desde caché.
  ///
  /// Retorna null solo si no hay caché o está corrupto. Si venció el TTL, los
  /// datos se devuelven marcados como `isStale` (last-known-good).
  Future<CachedResult<List<Apartment>>?> loadProperties() async {
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
          debugPrint('🔄 Migradas propiedades desde prefs al archivo.');
        }
      }

      // Releer tras posible migración
      final effectiveFileJson = hasFile ? fileJson : await _readPropertiesFile();
      if (effectiveFileJson == null) {
        debugPrint('📭 No hay propiedades en caché');
        return null;
      }

      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - lastUpdate;
      final cacheAgeHours = cacheAge / (1000 * 60 * 60);
      final isStale = cacheAgeHours > _cacheExpirationHours;

      // Ya tenemos effectiveFileJson válido aquí
      final propertiesJson = jsonDecode(effectiveFileJson) as List;
      final properties = propertiesJson
          .map((json) => Apartment.fromJson(json))
          .toList();

      debugPrint('📦 Propiedades cargadas desde caché: ${properties.length}'
          '${isStale ? ' (vencido ${cacheAgeHours.toStringAsFixed(1)} h, se refrescará)' : ''}');
      return CachedResult(data: properties, isStale: isStale);
    } catch (e) {
      debugPrint('❌ Error cargando propiedades desde caché: $e');
      await clearCache(); // Limpiar caché corrupto
      return null;
    }
  }

  /// Verifica si hay caché válido disponible
  Future<bool> hasCachedProperties() async {
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
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final cached = await loadProperties();
      final fileInfo = await _getPropertiesFileInfo();

      return {
        'hasCache': await hasCachedProperties(),
        'isStale': cached?.isStale ?? true,
        'lastUpdate': DateTime.fromMillisecondsSinceEpoch(lastUpdate),
        'propertiesCount': cached?.data.length ?? 0,
        'cacheAgeHours': (DateTime.now().millisecondsSinceEpoch - lastUpdate) / (1000 * 60 * 60),
        'filePath': fileInfo['path'],
        'fileSizeKB': fileInfo['sizeKB'],
      };
    } catch (e) {
      return {
        'hasCache': false,
        'isStale': true,
        'lastUpdate': null,
        'propertiesCount': 0,
        'cacheAgeHours': 0,
        'filePath': null,
        'fileSizeKB': 0,
      };
    }
  }

  /// Limpia el caché de propiedades
  Future<void> clearCache() async {
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
  Future<void> _writePropertiesFile(String jsonString) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_propertiesFileName');
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('⚠️ No se pudo escribir archivo de propiedades: $e');
    }
  }

  Future<String?> _readPropertiesFile() async {
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

  Future<Map<String, dynamic>> _getPropertiesFileInfo() async {
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

  // ================== Borrador formulario Agregar Propiedad ==================
  Future<void> saveAddPropertyDraft(Map<String, dynamic> data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_addPropertyDraftFileName');
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar borrador de apartamento: $e');
    }
  }

  Future<Map<String, dynamic>?> loadAddPropertyDraft() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_addPropertyDraftFileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar borrador de apartamento: $e');
      return null;
    }
  }

  Future<void> clearAddPropertyDraft() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_addPropertyDraftFileName');
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('⚠️ No se pudo borrar borrador de apartamento: $e');
    }
  }

  // ================== Perfil usuario ==================
  Future<void> saveUserProfile(Map<String, dynamic> data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_userProfileFileName');
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar perfil de usuario: $e');
    }
  }

  Future<Map<String, dynamic>?> loadUserProfile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_userProfileFileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar perfil de usuario: $e');
      return null;
    }
  }

  Future<void> clearUserProfile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_userProfileFileName');
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('⚠️ No se pudo borrar perfil de usuario: $e');
    }
  }

  // ================== Sesión de autenticación ==================

  /// Guarda la sesión de autenticación
  Future<void> saveAuthSession(Map<String, dynamic> data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_authSessionFileName');
      await file.writeAsString(jsonEncode(data), flush: true);
      debugPrint('✅ Sesión de autenticación guardada');
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar sesión de autenticación: $e');
    }
  }

  /// Carga la sesión de autenticación guardada
  Future<Map<String, dynamic>?> loadAuthSession() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_authSessionFileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar sesión de autenticación: $e');
      return null;
    }
  }

  /// Elimina la sesión de autenticación
  Future<void> clearAuthSession() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_authSessionFileName');
      if (await file.exists()) await file.delete();
      debugPrint('🧹 Sesión de autenticación eliminada');
    } catch (e) {
      debugPrint('⚠️ No se pudo borrar sesión de autenticación: $e');
    }
  }

  // ================== Ciudades habilitadas ==================

  /// Guarda las ciudades habilitadas en caché (archivo + timestamp).
  Future<void> saveAllowedCities(List<Map<String, dynamic>> cities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_allowedCitiesFileName');
      await file.writeAsString(jsonEncode(cities), flush: true);
      await prefs.setInt(_allowedCitiesUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar ciudades en caché: $e');
    }
  }

  /// Carga las ciudades habilitadas desde caché.
  ///
  /// Retorna null si no hay caché; si venció, los datos van marcados como
  /// `isStale` para entregar el último valor conocido cuando el backend no
  /// responde.
  Future<CachedResult<List<Map<String, dynamic>>>?> loadAllowedCities() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_allowedCitiesFileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final cities = (jsonDecode(content) as List).cast<Map<String, dynamic>>();

      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_allowedCitiesUpdateKey) ?? 0;
      final ageMinutes = (DateTime.now().millisecondsSinceEpoch - lastUpdate) / (1000 * 60);

      return CachedResult(
        data: cities,
        isStale: ageMinutes > _allowedCitiesExpirationMinutes,
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar ciudades desde caché: $e');
      return null;
    }
  }

  // ================== Clientes CRM ==================

  /// Guarda los clientes CRM (ya cruzados con WASI) en caché.
  Future<void> saveClients(List<Client> clients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_clientsFileName');
      final jsonString = jsonEncode(clients.map((c) => c.toJson()).toList());
      await file.writeAsString(jsonString, flush: true);
      await prefs.setInt(_clientsUpdateKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('✅ Clientes guardados en caché: ${clients.length}');
    } catch (e) {
      debugPrint('❌ Error guardando clientes en caché: $e');
    }
  }

  /// Carga los clientes CRM desde caché.
  ///
  /// Retorna null solo si no hay caché o está corrupto; vencido el TTL de 6 h
  /// los datos van marcados como `isStale`.
  Future<CachedResult<List<Client>>?> loadClients() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_clientsFileName');
      if (!await file.exists()) {
        debugPrint('📭 No hay clientes en caché');
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_clientsUpdateKey) ?? 0;
      final cacheAgeHours =
          (DateTime.now().millisecondsSinceEpoch - lastUpdate) / (1000 * 60 * 60);
      final isStale = cacheAgeHours > _cacheExpirationHours;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final clients = (jsonDecode(content) as List)
          .map((json) => Client.fromJson(json as Map<String, dynamic>))
          .toList();
      debugPrint('📦 Clientes cargados desde caché: ${clients.length}'
          '${isStale ? ' (vencido ${cacheAgeHours.toStringAsFixed(1)} h, se refrescará)' : ''}');
      return CachedResult(data: clients, isStale: isStale);
    } catch (e) {
      debugPrint('❌ Error cargando clientes desde caché: $e');
      await clearClientsCache(); // Limpiar caché corrupto
      return null;
    }
  }

  /// Guarda la propiedad dummy del asesor (advisor-map). Sin TTL: solo se
  /// invalida al cerrar sesión, la relación asesor↔propiedad no cambia.
  Future<void> saveAdvisorMap(Map<String, dynamic> data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_advisorMapFileName');
      await file.writeAsString(jsonEncode(data), flush: true);
      debugPrint('✅ Advisor-map guardado en caché');
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar advisor-map: $e');
    }
  }

  /// Carga la propiedad dummy del asesor desde caché.
  Future<Map<String, dynamic>?> loadAdvisorMap() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_advisorMapFileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar advisor-map: $e');
      return null;
    }
  }

  /// Elimina el advisor-map (al cerrar sesión).
  Future<void> clearAdvisorMap() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_advisorMapFileName');
      if (await file.exists()) await file.delete();
      debugPrint('🧹 Advisor-map eliminado');
    } catch (e) {
      debugPrint('⚠️ No se pudo borrar advisor-map: $e');
    }
  }

  /// Limpia el caché de clientes CRM.
  Future<void> clearClientsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clientsUpdateKey);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_clientsFileName');
      if (await file.exists()) await file.delete();
      debugPrint('🧹 Caché de clientes limpiado');
    } catch (e) {
      debugPrint('❌ Error limpiando caché de clientes: $e');
    }
  }

  // ================= Versión de la app =================

  /// Guarda la versión actual de la app en caché
  Future<void> saveAppVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appVersionKey, version);
  }

  /// Obtiene la versión guardada en caché
  Future<String?> getAppVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appVersionKey);
  }

  /// Limpia todo el caché (archivos + SharedPreferences), excepto la sesión de autenticación
  Future<void> clearAllCache() async {
    try {
      // Borrar archivos
      final dir = await getApplicationDocumentsDirectory();
      final fileNames = [
        _propertiesFileName,
        _addPropertyDraftFileName,
        _userProfileFileName,
        _allowedCitiesFileName,
        _clientsFileName,
        _advisorMapFileName,
      ];
      for (final name in fileNames) {
        final file = File('${dir.path}/$name');
        if (await file.exists()) await file.delete();
      }

      // Borrar claves de SharedPreferences (excepto auth)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_propertiesKey);
      await prefs.remove(_lastUpdateKey);
      await prefs.remove(_filterKey);
      await prefs.remove(_allowedCitiesUpdateKey);
      await prefs.remove(_clientsUpdateKey);

      debugPrint('🧹 Todo el caché limpiado por cambio de versión');
    } catch (e) {
      debugPrint('❌ Error limpiando todo el caché: $e');
    }
  }

  /// Obtiene el tamaño total de todo el almacenamiento local (archivos + SharedPreferences)
  Future<Map<String, dynamic>> getTotalStorageInfo() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final prefs = await SharedPreferences.getInstance();

      // ── Archivos en documents directory ──
      final files = <String, int>{};
      final fileNames = [
        _propertiesFileName,
        _addPropertyDraftFileName,
        _userProfileFileName,
        _authSessionFileName,
        _allowedCitiesFileName,
        _clientsFileName,
        _advisorMapFileName,
      ];
      for (final name in fileNames) {
        final file = File('${dir.path}/$name');
        if (await file.exists()) {
          files[name] = await file.length();
        }
      }

      // ── SharedPreferences (estimar tamaño serializado) ──
      int prefsBytes = 0;
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        // Sumar tamaño de la clave
        prefsBytes += key.length * 2; // UTF-16
        final value = prefs.get(key);
        if (value is String) {
          prefsBytes += value.length * 2;
        } else if (value is int || value is double) {
          prefsBytes += 8;
        } else if (value is bool) {
          prefsBytes += 1;
        } else if (value is List<String>) {
          for (final s in value) {
            prefsBytes += s.length * 2;
          }
        }
      }

      final totalFileBytes = files.values.fold<int>(0, (sum, v) => sum + v);
      final totalBytes = totalFileBytes + prefsBytes;

      return {
        'files': files,
        'totalFileBytes': totalFileBytes,
        'prefsBytes': prefsBytes,
        'prefsKeyCount': allKeys.length,
        'totalBytes': totalBytes,
        'totalFormatted': _formatBytes(totalBytes),
        'filesFormatted': _formatBytes(totalFileBytes),
        'prefsFormatted': _formatBytes(prefsBytes),
      };
    } catch (e) {
      debugPrint('❌ Error calculando almacenamiento total: $e');
      return {
        'files': <String, int>{},
        'totalFileBytes': 0,
        'prefsBytes': 0,
        'prefsKeyCount': 0,
        'totalBytes': 0,
        'totalFormatted': '0 B',
        'filesFormatted': '0 B',
        'prefsFormatted': '0 B',
      };
    }
  }

  /// Formatea bytes a unidad legible (B, KB, MB)
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Guarda filtros aplicados
  Future<void> saveFilter(Map<String, dynamic> filterData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_filterKey, jsonEncode(filterData));
    } catch (e) {
      debugPrint('❌ Error guardando filtros: $e');
    }
  }

  /// Carga filtros guardados
  Future<Map<String, dynamic>?> loadFilter() async {
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
