import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../domain/models/apartment.dart';
import '../../domain/models/property_filter.dart';
import '../../core/constants/app_constants.dart';

class WasiApiService {
  final Dio _dio;
  final String apiToken;
  final String companyId;

  WasiApiService({
    required this.apiToken,
    required this.companyId,
  }) : _dio = Dio() {
    _dio.options.baseUrl = AppConstants.wasiApiBaseUrl;
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Interceptor para logging (opcional)
    /*_dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('[WASI API] $obj'),
      ),
    );*/
  }

  /// Obtiene la lista de propiedades activas
  Future<List<Apartment>> getActiveProperties({
    PropertyFilter? filter,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'wasi_token': apiToken,
        'id_company': companyId,
        //'for_sale': true, // Solo propiedades en venta
        'id_availability': '1', // Solo disponibles
        'scope': '1', // Solo propiedades propias
        'short': true, 
        'skip': (page - 1) * limit,
        'take': limit,
        'order': 'desc',
        'order_by': 'id_property',
      };

      // Aplicar filtros si existen
      if (filter != null) {
        _applyApiFilters(queryParams, filter);
      }

  final response = await _dio.get('/property/search', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        debugPrint(response.realUri.toString());
        if (responseData['status'] != 'success') {
          throw Exception('Error en respuesta de WASI: ${responseData['status']}');
        }


        // Obtener las propiedades del response
        List<dynamic> properties = [];
        responseData.forEach((key, value) {
          if (key != 'status' && key != 'total' && value is Map<String, dynamic>) {
            properties.add(value);
          }
        });
        
        List<Apartment> apartments = properties
            .map((json) => _mapWasiToApartment(json))
            .where((apartment) => apartment.id.isNotEmpty)
            .toList();
        
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
      final queryParams = <String, dynamic>{
        'wasi_token': apiToken,
        'id_company': companyId,
        'short': 'false', // Incluir galerías y características
      };

      final response = await _dio.get('/property/get/$id', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['status'] != 'success') {
          throw Exception('Error en respuesta de WASI: ${data['status']}');
        }
        
        return _mapWasiToApartment(data);
      } else {
        throw Exception('Error al obtener propiedad: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene la lista de ciudades para Antioquia (ID: 2)
  Future<List<Map<String, dynamic>>> getCities() async {
    try {
      final queryParams = <String, dynamic>{
        'wasi_token': apiToken,
        'id_company': companyId
      };
      //'id_region': 2, // Antioquia
      final response = await _dio.get('/location/cities-from-region/2', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'success') {
          List<Map<String, dynamic>> cities = [];
          data.forEach((key, value) {
            if (key != 'status' && value is Map<String, dynamic>) {
              cities.add({
                'id': value['id_city']?.toString() ?? '',
                'name': value['name']?.toString() ?? '',
              });
            }
          });
          final sanitized = cities
              .where((city) => (city['name'] as String).isNotEmpty)
              .toList();
          return AppConstants.filterAllowedCities(sanitized);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo ciudades: $e');
      return [];
    }
  }

  /// Obtiene la lista completa de características disponibles en WASI
  Future<List<Map<String, dynamic>>> getFeatures() async {
    try {
      final queryParams = <String, dynamic>{
        'wasi_token': apiToken,
        'id_company': companyId,
      };

      final response = await _dio.get('/feature/all', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          final List<Map<String, dynamic>> features = [];

          data.forEach((key, value) {
            if (key == 'status') return;

            if (value is List) {
              for (final item in value) {
                if (item is Map<String, dynamic>) {
                  final id = item['id_feature'] ?? item['id'] ?? item['id_feature_type'];
                  final dynamic rawName = item['nombre'] ?? item['name'] ?? item['label'];
                  final name = (rawName ?? '').toString().trim();
                  if (name.isEmpty) continue;

                  final category = (item['type'] ?? key).toString().toLowerCase();
                  features.add({
                    'id': (id ?? '').toString(),
                    'name': name,
                    'category': category,
                    'own': item['own'] ?? false,
                    'raw': item,
                  });
                }
              }
            } else if (value is Map<String, dynamic>) {
              final id = value['id_feature'] ?? value['id'] ?? value['id_feature_type'];
              final dynamic rawName = value['nombre'] ?? value['name'] ?? value['label'];
              final name = (rawName ?? '').toString().trim();
              if (name.isEmpty) return;

              final category = (value['type'] ?? key).toString().toLowerCase();
              features.add({
                'id': (id ?? '').toString(),
                'name': name,
                'category': category,
                'own': value['own'] ?? false,
                'raw': value,
              });
            }
          });

          return features;
        }
      }

      return [];
    } catch (e) {
      debugPrint('Error obteniendo características: $e');
      return [];
    }
  }

  /// Obtiene la lista de zonas (barrios) para una ciudad específica
  Future<List<Map<String, dynamic>>> getZonesByCity(String cityId) async {
    try {
      if (cityId.isEmpty) return [];
      final queryParams = <String, dynamic>{
        'wasi_token': apiToken,
        'id_company': companyId,
      };
      final response = await _dio.get('/location/zones-from-city/$cityId', queryParameters: queryParams);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'success') {
          List<Map<String, dynamic>> zones = [];
          data.forEach((key, value) {
            if (key != 'status' && value is Map<String, dynamic>) {
              zones.add({
                'id': value['id_zone']?.toString() ?? '',
                'name': value['name']?.toString() ?? '',
              });
            }
          });
          return zones.where((z) => z['name'].isNotEmpty).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo zonas para ciudad $cityId: $e');
      return [];
    }
  }

  /// Aplica filtros a los parámetros de la API
  void _applyApiFilters(Map<String, dynamic> queryParams, PropertyFilter filter) {
    // Filtro por cuartos
    if (filter.minCuartos != null) {
      queryParams['min_bedrooms'] = filter.minCuartos;
    }

    // Filtro por baños
    if (filter.minBanos != null) {
      queryParams['bathrooms'] = filter.minBanos;
    }

    // Filtro por garajes
    if (filter.minGarages != null) {
      queryParams['garages'] = filter.minGarages;
    }

    // Filtro por precio
    if (filter.minPrecio != null) {
      queryParams['min_price'] = filter.minPrecio!.toInt();
    }
    if (filter.maxPrecio != null) {
      queryParams['max_price'] = filter.maxPrecio!.toInt();
    }

    // Filtro por área
    if (filter.minArea != null) {
      queryParams['min_area'] = filter.minArea!.toInt();
    }

    if (filter.municipio != null && filter.municipio!.isNotEmpty) {
      String? id = AppConstants.cities.firstWhere(
        (city) => city['name'] == filter.municipio,
        orElse: () => {'id': null},
      )['id']?.toString();
      queryParams['id_city'] = id;
    }

    if (filter.forRent != null) {
      queryParams['for_rent'] = filter.forRent;
    }

    if (filter.forSale != null) {
      queryParams['for_sale'] = filter.forSale;
    }
  }

  /// Limpia el HTML de la descripción
  String _cleanHtmlDescription(String? htmlText) {
    if (htmlText == null || htmlText.isEmpty) {
      return 'Hermoso apartamento disponible para arriendo';
    }

    String cleanText = htmlText;
    // Remover etiquetas HTML comunes
    cleanText = cleanText.replaceAll(RegExp(r'<[^>]*>'), '');
    
    
    // Decodificar entidades HTML
    cleanText = cleanText
        .replaceAll('&ntilde;', 'ñ')
        .replaceAll('&aacute;', 'á')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&iacute;', 'í')
        .replaceAll('&oacute;', 'ó')
        .replaceAll('&uacute;', 'ú')
        .replaceAll('&Aacute;', 'Á')
        .replaceAll('&Eacute;', 'É')
        .replaceAll('&Iacute;', 'Í')
        .replaceAll('&Oacute;', 'Ó')
        .replaceAll('&Uacute;', 'Ú')
        .replaceAll('&ccedil;', 'ç')
        .replaceAll('&Ccedil;', 'Ç')
        .replaceAll('&uuml;', 'ü')
        .replaceAll('&Uuml;', 'Ü')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    
    // Limpiar múltiples espacios y saltos de línea
    cleanText = cleanText
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n')  // Múltiples saltos de línea
        //.replaceAll(RegExp(r'\s+'), ' ')          // Múltiples espacios
        .trim();
        
    // Convertir guiones al inicio de línea en viñetas más legibles
    cleanText = cleanText
        .replaceAll(RegExp(r'^-', multiLine: true), '• ')
        .replaceAll(RegExp(r'\n-'), '\n• ');

    // Si está vacío después de la limpieza, devolver descripción por defecto
    if (cleanText.isEmpty) {
      return 'Hermoso apartamento disponible para arriendo';
    }

    return cleanText;
  }

  /// Mapea los datos de WASI al modelo Apartment
  Apartment _mapWasiToApartment(Map<String, dynamic> json) {
    try {
      // Extraer imágenes de las galerías
      List<String> imagenes = [];
      
      // Imagen principal
      if (json['main_image'] != null) {
        final mainImage = json['main_image']['url_big'] ??
                         json['main_image']['url_medium'] ??
                         json['main_image']['url'] ??
                         json['main_image']['url_original'];
        if (mainImage != null) {
          imagenes.add(mainImage.toString());
        }
      }

      // Imágenes de galerías
      if (json['galleries'] != null && json['galleries'] is List) {
        for (var gallery in json['galleries']) {
          if (gallery is Map<String, dynamic>) {
            gallery.forEach((key, value) {
              if (key != 'id' && value is Map<String, dynamic>) {
                final imageUrl = value['url_big'] ??
                               value['url_medium'] ??
                               value['url'] ??
                               value['url_original'];
                if (imageUrl != null && !imagenes.contains(imageUrl.toString())) {
                  imagenes.add(imageUrl.toString());
                }
              }
            });
          }
        }
      }

      // Extraer características
      List<Map<String, dynamic>> caracteristicas = [];
      if (json['features'] != null) {
        final features = json['features'];
        if (features['internal'] != null) {
          for (var feature in features['internal']) {
            caracteristicas.add({
              'descripcion': feature['nombre'] ?? feature['name'] ?? '',
              'valor': 'Si',
              'tipo': 'internal'
            });
          }
        }
        if (features['external'] != null) {
          for (var feature in features['external']) {
            caracteristicas.add({
              'descripcion': feature['nombre'] ?? feature['name'] ?? '',
              'valor': 'Si',
              'tipo': 'external'
            });
          }
        }
      }

      // Construir ubicación
      final ciudad = json['city_label']?.toString() ?? '';
      final region = json['region_label']?.toString() ?? '';
      final zona = json['zone_label']?.toString() ?? '';
      
      String barrio = zona.isNotEmpty ? zona : 'Centro';
      String municipio = ciudad.isNotEmpty ? ciudad : region;
      
      // Precio de arriendo
      double rentPrice = _parseDouble(json['rent_price']);
      // Precio de venta
      double salePrice = _parseDouble(json['sale_price']);

      // Coordenadas
      String coordenadas = '';
      if (json['latitude'] != null && json['longitude'] != null) {
        coordenadas = '${json['latitude']},${json['longitude']}';
      } else if (json['map'] != null) {
        coordenadas = json['map'].toString();
      }
      return Apartment(
        id: json['id_property']?.toString() ?? '',
        titulo: json['title']?.toString() ?? 'Propiedad sin título',
        reference: json['registration_number']?.toString() ?? 'Sin numero de apto',
        rentPrice: rentPrice,
        salePrice: salePrice,
        cuartos: int.tryParse(json['bedrooms']?.toString() ?? '0') ?? 0,
        banos: int.tryParse(json['bathrooms']?.toString() ?? '0') ?? 0,
        barrio: barrio,
        municipio: municipio,
        estrato: int.tryParse(json['stratum']?.toString() ?? '0') ?? 0,
        area: _parseDouble(json['area']),
        estado: '1',
        estadoTexto: 'Activa',
        imagenes: imagenes,
        descripcion: _cleanHtmlDescription(json['observations']?.toString()),
        direccion: json['address']?.toString() ?? '',
        claseInmueble: json['property_type_label']?.toString() ?? 'Apartamento',
        asesor: '', // WASI puede tener esta info en otro endpoint
        departamento: region,
        coordenadas: coordenadas,
        caracteristicas: caracteristicas,
      );
    } catch (e) {
      debugPrint('Error mapeando propiedad de WASI: $e');
      debugPrint('JSON: $json');
      
      // Retornar un apartamento básico en caso de error
      return Apartment(
        id: json['id_property']?.toString() ?? '',
        titulo: json['title']?.toString() ?? 'Error al cargar propiedad',
        reference: json['registration_number']?.toString() ?? '',
        rentPrice: 0,
        salePrice: 0,
        cuartos: 0,
        banos: 0,
        barrio: '',
        municipio: '',
        estrato: 1,
        area: 0,
        estado: '1',
        estadoTexto: 'Activa',
        imagenes: [],
        descripcion: '',
        direccion: '',
        claseInmueble: '',
        asesor: '',
        departamento: '',
        coordenadas: '',
        caracteristicas: [],
      );
    }
  }

  /// Helper para parsear valores numéricos
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Remover caracteres no numéricos excepto punto y coma
      final cleanValue = value.replaceAll(RegExp(r'[^\d.,]'), '');
      return double.tryParse(cleanValue.replaceAll(',', '')) ?? 0.0;
    }
    return 0.0;
  }
}
