import 'package:flutter/foundation.dart';
import '../../domain/models/apartment.dart';
import '../../domain/models/property_filter.dart';
import '../../data/services/arrendasoft_api_service.dart';

class PropertyProvider extends ChangeNotifier {
  final ArrendasoftApiService _apiService;
  
  List<Apartment> _properties = [];
  List<String> _municipios = [];
  List<String> _estratos = [];
  PropertyFilter _currentFilter = PropertyFilter();
  bool _isLoading = false;
  String? _error;
  bool _hasMoreData = true;
  int _currentPage = 1;

  PropertyProvider({required ArrendasoftApiService apiService}) 
      : _apiService = apiService;

  // Getters
  List<Apartment> get properties => _properties;
  List<String> get municipios => _municipios;
  List<String> get estratos => _estratos;
  PropertyFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;
  bool get hasActiveFilters => _currentFilter.hasActiveFilters;

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

      if (newProperties.isEmpty || newProperties.length < 20) {
        _hasMoreData = false;
      } else {
        _currentPage++;
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
    await loadProperties(refresh: true);
  }

  /// Limpia los filtros
  Future<void> clearFilters() async {
    _currentFilter = PropertyFilter();
    await loadProperties(refresh: true);
  }

  /// Carga los municipios disponibles
  Future<void> loadMunicipios() async {
    try {
      _municipios = await _apiService.getMunicipios();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading municipios: $e');
    }
  }

  /// Carga los estratos disponibles
  Future<void> loadEstratos() async {
    try {
      _estratos = await _apiService.getEstratos();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading estratos: $e');
    }
  }

  /// Obtiene una propiedad por ID
  Future<Apartment?> getPropertyById(String id) async {
    try {
      return await _apiService.getPropertyById(id);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Busca propiedades en la lista actual
  List<Apartment> searchProperties(String query) {
    if (query.isEmpty) return _properties;
    
    final lowercaseQuery = query.toLowerCase();
    return _properties.where((property) {
      return property.titulo.toLowerCase().contains(lowercaseQuery) ||
             property.barrio.toLowerCase().contains(lowercaseQuery) ||
             property.municipio.toLowerCase().contains(lowercaseQuery) ||
             property.codigo.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Refresca todos los datos
  Future<void> refresh() async {
    await Future.wait([
      loadProperties(refresh: true),
      loadMunicipios(),
      loadEstratos(),
    ]);
  }
}
