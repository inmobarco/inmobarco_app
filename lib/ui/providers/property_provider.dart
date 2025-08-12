import 'package:flutter/foundation.dart';
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

  PropertyProvider({required WasiApiService apiService}) 
      : _apiService = apiService {
    _loadFromCache(); // Cargar caché al inicializar
  }

  // Getters
  List<Apartment> get properties => _properties;
  List<Map<String, dynamic>> get cities => AppConstants.cities; // Usar datos globales
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
        limit: 20,
      );

      if (refresh) {
        _properties = newProperties;
      } else {
        _properties.addAll(newProperties);
      }

      _currentPage++;
      _hasMoreData = newProperties.length >= 20;

      // Guardar en caché si es la primera página o refresh
      if (_currentPage == 2 || refresh) {
        await CacheService.saveProperties(_properties);
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

  /// Obtiene una propiedad por ID
  Future<Apartment?> getPropertyById(String id) async {
    try {
      // Buscar primero en la lista local/caché
      final localProperty = _properties.where((p) => p.id == id).firstOrNull;
      if (localProperty != null) {
        return localProperty;
      }

      // Si no está en la lista local, buscar en la API
      return await _apiService.getPropertyById(id);
    } catch (e) {
      throw Exception('Error obteniendo propiedad: $e');
    }
  }

  /// Busca propiedades en la lista actual
  List<Apartment> searchProperties(String query) {
    if (query.isEmpty) return _properties;
    
    final searchTerm = query.toLowerCase();
    return _properties.where((apartment) =>
      apartment.titulo.toLowerCase().contains(searchTerm) ||
      apartment.barrio.toLowerCase().contains(searchTerm) ||
      apartment.municipio.toLowerCase().contains(searchTerm) ||
      apartment.direccion.toLowerCase().contains(searchTerm) ||
      apartment.reference.toLowerCase().contains(searchTerm)
    ).toList();
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

  /// Limpia el caché manualmente
  Future<void> clearCache() async {
    await CacheService.clearCache();
    _properties.clear();
    notifyListeners();
  }
}
