class PropertyFilter {
  final int? minCuartos;
  final int? maxCuartos;
  final int? minBanos;
  final int? maxBanos;
  final double? minPrecio;
  final double? maxPrecio;
  final String? municipio;
  final String? estrato;
  final double? minArea;
  final double? maxArea;

  PropertyFilter({
    this.minCuartos,
    this.maxCuartos,
    this.minBanos,
    this.maxBanos,
    this.minPrecio,
    this.maxPrecio,
    this.municipio,
    this.estrato,
    this.minArea,
    this.maxArea,
  });

  PropertyFilter copyWith({
    int? minCuartos,
    int? maxCuartos,
    int? minBanos,
    int? maxBanos,
    double? minPrecio,
    double? maxPrecio,
    String? municipio,
    String? estrato,
    double? minArea,
    double? maxArea,
    bool clearMunicipio = false,
    bool clearEstrato = false,
  }) {
    return PropertyFilter(
      minCuartos: minCuartos ?? this.minCuartos,
      maxCuartos: maxCuartos ?? this.maxCuartos,
      minBanos: minBanos ?? this.minBanos,
      maxBanos: maxBanos ?? this.maxBanos,
      minPrecio: minPrecio ?? this.minPrecio,
      maxPrecio: maxPrecio ?? this.maxPrecio,
      municipio: clearMunicipio ? null : (municipio ?? this.municipio),
      estrato: clearEstrato ? null : (estrato ?? this.estrato),
      minArea: minArea ?? this.minArea,
      maxArea: maxArea ?? this.maxArea,
    );
  }

  bool get hasActiveFilters {
    return minCuartos != null ||
        maxCuartos != null ||
        minBanos != null ||
        maxBanos != null ||
        minPrecio != null ||
        maxPrecio != null ||
        municipio != null ||
        estrato != null ||
        minArea != null ||
        maxArea != null;
  }

  PropertyFilter clear() {
    return PropertyFilter();
  }

  Map<String, dynamic> toJson() {
    return {
      'min_cuartos': minCuartos,
      'max_cuartos': maxCuartos,
      'min_banos': minBanos,
      'max_banos': maxBanos,
      'min_precio': minPrecio,
      'max_precio': maxPrecio,
      'municipio': municipio,
      'estrato': estrato,
      'min_area': minArea,
      'max_area': maxArea,
    };
  }
}
