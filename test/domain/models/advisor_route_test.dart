import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inmobarco_app/domain/models/advisor_route.dart';

void main() {
  // Respuesta tal como la arma `_get_advisor_routes`: día → rutas → conjuntos.
  final sample = [
    {
      'day_of_week': 1,
      'routes': [
        {
          'assignment_id': 10,
          'route_id': 3,
          'route_name': 'Ruta Envigado',
          'notes': 'Empezar por la zona alta',
          'priority': 1,
          'complexes': [
            {
              'complex_id': 7,
              'name': 'Torres del Parque',
              'address': 'Cra 43 #30-10',
              'latitude': 6.1701,
              'longitude': -75.5906,
              'visit_order': 1,
            },
            {
              'complex_id': 8,
              'name': 'Miravalle',
              'address': null,
              'latitude': null,
              'longitude': null,
              'visit_order': null,
            },
          ],
        },
      ],
    },
    {
      'day_of_week': 4,
      'routes': [
        {
          'assignment_id': 11,
          'route_id': 5,
          'route_name': 'Ruta Sabaneta',
          'notes': null,
          'priority': 2,
          'complexes': <Map<String, dynamic>>[],
        },
      ],
    },
  ];

  group('AdvisorRouteDay.listFromJson', () {
    test('parses days, routes and complexes', () {
      final days = AdvisorRouteDay.listFromJson(sample);

      expect(days, hasLength(2));
      expect(days.first.dayOfWeek, 1);

      final route = days.first.routes.single;
      expect(route.assignmentId, 10);
      expect(route.routeId, 3);
      expect(route.name, 'Ruta Envigado');
      expect(route.notes, 'Empezar por la zona alta');
      expect(route.priority, 1);
      expect(route.complexes, hasLength(2));

      final first = route.complexes.first;
      expect(first.complexId, 7);
      expect(first.name, 'Torres del Parque');
      expect(first.address, 'Cra 43 #30-10');
      expect(first.latitude, 6.1701);
      expect(first.longitude, -75.5906);
      expect(first.visitOrder, 1);
    });

    test('preserves the order the backend sent', () {
      final days = AdvisorRouteDay.listFromJson(sample);

      expect(days.map((d) => d.dayOfWeek), [1, 4]);
      expect(
        days.first.routes.single.complexes.map((c) => c.name),
        ['Torres del Parque', 'Miravalle'],
      );
    });

    test('nulls become null, not empty strings or zeros', () {
      final complex =
          AdvisorRouteDay.listFromJson(sample).first.routes.single.complexes[1];

      expect(complex.address, isNull);
      expect(complex.latitude, isNull);
      expect(complex.longitude, isNull);
      expect(complex.visitOrder, isNull);
    });

    test('a route with no complexes parses as an empty list', () {
      final route = AdvisorRouteDay.listFromJson(sample)[1].routes.single;

      expect(route.notes, isNull);
      expect(route.complexes, isEmpty);
    });

    test('an empty response (Sunday) yields no days', () {
      expect(AdvisorRouteDay.listFromJson(const []), isEmpty);
    });

    test('survives a round trip through the JSON cache', () {
      final decoded = jsonDecode(jsonEncode(sample)) as List<dynamic>;
      final days = AdvisorRouteDay.listFromJson(decoded);

      expect(days, hasLength(2));
      expect(days.first.routes.single.complexes.first.latitude, 6.1701);
    });

    test('tolerates numeric fields sent as strings', () {
      // Postgres `numeric` puede llegar serializado como string.
      final days = AdvisorRouteDay.listFromJson([
        {
          'day_of_week': '2',
          'routes': [
            {
              'assignment_id': '99',
              'route_id': '4',
              'route_name': 'Ruta Itagüí',
              'priority': '1',
              'complexes': [
                {
                  'complex_id': '12',
                  'name': 'La Colina',
                  'latitude': '6.1720',
                  'longitude': '-75.6100',
                  'visit_order': '2',
                },
              ],
            },
          ],
        },
      ]);

      final complex = days.single.routes.single.complexes.single;
      expect(days.single.dayOfWeek, 2);
      expect(days.single.routes.single.assignmentId, 99);
      expect(complex.complexId, 12);
      expect(complex.latitude, 6.1720);
      expect(complex.visitOrder, 2);
    });

    test('missing route name falls back to a placeholder', () {
      final days = AdvisorRouteDay.listFromJson([
        {
          'day_of_week': 3,
          'routes': [
            {'complexes': <Map<String, dynamic>>[]},
          ],
        },
      ]);

      expect(days.single.routes.single.name, 'Ruta sin nombre');
      expect(days.single.routes.single.routeId, isNull);
    });
  });
}
