import 'package:flutter_test/flutter_test.dart';
import 'package:inmobarco_app/domain/models/property_filter.dart';

void main() {
  group('PropertyFilter.hasActiveFilters', () {
    test('returns false for default filter', () {
      final filter = PropertyFilter();
      expect(filter.hasActiveFilters, isFalse);
    });

    test('returns true when any field is set', () {
      expect(PropertyFilter(minCuartos: 2).hasActiveFilters, isTrue);
      expect(PropertyFilter(minBanos: 1).hasActiveFilters, isTrue);
      expect(PropertyFilter(minGarages: 1).hasActiveFilters, isTrue);
      expect(PropertyFilter(minPrecio: 100000).hasActiveFilters, isTrue);
      expect(PropertyFilter(maxPrecio: 500000).hasActiveFilters, isTrue);
      expect(PropertyFilter(municipio: 'Medellín').hasActiveFilters, isTrue);
      expect(PropertyFilter(minArea: 50).hasActiveFilters, isTrue);
      expect(PropertyFilter(forRent: true).hasActiveFilters, isTrue);
      expect(PropertyFilter(forSale: true).hasActiveFilters, isTrue);
    });
  });

  group('PropertyFilter.copyWith', () {
    test('changes specified fields', () {
      final filter = PropertyFilter(minCuartos: 2, municipio: 'Medellín');
      final copy = filter.copyWith(minCuartos: 3, minBanos: 1);

      expect(copy.minCuartos, 3);
      expect(copy.minBanos, 1);
      expect(copy.municipio, 'Medellín'); // preserved
    });

    test('clearMunicipio sets municipio to null', () {
      final filter = PropertyFilter(municipio: 'Envigado');
      final copy = filter.copyWith(clearMunicipio: true);

      expect(copy.municipio, isNull);
    });

    test('clearMunicipio overrides provided municipio', () {
      final filter = PropertyFilter(municipio: 'Envigado');
      final copy = filter.copyWith(municipio: 'Medellín', clearMunicipio: true);

      expect(copy.municipio, isNull);
    });
  });

  group('PropertyFilter.clear', () {
    test('returns filter with no active filters', () {
      final filter = PropertyFilter(
        minCuartos: 3,
        minBanos: 2,
        municipio: 'Medellín',
        minPrecio: 100000,
      );
      final cleared = filter.clear();

      expect(cleared.hasActiveFilters, isFalse);
      expect(cleared.minCuartos, isNull);
      expect(cleared.minBanos, isNull);
      expect(cleared.municipio, isNull);
      expect(cleared.minPrecio, isNull);
    });
  });

  group('PropertyFilter.toJson', () {
    test('serializes all fields', () {
      final filter = PropertyFilter(
        minCuartos: 2,
        minBanos: 1,
        minGarages: 1,
        minPrecio: 100000,
        maxPrecio: 500000,
        municipio: 'Sabaneta',
        minArea: 60,
        forRent: true,
        forSale: false,
      );

      final json = filter.toJson();

      expect(json['min_cuartos'], 2);
      expect(json['min_banos'], 1);
      expect(json['min_garages'], 1);
      expect(json['min_precio'], 100000);
      expect(json['max_precio'], 500000);
      expect(json['municipio'], 'Sabaneta');
      expect(json['min_area'], 60);
      expect(json['for_rent'], true);
      expect(json['for_sale'], false);
    });

    test('serializes null values', () {
      final filter = PropertyFilter();
      final json = filter.toJson();

      expect(json['min_cuartos'], isNull);
      expect(json['municipio'], isNull);
    });
  });
}
