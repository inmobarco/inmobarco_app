import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../domain/models/apartment.dart';
import '../../domain/models/property_filter.dart';
import '../../data/services/wasi_api_service.dart';
import '../../data/services/cache_service.dart';
import '../../core/constants/app_constants.dart';

/// Estado de la lista de propiedades.
///
/// Modo normal: el inventario activo completo vive en local (`inventario` en
/// caché con TTL de 6 h), y filtro, búsqueda y paginación se resuelven sobre
/// esa lista sin tocar la red. Con <500 propiedades el sync completo son ≤5
/// peticiones, así que la red no puede aportar nada que no esté ya en el
/// dispositivo.
///
/// Modo degradado: mientras no exista inventario local (primera instalación,
/// sync en curso o fallido) se cae a la paginación de la API con los filtros
/// del lado del servidor, que es el comportamiento anterior.
class PropertyProvider extends ChangeNotifier {
  final WasiApiService _apiService;
  final CacheService _cacheService;

  /// Tope de páginas del sync completo. A 100 por página son 6.000
  /// propiedades: muy por encima del inventario real, y evita un bucle
  /// infinito si la API dejara de acortar la última página.
  static const int _maxInventoryPages = 60;

  // ── Inventario local (fuente de verdad cuando está completo) ──
  List<Apartment> _inventory = [];
  bool _inventoryComplete = false;
  bool _inventoryStale = false;
  List<Apartment>? _matchingCache;

  // ── Modo degradado: páginas traídas de la API ──
  final List<Apartment> _remotePages = [];
  int _remotePage = 1;
  bool _remoteHasMore = true;

  // ── Paginación local ──
  int _visibleCount = AppConstants.pageSize;

  PropertyFilter _currentFilter = PropertyFilter();
  bool _isLoading = false;
  bool _isSyncingInventory = false;
  int _syncedCount = 0;
  int? _syncTotal;
  String? _error;
  bool _isLoadingFromCache = false;
  String _searchQuery = '';
  Timer? _searchDebounceTimer;

  static const Duration _searchDebounceDuration = Duration(milliseconds: 350); // Ajustable

  PropertyProvider({
    required WasiApiService apiService,
    required CacheService cacheService,
  })  : _apiService = apiService,
       _cacheService = cacheService {
    _hydration = _loadFromCache(); // Cargar caché al inicializar
  }

  late final Future<void> _hydration;

  /// Se completa cuando terminó la lectura del caché.
  ///
  /// Quien decida si hace falta ir a la red debe esperarlo: la lectura es E/S
  /// asíncrona y no alcanza a terminar en el mismo frame, así que consultar
  /// `properties.isEmpty` de una vez descartaba el caché casi siempre.
  Future<void> get hydration => _hydration;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// True si hay inventario completo en local: filtro y búsqueda son locales.
  bool get hasLocalInventory => _inventoryComplete && _inventory.isNotEmpty;

  /// Propiedades del inventario local (0 en modo degradado).
  int get inventoryCount => _inventory.length;

  /// Página visible de la lista ya filtrada.
  List<Apartment> get properties => hasLocalInventory
      ? _matching.take(_visibleCount).toList()
      : List.unmodifiable(_remotePages);

  /// Lista visible aplicando además la búsqueda por referencia o id de WASI.
  ///
  /// Con inventario local la búsqueda recorre **todo** el inventario, no solo
  /// las páginas ya visibles.
  List<Apartment> get filteredProperties {
    if (_searchQuery.isEmpty) return properties;
    final q = _searchQuery.toLowerCase();
    final base = hasLocalInventory ? _matching : _remotePages;
    return base
        .where((p) => p.reference.toLowerCase().contains(q) || p.id.contains(q))
        .toList();
  }

  PropertyFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading || _isSyncingInventory;
  String? get error => _error;
  bool get hasActiveFilters => _currentFilter.hasActiveFilters;
  bool get isLoadingFromCache => _isLoadingFromCache;

  /// True si lo que hay en pantalla viene de un caché vencido y conviene
  /// refrescar desde la API.
  bool get isCacheStale => _inventoryStale;

  bool get hasMoreData => hasLocalInventory
      ? _visibleCount < _matching.length
      : _remoteHasMore;

  /// True mientras corre el sync completo del inventario.
  bool get isSyncingInventory => _isSyncingInventory;

