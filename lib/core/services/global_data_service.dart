import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/services/cache_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../constants/app_constants.dart';

/// Catálogos compartidos (ciudades, barrios, características, residenciales).
///
/// Es un [ChangeNotifier] para que un refresco en segundo plano se refleje en
/// las pantallas que los muestran sin que cada una tenga que recargar a mano.
class GlobalDataService extends ChangeNotifier {
  GlobalDataService({required CacheService cacheService})
      : _cacheService = cacheService;

  final CacheService _cacheService;

  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _features = [];
  List<Map<String, dynamic>> _residentialComplexes = [];
  List<Map<String, dynamic>> _zones = [];

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hydrated = false;
  Future<void>? _inFlightRefresh;

  // Qué necesita ir a la red: sin caché o con caché vencido.
  bool _citiesStale = true;
  bool _featuresStale = true;
  bool _zonesStale = true;
  bool _residentialsStale = true;

  // Getter para acceder a las ciudades desde cualquier parte
  List<Map<String, dynamic>> get cities => _cities;
  List<Map<String, dynamic>> get features => _features;
  List<Map<String, dynamic>> get residentialComplexes => _residentialComplexes;
  List<Map<String, dynamic>> get zones => _zones;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  WasiApiService _buildWasiApi() => WasiApiService(
        apiToken: AppConstants.wasiApiToken,
        companyId: AppConstants.wasiApiId,
      );

  /// Carga todos los catálogos desde disco. **No toca la red.**
  ///
  /// Es lo único que `main()` espera antes de `runApp`: la versión anterior
  /// esperaba características + residenciales + una llamada de zonas por
  /// ciudad, así que sin cobertura el primer frame tardaba ~30 s.
  Future<void> hydrateFromCache() async {
    if (_hydrated) return;
    _hydrated = true;

    final results = await Future.wait([
      _cacheService.loadAllowedCities(),
      _cacheService.loadFeatures(),
      _cacheService.loadZones(),
      _cacheService.loadResidentialComplexes(),
    ]);

    final cachedCities = results[0];
    final cachedFeatures = results[1];
    final cachedZones = results[2];
    final cachedResidentials = results[3];

    if (cachedCities != null) {
      _cities = cachedCities.data;
      _citiesStale = cachedCities.isStale;
    }
    if (cachedFeatures != null) {
      _features = cachedFeatures.data;
      _featuresStale = cachedFeatures.isStale;
    }
    if (cachedZones != null) {
      _zones = cachedZones.data;
      _zonesStale = cachedZones.isStale;
    }
    if (cachedResidentials != null) {
      _residentialComplexes = cachedResidentials.data;
      _residentialsStale = cachedResidentials.isStale;
    }

    _isInitialized = true;
    notifyListeners();
    debugPrint('🌍 Datos globales desde caché: ${_cities.length} ciudades, '
        '${_features.length} características, ${_zones.length} zonas, '
        '${_residentialComplexes.length} residenciales '
        '(pendiente de red: ${_stalePartsLabel()})');
  }

  /// Refresca desde la red solo lo que esté vencido o falte.
  ///
  /// Se llama después de `runApp` sin esperarla. Con [force] refresca todo.
  Future<void> refreshStale({bool force = false}) async {
    final pending = _inFlightRefresh;
    if (pending != null) {
      if (!force) {
        debugPrint('⏭️ Refresco de datos globales ya en curso');
        return;
      }
      // Un forzado (p. ej. tras login) no se descarta: espera al que corre y
      // después refresca de verdad.
      await pending;
    }

    final task = _doRefreshStale(force: force);
    _inFlightRefresh = task;
    try {
      await task;
    } finally {
      _inFlightRefresh = null;
    }
  }

