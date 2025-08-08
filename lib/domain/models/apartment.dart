class Apartment {
  final String id;
  final String codigo;
  final String titulo;
  final double precio;
  final int cuartos;
  final int banos;
  final String barrio;
  final String municipio;
  final String estrato;
  final String estratoTexto;
  final double area;
  final String estado;
  final String estadoTexto;
  final List<String> imagenes;
  final String descripcion;
  final String direccion;
  final String claseInmueble;
  final String tipoServicio;
  final String asesor;
  final String departamento;
  final String coordenadas;
  final List<Map<String, dynamic>> caracteristicas;

  Apartment({
    required this.id,
    required this.codigo,
    required this.titulo,
    required this.precio,
    required this.cuartos,
    required this.banos,
    required this.barrio,
    required this.municipio,
    required this.estrato,
    required this.estratoTexto,
    required this.area,
    required this.estado,
    required this.estadoTexto,
    required this.imagenes,
    required this.descripcion,
    required this.direccion,
    required this.claseInmueble,
    required this.tipoServicio,
    required this.asesor,
    required this.departamento,
    required this.coordenadas,
    required this.caracteristicas,
  });

  factory Apartment.fromJson(Map<String, dynamic> json) {
    // Extraer cuartos y baños de las características
    final caracteristicasList = (json['caracteristicas'] as List<dynamic>?) ?? [];
    int cuartos = 0;
    int banos = 0;
    
    for (var caracteristica in caracteristicasList) {
      final descripcion = caracteristica['descripcion']?.toString().toLowerCase() ?? '';
      final valor = caracteristica['valor']?.toString() ?? '';
      
      if (descripcion.contains('habitacion') || descripcion.contains('cuartos')) {
        cuartos = int.tryParse(valor) ?? 0;
      } else if (descripcion.contains('baño') || descripcion.contains('banos')) {
        banos = int.tryParse(valor) ?? 0;
      }
    }

    // Extraer imágenes
    final imagenesList = (json['imagenes'] as List<dynamic>?) ?? [];
    final imagenesUrls = imagenesList
        .map((img) => img['imagen']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();

    // Determinar precio según tipo de servicio
    double precioFinal = 0;
    final tipoServicio = json['tipo_servicio']?.toString().toLowerCase() ?? '';
    if (tipoServicio.contains('arriendo')) {
      precioFinal = _parseDouble(json['valor_arriendo1']);
    } else if (tipoServicio.contains('venta')) {
      precioFinal = _parseDouble(json['valor_venta1']);
    }

    return Apartment(
      id: json['codigo']?.toString() ?? '',
      codigo: json['codigo']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? '',
      precio: precioFinal,
      cuartos: cuartos,
      banos: banos,
      barrio: json['barrio']?.toString() ?? '',
      municipio: json['municipio']?.toString() ?? '',
      estrato: json['estrato']?.toString() ?? '',
      estratoTexto: json['estrato_texto']?.toString() ?? '',
      area: _parseDouble(json['area']),
      estado: json['estado']?.toString() ?? '',
      estadoTexto: json['estado_texto']?.toString() ?? '',
      imagenes: imagenesUrls,
      descripcion: json['observaciones']?.toString() ?? json['titulo']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      claseInmueble: json['clase_inmueble']?.toString() ?? '',
      tipoServicio: json['tipo_servicio']?.toString() ?? '',
      asesor: json['asesor']?.toString() ?? '',
      departamento: json['departamento']?.toString() ?? '',
      coordenadas: json['coordenadas']?.toString() ?? '',
      caracteristicas: caracteristicasList.cast<Map<String, dynamic>>(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
    }
    return 0.0;
  }

  String get priceFormatted {
    return '\$${precio.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  String get ubicacion => '$barrio, $municipio';

  String get primaryImage => imagenes.isNotEmpty ? imagenes.first : '';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'titulo': titulo,
      'precio': precio,
      'cuartos': cuartos,
      'banos': banos,
      'barrio': barrio,
      'municipio': municipio,
      'estrato': estrato,
      'estrato_texto': estratoTexto,
      'area': area,
      'estado': estado,
      'estado_texto': estadoTexto,
      'imagenes': imagenes,
      'descripcion': descripcion,
      'direccion': direccion,
      'clase_inmueble': claseInmueble,
      'tipo_servicio': tipoServicio,
      'asesor': asesor,
      'departamento': departamento,
      'coordenadas': coordenadas,
      'caracteristicas': caracteristicas,
    };
  }
}
