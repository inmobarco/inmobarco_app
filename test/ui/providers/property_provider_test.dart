import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:inmobarco_app/core/constants/app_constants.dart';
import 'package:inmobarco_app/data/services/cache_service.dart';
import 'package:inmobarco_app/data/services/wasi_api_service.dart';
import 'package:inmobarco_app/domain/models/apartment.dart';
import 'package:inmobarco_app/domain/models/property_filter.dart';
import 'package:inmobarco_app/ui/providers/property_provider.dart';

@GenerateMocks([WasiApiService, CacheService])
import 'property_provider_test.mocks.dart';

void main() {
  late MockWasiApiService mockApiService;
  late MockCacheService mockCacheService;

  Apartment apartment({
    String id = '1',
    String reference = 'REF-001',
    double rentPrice = 1500000,
    double salePrice = 0,
    int cuartos = 2,
    int banos = 2,
    int garages = 1,
    double area = 60,
    String barrio = 'El Poblado',
    String municipio = 'Envigado',
    String claseInmueble = 'Apartamento',
    String idCity = '',
    String idZone = '',
    String idPropertyType = '',
    bool forRent = true,
    bool forSale = false,
  }) =>
      Apartment(
        id: id,
        titulo: 'Apartamento $id',
        reference: reference,
        rentPrice: rentPrice,
        salePrice: salePrice,
        cuartos: cuartos,
        banos: banos,
        garages: garages,
        barrio: barrio,
        municipio: municipio,
        estrato: 4,
        area: area,
        estado: '1',
        estadoTexto: 'Activa',
        imagenes: const [],
        descripcion: '',
        direccion: '',
        claseInmueble: claseInmueble,
        asesor: '',
        departamento: 'Antioquia',
        coordenadas: '',
        caracteristicas: const [],
        forRent: forRent,
        forSale: forSale,
        idCity: idCity,
        idZone: idZone,
        idPropertyType: idPropertyType,
      );

  List<Apartment> apartments(int count) => List.generate(
        count,
        (i) => apartment(id: '$i', reference: 'REF-$i'),
      );

  CachedResult<List<Apartment>> cached(
    List<Apartment> items, {
    bool isStale = false,
  }) =>
      CachedResult(data: items, isStale: isStale);

  /// Responde a `getPropertiesPage` paginando [items] de a 100, con el `total`
  /// que devuelve WASI.
  void stubInventory(List<Apartment> items, {int? total}) {
    when(mockApiService.getPropertiesPage(
      filter: anyNamed('filter'),
      page: anyNamed('page'),
      limit: anyNamed('limit'),
    )).thenAnswer((invocation) async {
      final page = invocation.namedArguments[const Symbol('page')] as int? ?? 1;
      final start = (page - 1) * AppConstants.pageSize;
      final end = (start + AppConstants.pageSize).clamp(0, items.length);
      return PropertyPage(
        items: start >= items.length ? [] : items.sublist(start, end),
        total: total ?? items.length,
      );
    });
  }

  void stubRemotePages(List<Apartment> result) {
    when(mockApiService.getActiveProperties(
      filter: anyNamed('filter'),
      page: anyNamed('page'),
      limit: anyNamed('limit'),
    )).thenAnswer((_) async => result);
  }

  /// Deja el inventario completo en caché, listo para filtrar en local.
  void stubCachedInventory(List<Apartment> items, {bool isStale = false}) {
    when(mockCacheService.loadProperties())
        .thenAnswer((_) async => cached(items, isStale: isStale));
    when(mockCacheService.isCachedInventoryComplete())
        .thenAnswer((_) async => true);
  }

  /// Builds the provider. The constructor fires `_loadFromCache()`, so the
  /// cache stubs must already be in place and the microtask flushed.
  Future<PropertyProvider> buildProvider() async {
    final provider = PropertyProvider(
      apiService: mockApiService,
      cacheService: mockCacheService,
    );
    await provider.hydration;
    return provider;
  }

  setUp(() {
    mockApiService = MockWasiApiService();
    mockCacheService = MockCacheService();
    when(mockCacheService.loadProperties()).thenAnswer((_) async => null);
    when(mockCacheService.isCachedInventoryComplete())
        .thenAnswer((_) async => false);
    when(mockCacheService.saveProperties(any, complete: anyNamed('complete')))
        .thenAnswer((_) async {});
    when(mockCacheService.saveFilter(any)).thenAnswer((_) async {});
    when(mockCacheService.loadPropertyDetail(any))
        .thenAnswer((_) async => null);
    when(mockCacheService.savePropertyDetail(any)).thenAnswer((_) async {});
  });

  group('construction', () {
    test('starts empty when there is no cache', () async {
      final provider = await buildProvider();

      expect(provider.properties, isEmpty);
      expect(provider.hasLocalInventory, isFalse);
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isLoadingFromCache, isFalse);
      expect(provider.hasActiveFilters, isFalse);
    });

    test('hydrates the local inventory from a complete cache', () async {
      stubCachedInventory(apartments(3));

      final provider = await buildProvider();

      expect(provider.hasLocalInventory, isTrue);
      expect(provider.inventoryCount, 3);
      expect(provider.properties.length, 3);
      expect(provider.isCacheStale, isFalse);
    });

    test('serves an expired inventory and flags it as stale', () async {
      stubCachedInventory(apartments(3), isStale: true);

      final provider = await buildProvider();

      // Last-known-good: sin red y con caché vencido se pinta lo viejo en vez
      // de dejar la pantalla vacía.
      expect(provider.properties.length, 3);
      expect(provider.isCacheStale, isTrue);
    });

    test('treats a partial snapshot as stale and not filterable locally',
        () async {
      // Caché escrito por una versión anterior: solo la primera página.
      when(mockCacheService.loadProperties())
          .thenAnswer((_) async => cached(apartments(3)));
      when(mockCacheService.isCachedInventoryComplete())
          .thenAnswer((_) async => false);

      final provider = await buildProvider();

      expect(provider.properties.length, 3, reason: 'sirve para pintar');
      expect(provider.hasLocalInventory, isFalse);
      expect(provider.isCacheStale, isTrue, reason: 'debe disparar el sync');
    });

    test('survives a cache failure', () async {
      when(mockCacheService.loadProperties()).thenThrow(Exception('corrupt'));

      final provider = await buildProvider();

      expect(provider.properties, isEmpty);
      expect(provider.isLoadingFromCache, isFalse);
    });
  });

  group('syncInventory', () {
    test('paginates until the last page and persists it as complete',
        () async {
      final provider = await buildProvider();
      stubInventory(apartments(250));

      await provider.syncInventory();

      expect(provider.inventoryCount, 250);
      expect(provider.hasLocalInventory, isTrue);
      verify(mockApiService.getPropertiesPage(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      )).called(3);
      verify(mockCacheService.saveProperties(any, complete: true)).called(1);
    });

    test('stops as soon as it reaches the total reported by WASI', () async {
      final provider = await buildProvider();
      // Página exacta de 100 con total 100: sin el total habría pedido una
      // segunda página para descubrir que no hay más.
      stubInventory(apartments(100), total: 100);

      await provider.syncInventory();

      verify(mockApiService.getPropertiesPage(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      )).called(1);
      expect(provider.inventoryCount, 100);
    });

    test('never sends filters, so the cache is the inventory', () async {
      stubCachedInventory(apartments(5));
      final provider = await buildProvider();
      stubInventory(apartments(5));
      await provider.updateFilter(PropertyFilter(minCuartos: 3));

      await provider.syncInventory(force: true);

      verify(mockApiService.getPropertiesPage(
        filter: null,
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      )).called(1);
    });

    test('skips the network when the inventory is fresh', () async {
      stubCachedInventory(apartments(3));
      final provider = await buildProvider();

      await provider.syncInventory();

      verifyNever(mockApiService.getPropertiesPage(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      ));
    });

    test('force re-syncs even when the inventory is fresh', () async {
      stubCachedInventory(apartments(3));
      final provider = await buildProvider();
      stubInventory(apartments(4));

      await provider.syncInventory(force: true);

      expect(provider.inventoryCount, 4);
    });

    test('keeps the previous inventory when the sync fails', () async {
      stubCachedInventory(apartments(3), isStale: true);
      final provider = await buildProvider();
      when(mockApiService.getPropertiesPage(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      )).thenThrow(Exception('network down'));

      await provider.syncInventory();

      expect(provider.inventoryCount, 3);
      expect(provider.error, contains('network down'));
      verifyNever(mockCacheService.saveProperties(any,
          complete: anyNamed('complete')));
    });

    test('keeps the previous inventory when the sync comes back empty',
        () async {
      stubCachedInventory(apartments(3), isStale: true);
      final provider = await buildProvider();
      stubInventory([], total: 0);

      await provider.syncInventory();

      // Un inventario que se vacía de golpe es más probablemente un problema
      // de WASI que un inventario realmente vacío.
      expect(provider.inventoryCount, 3);
      verifyNever(mockCacheService.saveProperties(any,
          complete: anyNamed('complete')));
    });

    test('exposes progress while it runs', () async {
      final provider = await buildProvider();
      stubInventory(apartments(150));
      final seen = <String>[];
      provider.addListener(() {
        if (provider.isSyncingInventory) {
          seen.add('${provider.syncedCount}/${provider.syncTotal}');
        }
      });

      await provider.syncInventory();

      expect(seen, contains('100/150'));
      expect(provider.isSyncingInventory, isFalse);
    });
  });

  group('local filtering', () {
    Future<PropertyProvider> providerWith(List<Apartment> items) async {
      stubCachedInventory(items);
      return buildProvider();
    }

    test('does not touch the API when filtering locally', () async {
      final provider = await providerWith(apartments(5));

      await provider.updateFilter(PropertyFilter(minCuartos: 2));

      verifyNever(mockApiService.getActiveProperties(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      ));
      verifyNever(mockApiService.getPropertiesPage(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      ));
      verify(mockCacheService.saveFilter(any)).called(1);
    });

    test('bedrooms, bathrooms, garages and area are minimums', () async {
      final provider = await providerWith([
        apartment(id: 'a', cuartos: 1, banos: 1, garages: 0, area: 40),
        apartment(id: 'b', cuartos: 3, banos: 2, garages: 2, area: 90),
      ]);

      await provider.updateFilter(PropertyFilter(
        minCuartos: 2,
        minBanos: 2,
        minGarages: 1,
        minArea: 50,
      ));

      // WASI manda minBanos/minGarages a `bathrooms`/`garages`, que son
      // coincidencia exacta; en local el mínimo es realmente mínimo.
      expect(provider.properties.single.id, 'b');
    });

    test('price range applies to the rent price when filtering rentals',
        () async {
      final provider = await providerWith([
        apartment(id: 'rent', rentPrice: 1800000, salePrice: 900000000),
        apartment(id: 'other', rentPrice: 4000000, salePrice: 100000),
      ]);

      await provider.updateFilter(PropertyFilter(
        forRent: true,
        minPrecio: 1000000,
        maxPrecio: 2000000,
      ));

      // Con la API, el precio de venta de 'other' podía colarse en el rango.
      expect(provider.properties.single.id, 'rent');
    });

    test('price range applies to the sale price when filtering sales',
        () async {
      final provider = await providerWith([
        apartment(
            id: 'sale',
            forRent: false,
            forSale: true,
            rentPrice: 0,
            salePrice: 350000000),
        apartment(
            id: 'expensive',
            forRent: false,
            forSale: true,
            rentPrice: 0,
            salePrice: 900000000),
      ]);

      await provider.updateFilter(PropertyFilter(
        forSale: true,
        maxPrecio: 400000000,
      ));

      expect(provider.properties.single.id, 'sale');
    });

    test('matches city by id when the property carries it', () async {
      final provider = await providerWith([
        apartment(id: 'a', idCity: '291', municipio: 'Envigado'),
        apartment(id: 'b', idCity: '496', municipio: 'Medellín'),
      ]);

      await provider
          .updateFilter(PropertyFilter(municipio: 'Envigado', idCity: '291'));

      expect(provider.properties.single.id, 'a');
    });

    test('falls back to the city label when there is no id', () async {
      final provider = await providerWith([
        apartment(id: 'a', municipio: 'Envigado'),
        apartment(id: 'b', municipio: 'Medellín'),
      ]);

      await provider
          .updateFilter(PropertyFilter(municipio: 'medellín', idCity: '496'));

      // La respuesta corta de WASI no siempre trae los ids.
      expect(provider.properties.single.id, 'b');
    });

    test('matches zone by id, and by name when there is no id', () async {
      final provider = await providerWith([
        apartment(id: 'a', idZone: '10', barrio: 'El Poblado'),
        apartment(id: 'b', barrio: 'Laureles'),
      ]);

      await provider.updateFilter(PropertyFilter(idZone: '10'));
      expect(provider.properties.single.id, 'a');

      await provider
          .updateFilter(PropertyFilter(idZone: '99', zoneName: 'Laureles'));
      expect(provider.properties.single.id, 'b');
    });

    test('matches property type by id and by label', () async {
      final provider = await providerWith([
        apartment(id: 'house', idPropertyType: '1', claseInmueble: 'Casa'),
        apartment(id: 'apt', claseInmueble: 'Apartamento'),
      ]);

      await provider.updateFilter(PropertyFilter(idPropertyType: '1'));
      expect(provider.properties.single.id, 'house');

      // '2' es Apartamento en AppConstants.allPropertyTypes.
      await provider.updateFilter(PropertyFilter(idPropertyType: '2'));
      expect(provider.properties.single.id, 'apt');
    });

    test('clearFilters brings the whole inventory back', () async {
      final provider = await providerWith(apartments(5));
      await provider.updateFilter(PropertyFilter(minCuartos: 9));
      expect(provider.properties, isEmpty);

      await provider.clearFilters();

      expect(provider.properties.length, 5);
      expect(provider.hasActiveFilters, isFalse);
    });
  });

  group('local pagination', () {
    test('shows one page at a time and grows without network', () async {
      stubCachedInventory(apartments(250));
      final provider = await buildProvider();

      expect(provider.properties.length, AppConstants.pageSize);
      expect(provider.hasMoreData, isTrue);

      await provider.loadMoreProperties();
      expect(provider.properties.length, 200);

      await provider.loadMoreProperties();
      expect(provider.properties.length, 250);
      expect(provider.hasMoreData, isFalse);

      verifyNever(mockApiService.getPropertiesPage(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      ));
    });

    test('pagination follows the filtered list', () async {
      stubCachedInventory([
        ...List.generate(120, (i) => apartment(id: 'r$i', cuartos: 1)),
        ...List.generate(5, (i) => apartment(id: 's$i', cuartos: 4)),
      ]);
      final provider = await buildProvider();

      await provider.updateFilter(PropertyFilter(minCuartos: 3));

      expect(provider.properties.length, 5);
      expect(provider.hasMoreData, isFalse);
    });
  });

  group('search', () {
    test('spans the whole inventory, not just the visible page', () async {
      final items = apartments(250);
      stubCachedInventory(items);
      final provider = await buildProvider();

      provider.updateSearchQuery('REF-240');
      await Future.delayed(const Duration(milliseconds: 400));

      // La referencia está en la página 3: con la búsqueda en memoria sobre lo
      // ya visible no aparecía hasta scrollear.
      expect(provider.filteredProperties.single.reference, 'REF-240');
    });

    test('matches on the WASI id too', () async {
      stubCachedInventory([
        apartment(id: '55501', reference: 'REF-AAA'),
        apartment(id: '2', reference: 'REF-BBB'),
      ]);
      final provider = await buildProvider();

      provider.updateSearchQuery('555');
      await Future.delayed(const Duration(milliseconds: 400));

      expect(provider.filteredProperties.single.id, '55501');
    });

    test('search respects the active filter', () async {
      stubCachedInventory([
        apartment(id: '1', reference: 'REF-AAA', cuartos: 1),
        apartment(id: '2', reference: 'REF-AAB', cuartos: 4),
      ]);
      final provider = await buildProvider();
      await provider.updateFilter(PropertyFilter(minCuartos: 3));

      provider.updateSearchQuery('ref-aa');
      await Future.delayed(const Duration(milliseconds: 400));

      expect(provider.filteredProperties.single.id, '2');
    });

    test('clearSearchQuery applies immediately', () async {
      stubCachedInventory(apartments(3));
      final provider = await buildProvider();
      provider.updateSearchQuery('REF-0');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(provider.filteredProperties.length, 1);

      provider.clearSearchQuery();

      expect(provider.filteredProperties.length, 3);
    });
  });

  group('degraded mode (no local inventory)', () {
    test('paginates the API with server-side filters', () async {
      final provider = await buildProvider();
      stubRemotePages(apartments(AppConstants.pageSize));

      await provider.loadProperties();

      expect(provider.properties.length, AppConstants.pageSize);
      expect(provider.hasMoreData, isTrue);
      verify(mockApiService.getActiveProperties(
        filter: anyNamed('filter'),
        page: 1,
        limit: AppConstants.pageSize,
      )).called(1);
    });

    test('stops paginating on a partial page', () async {
      final provider = await buildProvider();
      stubRemotePages(apartments(5));

      await provider.loadProperties();

      expect(provider.hasMoreData, isFalse);
    });

    test('updateFilter goes to the API', () async {
      final provider = await buildProvider();
      stubRemotePages(apartments(2));

      await provider.updateFilter(PropertyFilter(minCuartos: 2));

      expect(provider.properties.length, 2);
      verify(mockApiService.getActiveProperties(
        filter: anyNamed('filter'),
        page: 1,
        limit: anyNamed('limit'),
      )).called(1);
    });

    test('never caches a filtered result', () async {
      final provider = await buildProvider();
      stubRemotePages(apartments(2));

      await provider.updateFilter(PropertyFilter(minCuartos: 2));

      verifyNever(mockCacheService.saveProperties(any,
          complete: anyNamed('complete')));
    });

    test('sets error and clears loading when the API throws', () async {
      final provider = await buildProvider();
      when(mockApiService.getActiveProperties(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      )).thenThrow(Exception('network down'));

      await provider.loadProperties();

      expect(provider.error, contains('network down'));
      expect(provider.isLoading, isFalse);
    });

    test('a successful sync takes over from the degraded pages', () async {
      final provider = await buildProvider();
      stubRemotePages(apartments(5));
      await provider.loadProperties();
      expect(provider.hasLocalInventory, isFalse);

      stubInventory(apartments(7));
      await provider.syncInventory();

      expect(provider.hasLocalInventory, isTrue);
      expect(provider.properties.length, 7);
    });
  });

  group('getPropertyById', () {
    test('serves a fresh detail from cache without hitting the API', () async {
      stubCachedInventory(apartments(3));
      final provider = await buildProvider();
      final detail = apartment(id: '1', reference: 'CACHED');
      when(mockCacheService.loadPropertyDetail('1'))
          .thenAnswer((_) async => CachedResult(data: detail, isStale: false));

      final result = await provider.getPropertyById('1');

      expect(result!.reference, 'CACHED');
      verifyNever(mockApiService.getPropertyById(any));
    });

    test('fetches and caches the detail when there is none', () async {
      stubCachedInventory(apartments(3));
      final provider = await buildProvider();
      when(mockApiService.getPropertyById('1'))
          .thenAnswer((_) async => apartment(id: '1', reference: 'FRESH'));

      final result = await provider.getPropertyById('1');

      expect(result!.reference, 'FRESH');
      verify(mockCacheService.savePropertyDetail(any)).called(1);
      // Y la lista queda con la versión detallada.
      expect(
        provider.properties.firstWhere((p) => p.id == '1').reference,
        'FRESH',
      );
    });

    test('revalidates an expired detail against the API', () async {
      stubCachedInventory(apartments(3));
      final provider = await buildProvider();
      when(mockCacheService.loadPropertyDetail('1')).thenAnswer((_) async =>
          CachedResult(
              data: apartment(id: '1', reference: 'OLD'), isStale: true));
      when(mockApiService.getPropertyById('1'))
          .thenAnswer((_) async => apartment(id: '1', reference: 'NEW'));

      final result = await provider.getPropertyById('1');

      expect(result!.reference, 'NEW');
      verify(mockCacheService.savePropertyDetail(any)).called(1);
    });

    test('falls back to the expired detail when the API fails', () async {
      stubCachedInventory(apartments(3));
      final provider = await buildProvider();
      when(mockCacheService.loadPropertyDetail('1')).thenAnswer((_) async =>
          CachedResult(
              data: apartment(id: '1', reference: 'OLD'), isStale: true));
      when(mockApiService.getPropertyById('1')).thenThrow(Exception('timeout'));

      final result = await provider.getPropertyById('1');

      expect(result!.reference, 'OLD');
    });

    test('falls back to the short copy from the list', () async {
      stubCachedInventory([apartment(id: '7', reference: 'SHORT')]);
      final provider = await buildProvider();
      when(mockApiService.getPropertyById('7')).thenThrow(Exception('timeout'));

      final result = await provider.getPropertyById('7');

      expect(result!.reference, 'SHORT');
    });

    test('throws when the API fails and nothing is local', () async {
      final provider = await buildProvider();
      when(mockApiService.getPropertyById('404'))
          .thenThrow(Exception('not found'));

      expect(() => provider.getPropertyById('404'), throwsException);
    });
  });

  group('cache delegation', () {
    test('clearCache empties the inventory and the degraded pages', () async {
      stubCachedInventory(apartments(3));
      final provider = await buildProvider();
      when(mockCacheService.clearCache()).thenAnswer((_) async {});

      await provider.clearCache();

      expect(provider.properties, isEmpty);
      expect(provider.hasLocalInventory, isFalse);
      verify(mockCacheService.clearCache()).called(1);
    });

    test('getCacheInfo delegates to the cache service', () async {
      final provider = await buildProvider();
      when(mockCacheService.getCacheInfo())
          .thenAnswer((_) async => {'hasCache': true});

      expect(await provider.getCacheInfo(), {'hasCache': true});
    });
  });
}
