import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../domain/models/apartment.dart';
import '../../domain/models/property_filter.dart';
import '../../data/services/wasi_api_service.dart';
import '../../data/services/cache_service.dart';
import '../../core/constants/app_constants.dart';

class PropertyProvider extends ChangeNotifier {
  final WasiApiService _apiService;
  
  List<Apartment> _properties = [];
  PropertyFilter _currentFilter = PropertyFilter();
  bool _isLoading = false;
  String? _error;
  bool _hasMoreData = true;
  int _currentPage = 1;
  bool _isLoadingFromCache = false;
  String _searchQuery = '';
  Timer? _searchDebounceTimer;

  static const Duration _searchDebounceDuration = Duration(milliseconds: 350); // Ajustable

  PropertyProvider({required WasiApiService apiService}) 
      : _apiService = apiService {
    _loadFromCache(); // Cargar caché al inicializar
  }

  // Getters
  List<Apartment> get properties => _properties;
  // Lista visible (aplica filtro de búsqueda por registration_number/reference si existe query)
  List<Apartment> get filteredProperties {
    if (_searchQuery.isEmpty) return _properties;
    final q = _searchQuery.toLowerCase();
    return _properties.where((p) => p.reference.toLowerCase().contains(q)).toList();
  }
  PropertyFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;
  bool get hasActiveFilters => _currentFilter.hasActiveFilters;
  bool get isLoadingFromCache => _isLoadingFromCache;

  /// Carga propiedades desde caché al inicializar
  Future<void> _loadFromCache() async {
    _isLoadingFromCache = true;
    notifyListeners();

    try {
      final cachedProperties = await CacheService.loadProperties();
      if (cachedProperties != null && cachedProperties.isNotEmpty) {
        _properties = cachedProperties;
        _hasMoreData = false; // No intentar cargar más hasta hacer refresh
        debugPrint('📦 ${cachedProperties.length} propiedades cargadas desde caché');
      }
    } catch (e) {
      debugPrint('❌ Error cargando caché: $e');
    }

    _isLoadingFromCache = false;
    notifyListeners();
  }

  /// Carga las propiedades iniciales
  Future<void> loadProperties({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _properties.clear();
    }

    if (_isLoading || !_hasMoreData) return;

    _setLoading(true);
    _setError(null);

    try {
      final newProperties = await _apiService.getActiveProperties(
        filter: _currentFilter,
        page: _currentPage,
        limit: AppConstants.pageSize,
      );

      if (refresh) {
        _properties = newProperties;
      } else {
        _properties.addAll(newProperties);
      }

      _currentPage++;
      // Si recibimos menos elementos que el tamaño de página asumimos que no hay más datos.
      _hasMoreData = newProperties.length == AppConstants.pageSize;

      // Guardar en caché sólo después de completar la primera página (ya en _properties) o en refresh.
      // _currentPage se incrementó, así que cuando era página 1 ahora vale 2.
      if (_currentPage == 2) {
        // Persistimos únicamente la primera página (hasta 100 propiedades) como snapshot rápido de arranque.
        await CacheService.saveProperties(_properties.take(AppConstants.pageSize).toList());
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Carga más propiedades (para paginación)
  Future<void> loadMoreProperties() async {
    if (!_hasMoreData || _isLoading) return;
    await loadProperties();
  }

  /// Actualiza los filtros y recarga las propiedades
  Future<void> updateFilter(PropertyFilter newFilter) async {
    _currentFilter = newFilter;
    _currentPage = 1;
    _hasMoreData = true;
    _properties.clear();
    
    // Guardar filtros aplicados
    await CacheService.saveFilter(newFilter.toJson());
    
    await loadProperties();
  }

  /// Limpia los filtros
  Future<void> clearFilters() async {
    _currentFilter = PropertyFilter();
    _currentPage = 1;
    _hasMoreData = true;
    _properties.clear();
    
    // Limpiar filtros guardados
    await CacheService.saveFilter({});
    
    await loadProperties();
  }

  /// Obtiene una propiedad por ID con detalle completo (fotos + características).
  ///
  /// Siempre consulta la API con short=false para garantizar que se incluyan
  /// galerías y características completas, ya que la lista se carga con short=true.
  Future<Apartment?> getPropertyById(String id) async {
    try {
      // Retornar la versión local inmediatamente si existe, para mostrar algo rápido.
      final localIndex = _properties.indexWhere((p) => p.id == id);
      final localProperty = localIndex != -1 ? _properties[localIndex] : null;

      // Siempre traer detalle completo desde la API (short=false incluye galerías).
      try {
        final detailedProperty = await _apiService.getPropertyById(id);

        // Actualizar la entrada local con los datos completos.
        if (localIndex != -1) {
          _properties[localIndex] = detailedProperty;
        } else {
          _properties.add(detailedProperty);
        }
        notifyListeners();
        return detailedProperty;
      } catch (apiError) {
        // Si falla la API pero tenemos datos locales, devolverlos como fallback.
        if (localProperty != null) {
          debugPrint('⚠️ Usando datos locales para propiedad $id: $apiError');
          return localProperty;
        }
        rethrow;
      }
    } catch (e) {
      throw Exception('Error obteniendo propiedad: $e');
    }
  }

  /// Busca propiedades en la lista actual
  List<Apartment> searchProperties(String query) {
    // Compatibilidad: delega a la lógica específica por reference
    return _properties.where((p) => p.reference.toLowerCase().contains(query.toLowerCase())).toList();
  }

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

  /// Refresca todos los datos desde la API
  Future<void> refresh() async {
    debugPrint('🔄 Refrescando datos desde la API...');
    await loadProperties(refresh: true);
  }

  /// Obtiene información del caché
  Future<Map<String, dynamic>> getCacheInfo() async {
    return await CacheService.getCacheInfo();
  }

  /// Obtiene información del almacenamiento total
  Future<Map<String, dynamic>> getTotalStorageInfo() async {
    return await CacheService.getTotalStorageInfo();
  }

  /// Limpia el caché manualmente
  Future<void> clearCache() async {
    await CacheService.clearCache();
    _properties.clear();
    notifyListeners();
  }
}
