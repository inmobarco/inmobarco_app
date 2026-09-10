/// Rutas de prospección del asesor (`GET /scheduling/routes`).
///
/// El backend agrupa día → rutas → conjuntos y ya entrega todo ordenado
/// (`day_of_week`, `priority`, `visit_order`), así que aquí solo se mapea:
/// nada se reordena para no perder el criterio del servidor.
///
/// Es una vista de solo lectura: la app no crea, edita ni borra rutas. Eso
/// vive en el panel de staff.
library;

/// Un conjunto residencial dentro de una ruta.
class RouteComplex {
  const RouteComplex({
    this.complexId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.visitOrder,
  });

  final int? complexId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  /// Posición dentro de la ruta. El backend permite null (`NULLS LAST`).
  final int? visitOrder;

  factory RouteComplex.fromJson(Map<String, dynamic> json) => RouteComplex(
        complexId: _asInt(json['complex_id']),
        name: json['name']?.toString() ?? '',
        address: _asText(json['address']),
        latitude: _asDouble(json['latitude']),
        longitude: _asDouble(json['longitude']),
        visitOrder: _asInt(json['visit_order']),
      );
}

/// Una ruta asignada al asesor para un día concreto.
class AdvisorRoute {
  const AdvisorRoute({
    this.assignmentId,
    this.routeId,
    required this.name,
    this.notes,
    this.priority,
    required this.complexes,
  });

  /// Id de la asignación (asesor + ruta + día). Es la clave con la que el
  /// backend agrupa: una misma ruta puede estar asignada varios días.
  final int? assignmentId;
  final int? routeId;
  final String name;
  final String? notes;
  final int? priority;
  final List<RouteComplex> complexes;

  factory AdvisorRoute.fromJson(Map<String, dynamic> json) => AdvisorRoute(
        assignmentId: _asInt(json['assignment_id']),
        routeId: _asInt(json['route_id']),
        name: json['route_name']?.toString() ?? 'Ruta sin nombre',
        notes: _asText(json['notes']),
        priority: _asInt(json['priority']),
        complexes: _asMapList(json['complexes'])
            .map(RouteComplex.fromJson)
            .toList(),
      );
}

/// Las rutas del asesor para un día de la semana (ISODOW: 1 = lunes).
class AdvisorRouteDay {
  const AdvisorRouteDay({required this.dayOfWeek, required this.routes});

  final int dayOfWeek;
  final List<AdvisorRoute> routes;

  factory AdvisorRouteDay.fromJson(Map<String, dynamic> json) => AdvisorRouteDay(
        dayOfWeek: _asInt(json['day_of_week']) ?? 0,
        routes: _asMapList(json['routes']).map(AdvisorRoute.fromJson).toList(),
      );

  /// Parsea la respuesta completa del endpoint.
  static List<AdvisorRouteDay> listFromJson(List<dynamic> data) => data
      .whereType<Map>()
      .map((e) => AdvisorRouteDay.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

/// `numeric` de Postgres puede llegar como número o como string.
double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _asText(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
