import 'package:flutter_test/flutter_test.dart';
import 'package:inmobarco_app/domain/models/apartment.dart';

void main() {
  Map<String, dynamic> sampleJson() => {
        'id': '123',
        'titulo': 'Apartamento en Envigado',
        'reference': 'REF-001',
        'rentPrice': 1500000.0,
        'salePrice': 350000000.0,
        'cuartos': 3,
        'banos': 2,
        'barrio': 'El Poblado',
        'municipio': 'Medellín',
        'estrato': 5,
        'area': 85.0,
        'estado': '1',
        'estado_texto': 'Activa',
        'imagenes': ['https://example.com/img1.jpg', 'https://example.com/img2.jpg'],
        'descripcion': 'Hermoso apartamento',
        'direccion': 'Cra 43A #1-50',
        'clase_inmueble': 'Apartamento',
        'asesor': 'Juan Barco',
        'departamento': 'Antioquia',
        'coordenadas': '6.2,-75.5',
        'caracteristicas': [
          {'id': '1', 'name': 'Piscina', 'category': 'external'}
        ],
      };

  group('Apartment.fromJson', () {
    test('parses all fields correctly', () {
      final apartment = Apartment.fromJson(sampleJson());

      expect(apartment.id, '123');
      expect(apartment.titulo, 'Apartamento en Envigado');
      expect(apartment.reference, 'REF-001');
      expect(apartment.rentPrice, 1500000.0);
      expect(apartment.salePrice, 350000000.0);
      expect(apartment.cuartos, 3);
      expect(apartment.banos, 2);
      expect(apartment.barrio, 'El Poblado');
      expect(apartment.municipio, 'Medellín');
      expect(apartment.estrato, 5);
      expect(apartment.area, 85.0);
      expect(apartment.estado, '1');
      expect(apartment.estadoTexto, 'Activa');
      expect(apartment.imagenes.length, 2);
      expect(apartment.descripcion, 'Hermoso apartamento');
      expect(apartment.direccion, 'Cra 43A #1-50');
      expect(apartment.claseInmueble, 'Apartamento');
      expect(apartment.asesor, 'Juan Barco');
      expect(apartment.departamento, 'Antioquia');
      expect(apartment.coordenadas, '6.2,-75.5');
      expect(apartment.caracteristicas.length, 1);
    });

    test('handles null/missing fields with defaults', () {
      final apartment = Apartment.fromJson({'id': '1'});

      expect(apartment.id, '1');
      expect(apartment.titulo, '');
      expect(apartment.reference, '');
      expect(apartment.rentPrice, 0.0);
      expect(apartment.salePrice, 0.0);
      expect(apartment.cuartos, 0);
      expect(apartment.banos, 0);
      expect(apartment.imagenes, isEmpty);
      expect(apartment.caracteristicas, isEmpty);
    });

    test('handles completely empty json', () {
      final apartment = Apartment.fromJson({});

      expect(apartment.id, '');
      expect(apartment.rentPrice, 0.0);
    });
  });

  group('Apartment.toJson', () {
    test('roundtrip: fromJson -> toJson -> fromJson preserves data', () {
      final original = Apartment.fromJson(sampleJson());
      final json = original.toJson();
      final restored = Apartment.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.titulo, original.titulo);
      expect(restored.reference, original.reference);
      expect(restored.rentPrice, original.rentPrice);
      expect(restored.salePrice, original.salePrice);
      expect(restored.cuartos, original.cuartos);
      expect(restored.banos, original.banos);
      expect(restored.barrio, original.barrio);
      expect(restored.municipio, original.municipio);
      expect(restored.estrato, original.estrato);
      expect(restored.area, original.area);
      expect(restored.imagenes, original.imagenes);
      expect(restored.caracteristicas.length, original.caracteristicas.length);
    });
  });

  group('Apartment.copyWith', () {
    test('copies with changed fields', () {
      final original = Apartment.fromJson(sampleJson());
      final copy = original.copyWith(titulo: 'Nuevo Titulo', cuartos: 5);

      expect(copy.titulo, 'Nuevo Titulo');
      expect(copy.cuartos, 5);
      // Unchanged fields preserved
      expect(copy.id, original.id);
      expect(copy.reference, original.reference);
      expect(copy.rentPrice, original.rentPrice);
    });

    test('copies with no changes returns equivalent object', () {
      final original = Apartment.fromJson(sampleJson());
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.titulo, original.titulo);
      expect(copy.cuartos, original.cuartos);
    });
  });

  group('Apartment computed properties', () {
    test('priceFormatted shows rent only', () {
      final apt = Apartment.fromJson(sampleJson()).copyWith(salePrice: 0);
      expect(apt.priceFormatted, contains('\$'));
      expect(apt.priceFormatted, isNot(contains('/')));
    });

    test('priceFormatted shows sale only', () {
      final apt = Apartment.fromJson(sampleJson()).copyWith(rentPrice: 0);
      expect(apt.priceFormatted, contains('\$'));
      expect(apt.priceFormatted, isNot(contains('/')));
    });

    test('priceFormatted shows both rent and sale', () {
      final apt = Apartment.fromJson(sampleJson());
      expect(apt.priceFormatted, contains('/'));
    });

    test('priceFormatted returns empty when both are zero', () {
      final apt = Apartment.fromJson(sampleJson()).copyWith(rentPrice: 0, salePrice: 0);
      expect(apt.priceFormatted, '');
    });

    test('ubicacion combines barrio and municipio', () {
      final apt = Apartment.fromJson(sampleJson());
      expect(apt.ubicacion, 'El Poblado, Medellín');
    });

    test('primaryImage returns first image', () {
      final apt = Apartment.fromJson(sampleJson());
      expect(apt.primaryImage, 'https://example.com/img1.jpg');
    });

    test('primaryImage returns empty string when no images', () {
      final apt = Apartment.fromJson(sampleJson()).copyWith(imagenes: []);
      expect(apt.primaryImage, '');
    });
  });
}