  Future<void> _doRefreshStale({required bool force}) async {
    if (!force && !_citiesStale && !_featuresStale && !_zonesStale &&
        !_residentialsStale) {
      debugPrint('✅ Datos globales vigentes, no se llama a la red');
      return;
    }

    _isLoading = true;
    try {
      if (AppConstants.wasiApiToken.isEmpty) {
        debugPrint('❌ WASI API Token no está disponible');
        return;
      }

      if (force || _citiesStale) await _refreshAllowedCities();
      if (force || _featuresStale) await _refreshFeatures();
      await _refreshResidentialsAndZones(force: force);
    } catch (e, stackTrace) {
      // Nunca se descartan los datos ya cargados: un fallo de red deja el
      // último valor conocido en su lugar.
      debugPrint('❌ Error refrescando datos globales: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
    }
  }

  /// Hidrata desde caché y espera el refresco. Para pantallas que necesitan
  /// los catálogos ya cargados (p. ej. reintento desde filtros).
  Future<void> initialize() async {
    await hydrateFromCache();
    await refreshStale();
  }

  /// Refresca todos los datos globales ignorando los TTL.
  Future<void> refresh() async {
    await hydrateFromCache();
    await refreshStale(force: true);
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
        _citiesStale = false;
        await _cacheService.saveAllowedCities(fresh);
        notifyListeners();
        debugPrint('✅ Ciudades refrescadas desde backend: ${fresh.length}');
      }
    } catch (e) {
      debugPrint('⚠️ Error refrescando ciudades (se conserva caché): $e');
    }
  }

  /// Refresca las características de WASI y las persiste.
  Future<void> _refreshFeatures() async {
    try {
      final fresh = await _buildWasiApi().getFeatures();
      if (fresh.isNotEmpty) {
        _features = fresh;
        _featuresStale = false;
        await _cacheService.saveFeatures(fresh);
        notifyListeners();
        debugPrint('✅ Características refrescadas: ${fresh.length}');
      }
    } catch (e) {
      debugPrint('⚠️ Error refrescando características (se conserva caché): $e');
    }
  }

  /// Refresca unidades residenciales y, si hace falta, las zonas (barrios) de
  /// sus ciudades.
  ///
  /// Las zonas tienen un TTL mucho más largo que los residenciales, así que no
  /// se re-descargan en cada ciclo de 10 minutos: solo si vencieron, si nunca
  /// se cargaron, o si llegó un residencial cuyo barrio no está en el caché
  /// (residencial nuevo en una ciudad que aún no habíamos consultado).
  Future<void> _refreshResidentialsAndZones({required bool force}) async {
    final needsResidentials = force || _residentialsStale;
    if (!needsResidentials && !_zonesStale && !_hasResidentialWithUnknownZone) {
      return;
    }

    if (!await ApiService.hasSession()) {
      debugPrint('🔒 Sin sesión → se omiten residenciales y zonas');
      return;
    }

    if (needsResidentials) {
      debugPrint('🏢 Refrescando unidades residenciales...');
      try {
        final fresh = await ApiService.getResidentialComplexes();
        _residentialComplexes = fresh;
        _residentialsStale = false;
        await _cacheService.saveResidentialComplexes(fresh);
        notifyListeners();
        debugPrint('✅ Unidades residenciales: ${fresh.length}');
      } catch (e) {
        debugPrint('⚠️ Error refrescando residenciales (se conserva caché): $e');
      }
    }

    if (!force && !_zonesStale && !_hasResidentialWithUnknownZone) return;

    try {
      final api = _buildWasiApi();
      final cityIds = _residentialComplexes
          .map((c) => c['id_city']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      if (cityIds.isEmpty) return;

      final results = await Future.wait(cityIds.map(api.getZonesByCity));
      final fresh = results.expand((z) => z).toList();
      if (fresh.isNotEmpty) {
        _zones = fresh;
        _zonesStale = false;
        await _cacheService.saveZones(fresh);
        notifyListeners();
        debugPrint('✅ Zonas refrescadas: ${fresh.length}');
      }
    } catch (e) {
      debugPrint('⚠️ Error refrescando zonas (se conserva caché): $e');
    }
  }

  /// True si algún residencial apunta a un barrio que no está en el caché de
  /// zonas: es el caso del residencial recién creado en una ciudad nueva.
  bool get _hasResidentialWithUnknownZone {
    final known = _zones.map((z) => z['id']?.toString()).toSet();
    return _residentialComplexes.any((c) {
      final zoneId = c['id_zone']?.toString();
      return zoneId != null && zoneId.isNotEmpty && !known.contains(zoneId);
    });
  }

  /// Recarga los residenciales y sus zonas (tras crear/editar/eliminar, o con
  /// el pull-to-refresh de la pantalla de Residenciales).
  Future<void> reloadResidentials() =>
      _refreshResidentialsAndZones(force: true);

  String _stalePartsLabel() {
    final parts = <String>[
      if (_citiesStale) 'ciudades',
      if (_featuresStale) 'características',
      if (_zonesStale) 'zonas',
      if (_residentialsStale) 'residenciales',
    ];
    return parts.isEmpty ? 'nada' : parts.join(', ');
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