  /// Propiedades descargadas en el sync en curso.
  int get syncedCount => _syncedCount;

  /// Total que reporta WASI para el sync en curso (null si aún no llega).
  int? get syncTotal => _syncTotal;

  /// Inventario que pasa el filtro activo, memorizado hasta que cambie el
  /// filtro o el inventario.
  List<Apartment> get _matching =>
      _matchingCache ??= _inventory.where(_matchesFilter).toList();

  void _invalidateMatching() => _matchingCache = null;

  // ---------------------------------------------------------------------------
  // Caché
  // ---------------------------------------------------------------------------

  /// Carga propiedades desde caché al inicializar
  Future<void> _loadFromCache() async {
    _isLoadingFromCache = true;
    notifyListeners();

    try {
      final cached = await _cacheService.loadProperties();
      if (cached != null && cached.data.isNotEmpty) {
        final complete = await _cacheService.isCachedInventoryComplete();
        if (complete) {
          _inventory = cached.data;
          _inventoryComplete = true;
          _inventoryStale = cached.isStale;
          _invalidateMatching();
        } else {
          // Snapshot parcial (versión anterior de la app): sirve para pintar
          // algo de inmediato, pero no para filtrar en local. Se marca como
          // vencido para que se dispare el sync completo.
          _remotePages
            ..clear()
            ..addAll(cached.data);
          _remoteHasMore = false;
          _inventoryStale = true;
        }
        debugPrint('📦 ${cached.data.length} propiedades desde caché'
            '${complete ? ' (inventario completo)' : ' (parcial)'}'
            '${cached.isStale ? ' · vencido' : ''}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando caché: $e');
    }

    _isLoadingFromCache = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sync completo del inventario
  // ---------------------------------------------------------------------------

  /// Descarga el inventario activo completo paginando `/property/search`.
  ///
  /// Sin filtros por construcción: lo que se persiste es el inventario, nunca
  /// un subconjunto filtrado. Si falla, conserva el inventario anterior.
  Future<void> syncInventory({bool force = false}) async {
    if (_isSyncingInventory) return;
    if (!force && _inventoryComplete && !_inventoryStale) {
      debugPrint('✅ Inventario local vigente (${_inventory.length}), sin sync');
      return;
    }

    _isSyncingInventory = true;
    _syncedCount = 0;
    _syncTotal = null;
    _error = null;
    notifyListeners();

    try {
      final all = <Apartment>[];
      var page = 1;

      while (page <= _maxInventoryPages) {
        final result = await _apiService.getPropertiesPage(
          page: page,
          limit: AppConstants.pageSize,
        );
        all.addAll(result.items);

        _syncedCount = all.length;
        if (result.total > 0) _syncTotal = result.total;
        notifyListeners();

        final reachedTotal = result.total > 0 && all.length >= result.total;
        if (result.items.length < AppConstants.pageSize || reachedTotal) break;
        page++;
      }

      if (all.isEmpty && _inventory.isNotEmpty) {
        // Respuesta vacía con inventario previo: más probable un problema del
        // lado de WASI que un inventario realmente vacío. No se descarta lo
        // que ya teníamos.
        debugPrint('⚠️ El sync devolvió 0 propiedades; se conserva el inventario');
        return;
      }

      _inventory = all;
      _inventoryComplete = true;
      _inventoryStale = false;
      _visibleCount = AppConstants.pageSize;
      _remotePages.clear();
      _remoteHasMore = false;
      _invalidateMatching();

      await _cacheService.saveProperties(all, complete: true);
      debugPrint('🔄 Inventario sincronizado: ${all.length} propiedades '
          'en $page página(s)');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error sincronizando inventario: $e');
    } finally {
      _isSyncingInventory = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Carga / paginación
  // ---------------------------------------------------------------------------

  /// Punto de entrada de carga.
  ///
  /// Con [refresh] fuerza el sync completo. Sin él, sincroniza solo si el
  /// inventario está vencido, y en modo degradado trae la siguiente página.
  Future<void> loadProperties({bool refresh = false}) async {
    if (refresh) {
      await syncInventory(force: true);
      return;
    }
    if (hasLocalInventory) {
      await syncInventory();
      return;
    }
    await _loadRemotePage();
  }

  /// Carga más propiedades: en local es solo mostrar más de lo que ya está.
  Future<void> loadMoreProperties() async {
    if (hasLocalInventory) {
      if (_visibleCount >= _matching.length) return;
      _visibleCount += AppConstants.pageSize;
      notifyListeners();
      return;
    }
    if (!_remoteHasMore || _isLoading) return;
    await _loadRemotePage();
  }

  /// Modo degradado: página de la API con los filtros del lado del servidor.
  Future<void> _loadRemotePage() async {
    if (_isLoading || !_remoteHasMore) return;

    _setLoading(true);
    _setError(null);

    try {
      final newProperties = await _apiService.getActiveProperties(
        filter: _currentFilter,
        page: _remotePage,
        limit: AppConstants.pageSize,
      );

      _remotePages.addAll(newProperties);
      _remotePage++;
      _remoteHasMore = newProperties.length == AppConstants.pageSize;

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Filtros
  // ---------------------------------------------------------------------------

  /// Actualiza los filtros. Con inventario local es instantáneo y sin red.
  Future<void> updateFilter(PropertyFilter newFilter) async {
    _currentFilter = newFilter;
    _visibleCount = AppConstants.pageSize;
    _invalidateMatching();

    // Guardar filtros aplicados
    await _cacheService.saveFilter(newFilter.toJson());

    if (hasLocalInventory) {
      notifyListeners();
      return;
    }

    _remotePages.clear();
    _remotePage = 1;
    _remoteHasMore = true;
    await _loadRemotePage();
  }

  /// Limpia los filtros
  Future<void> clearFilters() => updateFilter(PropertyFilter());

  /// Aplica el filtro activo a una propiedad.
  ///
  /// Es más preciso que la API de WASI: allí `minBanos` y `minGarages` van a
  /// `bathrooms`/`garages`, que son coincidencia exacta y no mínimo, y
  /// `min_price`/`max_price` no distinguen arriendo de venta.
  bool _matchesFilter(Apartment a) {
    final f = _currentFilter;
    if (!f.hasActiveFilters) return true;

    if (f.minCuartos != null && a.cuartos < f.minCuartos!) return false;
    if (f.minBanos != null && a.banos < f.minBanos!) return false;
    if (f.minGarages != null && a.garages < f.minGarages!) return false;
    if (f.minArea != null && a.area < f.minArea!) return false;
    if (f.forRent == true && !a.forRent) return false;
    if (f.forSale == true && !a.forSale) return false;
    if (!_matchesPrice(a, f)) return false;
    if (f.municipio != null && !_matchesCity(a, f)) return false;
    if (f.idZone != null && !_matchesZone(a, f)) return false;
    if (f.idPropertyType != null && !_matchesType(a, f)) return false;

    return true;
  }

  /// Rango de precio contra el precio del negocio pedido: arriendo si se filtró
  /// arriendo, venta si se filtró venta, cualquiera de los dos si no se
  /// especificó.
  bool _matchesPrice(Apartment a, PropertyFilter f) {
    if (f.minPrecio == null && f.maxPrecio == null) return true;

    final wantsRent = f.forRent == true;
    final wantsSale = f.forSale == true;
    final prices = <double>[
      if (wantsRent || !wantsSale) a.rentPrice,
      if (wantsSale || !wantsRent) a.salePrice,
    ];

    return prices.any((price) =>
        price > 0 &&
        (f.minPrecio == null || price >= f.minPrecio!) &&
        (f.maxPrecio == null || price <= f.maxPrecio!));
  }

  /// Compara por id cuando ambos lados lo tienen; si no, por etiqueta.
  ///
  /// Si no hay ni id ni etiqueta contra la que comparar, la propiedad **no**
  /// pasa: el filtro está activo y no se puede confirmar que lo cumpla.
  bool _matchesCity(Apartment a, PropertyFilter f) {
    final id = f.idCity;
    if (a.idCity.isNotEmpty && id != null && id.isNotEmpty) {
      return a.idCity == id;
    }
    final name = f.municipio;
    if (name == null || name.isEmpty) return true;
    return _sameLabel(a.municipio, name);
  }

  bool _matchesZone(Apartment a, PropertyFilter f) {
    if (a.idZone.isNotEmpty) return a.idZone == f.idZone;
    final name = f.zoneName;
    if (name == null || name.isEmpty) return false;
    return _sameLabel(a.barrio, name);
  }

  bool _matchesType(Apartment a, PropertyFilter f) {
    if (a.idPropertyType.isNotEmpty) {
      return a.idPropertyType == f.idPropertyType;
    }
    final label = AppConstants.allPropertyTypes.firstWhere(
      (t) => t['id'] == f.idPropertyType,
      orElse: () => const <String, String>{},
    )['label'];
    if (label == null || label.isEmpty) return false;
    return _sameLabel(a.claseInmueble, label);
  }

  bool _sameLabel(String value, String expected) =>
      value.trim().toLowerCase() == expected.trim().toLowerCase();

  // ---------------------------------------------------------------------------
  // Detalle
  // ---------------------------------------------------------------------------

  /// Obtiene una propiedad con detalle completo (fotos + características).
  ///
  /// Orden: caché de detalle vigente (24 h) → API → caché vencido → copia
  /// corta de la lista. El detalle se guarda solo para las propiedades que el
  /// asesor abre; nunca se descargan las galerías del inventario entero.
  Future<Apartment?> getPropertyById(String id) async {
    final localProperty = _findLocal(id);
    final cached = await _cacheService.loadPropertyDetail(id);

    if (cached != null && !cached.isStale) {
      _mergeDetail(cached.data);
      debugPrint('📦 Detalle de $id desde caché');
      return cached.data;
    }

    try {
      final detailed = await _apiService.getPropertyById(id);
      _mergeDetail(detailed);
      await _cacheService.savePropertyDetail(detailed);
      return detailed;
    } catch (apiError) {
      if (cached != null) {
        debugPrint('⚠️ Detalle vencido de $id servido desde caché: $apiError');
        _mergeDetail(cached.data);
        return cached.data;
      }
      if (localProperty != null) {
        debugPrint('⚠️ Usando datos locales para propiedad $id: $apiError');
        return localProperty;
      }
      throw Exception('Error obteniendo propiedad: $apiError');
    }
  }

  Apartment? _findLocal(String id) {
    for (final list in [_inventory, _remotePages]) {
      for (final property in list) {
        if (property.id == id) return property;
      }
    }
    return null;
  }

  /// Reemplaza la versión corta por la detallada en la lista que la contenga.
  void _mergeDetail(Apartment detailed) {
    var found = false;
    for (final list in [_inventory, _remotePages]) {
      final index = list.indexWhere((p) => p.id == detailed.id);
      if (index != -1) {
        list[index] = detailed;
        found = true;
      }
    }
    if (!found && _inventory.isNotEmpty) _inventory.add(detailed);
    _invalidateMatching();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Búsqueda
  // ---------------------------------------------------------------------------

  /// Limpia la búsqueda activa
  void clearSearchQuery() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _searchDebounceTimer?.cancel();
    notifyListeners();
  }

  /// Actualiza el texto de búsqueda con debounce para evitar rebuild en cada pulsación
  void updateSearchQuery(String query) {
    final trimmed = query.trim();

    // Si se limpia el texto, aplicar inmediatamente y cancelar timer
    if (trimmed.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        _searchQuery = '';
        _searchDebounceTimer?.cancel();
        notifyListeners();
      }
      return;
    }

    // Si no cambia realmente el contenido, no reprogramar
    if (trimmed == _searchQuery) return;

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      _searchQuery = trimmed;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Refresca todo el inventario desde la API
  Future<void> refresh() async {
    debugPrint('🔄 Refrescando inventario desde la API...');
    await syncInventory(force: true);
  }

  /// Obtiene información del caché
  Future<Map<String, dynamic>> getCacheInfo() async {
    return await _cacheService.getCacheInfo();
  }

  /// Obtiene información del almacenamiento total
  Future<Map<String, dynamic>> getTotalStorageInfo() async {
    return await _cacheService.getTotalStorageInfo();
  }

  /// Limpia el caché manualmente
  Future<void> clearCache() async {
    await _cacheService.clearCache();
    _inventory = [];
    _inventoryComplete = false;
    _inventoryStale = true;
    _remotePages.clear();
    _remotePage = 1;
    _remoteHasMore = true;
    _visibleCount = AppConstants.pageSize;
    _invalidateMatching();
    notifyListeners();
  }
}
