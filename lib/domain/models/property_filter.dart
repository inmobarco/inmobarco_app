class PropertyFilter {
  final int? minCuartos;
  final int? minBanos;
  final int? minGarages;
  final double? minPrecio;
  final double? maxPrecio;
  final String? municipio;
  final String? idZone;
  final String? idPropertyType;
  final double? minArea;
  final bool? forRent;
  final bool? forSale;

  PropertyFilter({
    this.minCuartos,
    this.minBanos,
    this.minPrecio,
    this.maxPrecio,
    this.municipio,
    this.idZone,
    this.idPropertyType,
    this.minArea,
    this.forRent,
    this.forSale,
    this.minGarages,
  });

  PropertyFilter copyWith({
    int? minCuartos,
    int? minBanos,
    int? minGarages,
    double? minPrecio,
    double? maxPrecio,
    String? municipio,
    String? idZone,
    String? idPropertyType,
    double? minArea,
    bool? forRent,
    bool? forSale,
    bool clearMunicipio = false,
    bool clearIdZone = false,
    bool clearIdPropertyType = false,
  }) {
    return PropertyFilter(
      minCuartos: minCuartos ?? this.minCuartos,
      minBanos: minBanos ?? this.minBanos,
      minGarages: minGarages ?? this.minGarages,
      minPrecio: minPrecio ?? this.minPrecio,
      maxPrecio: maxPrecio ?? this.maxPrecio,
      municipio: clearMunicipio ? null : (municipio ?? this.municipio),
      idZone: clearIdZone ? null : (idZone ?? this.idZone),
      idPropertyType: clearIdPropertyType ? null : (idPropertyType ?? this.idPropertyType),
      forRent: forRent ?? this.forRent,
      forSale: forSale ?? this.forSale,
      minArea: minArea ?? this.minArea,
    );
  }

  bool get hasActiveFilters {
    return minCuartos != null ||
        minBanos != null ||
        minPrecio != null ||
        maxPrecio != null ||
        municipio != null ||
        idZone != null ||
        idPropertyType != null ||
        minArea != null ||
        forRent != null ||
        forSale != null ||
        minGarages != null;
  }

  PropertyFilter clear() {
    return PropertyFilter();
  }

  Map<String, dynamic> toJson() {
    return {
      'min_cuartos': minCuartos,
      'min_banos': minBanos,
      'min_precio': minPrecio,
      'max_precio': maxPrecio,
      'municipio': municipio,
      'id_zone': idZone,
      'id_property_type': idPropertyType,
      'min_area': minArea,
      'for_rent': forRent,
      'for_sale': forSale,
      'min_garages': minGarages,
    };
  }
}
