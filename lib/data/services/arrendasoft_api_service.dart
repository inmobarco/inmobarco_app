import 'package:dio/dio.dart';
import '../../domain/models/apartment.dart';
import '../../domain/models/property_filter.dart';
import '../../core/constants/app_constants.dart';

class ArrendasoftApiService {
  final Dio _dio;
  final String apiKey;

  ArrendasoftApiService({required this.apiKey}) : _dio = Dio() {
    _dio.options.baseUrl = AppConstants.arrendasoftApiBaseUrl;
    _dio.options.headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Interceptor para logging (opcional)
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('[API] $obj'),
      ),
    );
  }

  /// Obtiene la lista de propiedades activas
  Future<List<Apartment>> getActiveProperties({
    PropertyFilter? filter,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      // Aplicar filtros si existen
      if (filter != null) {
        // No agregamos filtros específicos aquí porque la API de Arrendasoft 
        // no soporta filtros por cuartos/baños en la URL
        // Los filtros se aplicarán después de recibir los datos
      }

      final response = await _dio.get('/properties', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final List<dynamic> properties = response.data is List 
            ? response.data 
            : (response.data['data'] ?? response.data['properties'] ?? []);
        
        List<Apartment> apartments = properties
            .map((json) => Apartment.fromJson(json))
            .where((apartment) => 
                apartment.estadoTexto.toLowerCase() == 'activa' &&
                apartment.tipoServicio.toLowerCase().contains('arriendo'))
            .toList();

        // Aplicar filtros localmente
        if (filter != null) {
          apartments = _applyLocalFilters(apartments, filter);
        }
        
        return apartments;
      } else {
        throw Exception('Error al obtener propiedades: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene una propiedad específica por ID
  Future<Apartment> getPropertyById(String id) async {
    try {
      final response = await _dio.get('/properties/$id');
      
      if (response.statusCode == 200) {
        final data = response.data;
        return Apartment.fromJson(data['data'] ?? data);
      } else {
        throw Exception('Error al obtener propiedad: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene la lista de municipios disponibles
  Future<List<String>> getMunicipios() async {
    try {
      final response = await _dio.get('/municipios');
      
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> municipios = data['data'] ?? data['municipios'] ?? [];
        
        return municipios.map((item) => item.toString()).toList();
      } else {
        return [];
      }
    } catch (e) {
      // Si no existe el endpoint, devolvemos lista vacía
      return [];
    }
  }

  /// Obtiene la lista de estratos disponibles
  Future<List<String>> getEstratos() async {
    try {
      final response = await _dio.get('/estratos');
      
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> estratos = data['data'] ?? data['estratos'] ?? [];
        
        return estratos.map((item) => item.toString()).toList();
      } else {
        return ['1', '2', '3', '4', '5', '6']; // Estratos por defecto
      }
    } catch (e) {
      // Si no existe el endpoint, devolvemos estratos por defecto
      return ['1', '2', '3', '4', '5', '6'];
    }
  }

  /// Aplica filtros localmente a la lista de apartamentos
  List<Apartment> _applyLocalFilters(List<Apartment> apartments, PropertyFilter filter) {
    return apartments.where((apartment) {
      // Filtro por cuartos
      if (filter.minCuartos != null && apartment.cuartos < filter.minCuartos!) {
        return false;
      }
      if (filter.maxCuartos != null && apartment.cuartos > filter.maxCuartos!) {
        return false;
      }

      // Filtro por baños
      if (filter.minBanos != null && apartment.banos < filter.minBanos!) {
        return false;
      }
      if (filter.maxBanos != null && apartment.banos > filter.maxBanos!) {
        return false;
      }

      // Filtro por precio
      if (filter.minPrecio != null && apartment.precio < filter.minPrecio!) {
        return false;
      }
      if (filter.maxPrecio != null && apartment.precio > filter.maxPrecio!) {
        return false;
      }

      // Filtro por municipio
      if (filter.municipio != null && 
          filter.municipio!.isNotEmpty && 
          !apartment.municipio.toLowerCase().contains(filter.municipio!.toLowerCase())) {
        return false;
      }

      // Filtro por estrato
      if (filter.estrato != null && 
          filter.estrato!.isNotEmpty && 
          apartment.estratoTexto.toLowerCase() != filter.estrato!.toLowerCase()) {
        return false;
      }

      // Filtro por área
      if (filter.minArea != null && apartment.area < filter.minArea!) {
        return false;
      }
      if (filter.maxArea != null && apartment.area > filter.maxArea!) {
        return false;
      }

      return true;
    }).toList();
  }
}
