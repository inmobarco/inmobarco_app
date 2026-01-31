class Apartment {
  final String id;
  final String titulo;
  final String reference;
  final double rentPrice;
  final double salePrice;
  final int cuartos;
  final int banos;
  final String barrio;
  final String municipio;
  final int estrato;
  final double area;
  final String estado;
  final String estadoTexto;
  final List<String> imagenes;
  final String descripcion;
  final String direccion;
  final String claseInmueble;
  final String asesor;
  final String departamento;
  final String coordenadas;
  final List<Map<String, dynamic>> caracteristicas;

  Apartment({
    required this.id,
    required this.titulo,
    required this.reference,
    required this.rentPrice,
    required this.salePrice,
    required this.cuartos,
    required this.banos,
    required this.barrio,
    required this.municipio,
    required this.estrato,
    required this.area,
    required this.estado,
    required this.estadoTexto,
    required this.imagenes,
    required this.descripcion,
    required this.direccion,
    required this.claseInmueble,
    required this.asesor,
    required this.departamento,
    required this.coordenadas,
    required this.caracteristicas,
  });

  factory Apartment.fromJson(Map<String, dynamic> json) {
    // Data desde caché (formato simplificado con claves en camelCase)
    return Apartment(
      id: json['id']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      rentPrice: (json['rentPrice'] ?? 0).toDouble(),
      salePrice: (json['salePrice'] ?? 0).toDouble(),
      cuartos: json['cuartos'] ?? 0,
      banos: json['banos'] ?? 0,
      barrio: json['barrio']?.toString() ?? '',
      municipio: json['municipio']?.toString() ?? '',
      estrato: json['estrato'] ?? 0,
      area: (json['area'] ?? 0).toDouble(),
      estado: json['estado']?.toString() ?? '1',
      estadoTexto: json['estado_texto']?.toString() ?? 'Activa',
      imagenes: List<String>.from(json['imagenes'] ?? []),
      descripcion: json['descripcion']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      claseInmueble: json['clase_inmueble']?.toString() ?? '',
      asesor: json['asesor']?.toString() ?? '',
      departamento: json['departamento']?.toString() ?? '',
      coordenadas: json['coordenadas']?.toString() ?? '',
      caracteristicas: List<Map<String, dynamic>>.from(
        json['caracteristicas']?.map((x) => Map<String, dynamic>.from(x)) ?? []
      ),
    );
  }

  String get priceFormatted {
    String formatedRent = '\$${rentPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
    String formatedSale = '\$${salePrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
    if (rentPrice > 0 && salePrice > 0) {
      return '$formatedRent / $formatedSale';
    }
    if (rentPrice > 0) {
      return formatedRent;
    }
    if (salePrice > 0) {
      return formatedSale;
    }
    return '';
  }

  String get ubicacion => '$barrio, $municipio';

  String get primaryImage => imagenes.isNotEmpty ? imagenes.first : '';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'reference': reference,
      'rentPrice': rentPrice,
      'salePrice': salePrice,
      'cuartos': cuartos,
      'banos': banos,
      'barrio': barrio,
      'municipio': municipio,
      'estrato': estrato,
      'area': area,
      'estado': estado,
      'estado_texto': estadoTexto,
      'imagenes': imagenes,
      'descripcion': descripcion,
      'direccion': direccion,
      'clase_inmueble': claseInmueble,
      'asesor': asesor,
      'departamento': departamento,
      'coordenadas': coordenadas,
      'caracteristicas': caracteristicas,
    };
  }
}
