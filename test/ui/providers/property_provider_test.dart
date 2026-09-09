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

  Apartment sampleApartment({String id = '1', String reference = 'REF-001'}) =>
      Apartment.fromJson({
        'id': id,
        'titulo': 'Apartamento $id',
        'reference': reference,
        'rentPrice': 1500000.0,
        'salePrice': 0.0,
        'imagenes': <String>[],
        'caracteristicas': <Map<String, dynamic>>[],
        'forRent': true,
      });

  // Fresh list each time: loadProperties(refresh: true) mutates the list in place.
  List<Apartment> apartments(int count) => List.generate(
        count,
        (i) => sampleApartment(id: '$i', reference: 'REF-$i'),
      );

  CachedResult<List<Apartment>> cached(int count, {bool isStale = false}) =>
      CachedResult(data: apartments(count), isStale: isStale);

  void stubApi(List<Apartment> result) {
    when(mockApiService.getActiveProperties(
      filter: anyNamed('filter'),
      page: anyNamed('page'),
      limit: anyNamed('limit'),
    )).thenAnswer((_) async => result);
  }

  /// Builds the provider. The constructor fires `_loadFromCache()`, so
  /// `loadProperties()` must already be stubbed and the microtask flushed.
  Future<PropertyProvider> buildProvider() async {
    final provider = PropertyProvider(
      apiService: mockApiService,
      cacheService: mockCacheService,
    );
    await pumpEventQueue();
    return provider;
  }

  setUp(() {
    mockApiService = MockWasiApiService();
    mockCacheService = MockCacheService();
    when(mockCacheService.loadProperties()).thenAnswer((_) async => null);
    when(mockCacheService.saveProperties(any)).thenAnswer((_) async {});
    when(mockCacheService.saveFilter(any)).thenAnswer((_) async {});
  });

  group('construction', () {
    test('starts empty when there is no cache', () async {
      final provider = await buildProvider();

      expect(provider.properties, isEmpty);
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.hasMoreData, isTrue);
      expect(provider.isLoadingFromCache, isFalse);
      expect(provider.hasActiveFilters, isFalse);
    });

    test('loads from cache and stops pagination', () async {
      when(mockCacheService.loadProperties())
          .thenAnswer((_) async => cached(3));

      final provider = await buildProvider();

      expect(provider.properties.length, 3);
      expect(provider.hasMoreData, isFalse);
      expect(provider.isCacheStale, isFalse);
    });

    test('serves an expired cache and flags it as stale', () async {
      when(mockCacheService.loadProperties())
          .thenAnswer((_) async => cached(3, isStale: true));

      final provider = await buildProvider();

      // Last-known-good: sin red y con caché vencido se pinta lo viejo en vez
      // de dejar la pantalla vacía.
      expect(provider.properties.length, 3);
      expect(provider.isCacheStale, isTrue);
    });

    test('survives a cache failure', () async {
      when(mockCacheService.loadProperties()).thenThrow(Exception('corrupt'));

      final provider = await buildProvider();

      expect(provider.properties, isEmpty);
      expect(provider.isLoadingFromCache, isFalse);
    });
  });

  group('loadProperties', () {
    test('keeps paginating when a full page comes back', () async {
      final provider = await buildProvider();
      stubApi(apartments(AppConstants.pageSize));

      await provider.loadProperties();

      expect(provider.properties.length, AppConstants.pageSize);
      expect(provider.hasMoreData, isTrue);
      expect(provider.isLoading, isFalse);
    });

    test('stops paginating on a partial page', () async {
      final provider = await buildProvider();
      stubApi(apartments(5));

      await provider.loadProperties();

      expect(provider.hasMoreData, isFalse);
    });

    test('caches only the first page', () async {
      final provider = await buildProvider();
      stubApi(apartments(AppConstants.pageSize));

      await provider.loadProperties();
      await provider.loadProperties();

      verify(mockCacheService.saveProperties(any)).called(1);
    });

    test('clears the stale flag after a successful reload', () async {
      when(mockCacheService.loadProperties())
          .thenAnswer((_) async => cached(3, isStale: true));
      final provider = await buildProvider();
      expect(provider.isCacheStale, isTrue);
      stubApi(apartments(AppConstants.pageSize));

      await provider.loadProperties(refresh: true);

      expect(provider.isCacheStale, isFalse);
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

    test('does not call the API once there is no more data', () async {
      final provider = await buildProvider();
      stubApi(apartments(2));

      await provider.loadProperties();
      await provider.loadMoreProperties();

      verify(mockApiService.getActiveProperties(
        filter: anyNamed('filter'),
        page: anyNamed('page'),
        limit: anyNamed('limit'),
      )).called(1);
    });
  });

  group('filters', () {
    test('updateFilter persists the filter and reloads', () async {
      final provider = await buildProvider();
      stubApi(apartments(2));
      final filter = PropertyFilter(municipio: 'Envigado', minCuartos: 2);

      await provider.updateFilter(filter);

      expect(provider.currentFilter.municipio, 'Envigado');
      expect(provider.hasActiveFilters, isTrue);
      verify(mockCacheService.saveFilter(filter.toJson())).called(1);
      expect(provider.properties.length, 2);
    });

    test('does not persist filtered results as the startup snapshot', () async {
      final provider = await buildProvider();
      stubApi(apartments(3));

      await provider.updateFilter(PropertyFilter(minCuartos: 3));

      // El snapshot de arranque debe ser el inventario, no un subconjunto
      // filtrado presentado como tal.
      verifyNever(mockCacheService.saveProperties(any));
    });

    test('persists again once the filters are cleared', () async {
      final provider = await buildProvider();
      stubApi(apartments(3));
      await provider.updateFilter(PropertyFilter(minCuartos: 3));

      await provider.clearFilters();

      verify(mockCacheService.saveProperties(any)).called(1);
    });

    test('clearFilters wipes the stored filter', () async {
      final provider = await buildProvider();
      stubApi(apartments(1));
      await provider.updateFilter(PropertyFilter(municipio: 'Bello'));

      await provider.clearFilters();

      expect(provider.hasActiveFilters, isFalse);
      verify(mockCacheService.saveFilter({})).called(1);
    });
  });

  group('getPropertyById', () {
    test('replaces the local entry with the detailed one', () async {
      final provider = await buildProvider();
      stubApi([sampleApartment(id: '7', reference: 'OLD')]);
      await provider.loadProperties();

      when(mockApiService.getPropertyById('7'))
          .thenAnswer((_) async => sampleApartment(id: '7', reference: 'NEW'));

      final result = await provider.getPropertyById('7');

      expect(result!.reference, 'NEW');
      expect(provider.properties.single.reference, 'NEW');
    });

    test('falls back to the local copy when the API fails', () async {
      final provider = await buildProvider();
      stubApi([sampleApartment(id: '7', reference: 'LOCAL')]);
      await provider.loadProperties();

      when(mockApiService.getPropertyById('7')).thenThrow(Exception('timeout'));

      final result = await provider.getPropertyById('7');

      expect(result!.reference, 'LOCAL');
    });

    test('throws when the API fails and there is no local copy', () async {
      final provider = await buildProvider();
      when(mockApiService.getPropertyById('404'))
          .thenThrow(Exception('not found'));

      expect(() => provider.getPropertyById('404'), throwsException);
    });
  });

  group('search', () {
    test('filters by reference after the debounce elapses', () async {
      final provider = await buildProvider();
      stubApi([
        sampleApartment(id: '1', reference: 'REF-AAA'),
        sampleApartment(id: '2', reference: 'REF-BBB'),
      ]);
      await provider.loadProperties();

      provider.updateSearchQuery('aaa');
      expect(provider.filteredProperties.length, 2, reason: 'still debouncing');

      await Future.delayed(const Duration(milliseconds: 400));

      expect(provider.filteredProperties.single.reference, 'REF-AAA');
    });

    test('matches on WASI id too', () async {
      final provider = await buildProvider();
      stubApi([
        sampleApartment(id: '55501', reference: 'REF-AAA'),
        sampleApartment(id: '2', reference: 'REF-BBB'),
      ]);
      await provider.loadProperties();

      provider.updateSearchQuery('555');
      await Future.delayed(const Duration(milliseconds: 400));

      expect(provider.filteredProperties.single.id, '55501');
    });

    test('clearSearchQuery applies immediately', () async {
      final provider = await buildProvider();
      stubApi(apartments(2));
      await provider.loadProperties();

      provider.updateSearchQuery('REF-0');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(provider.filteredProperties.length, 1);

      provider.clearSearchQuery();

      expect(provider.filteredProperties.length, 2);
    });
  });

  group('cache delegation', () {
    test('clearCache empties the list', () async {
      final provider = await buildProvider();
      stubApi(apartments(3));
      await provider.loadProperties();
      when(mockCacheService.clearCache()).thenAnswer((_) async {});

      await provider.clearCache();

      expect(provider.properties, isEmpty);
      verify(mockCacheService.clearCache()).called(1);
    });

    test('getCacheInfo delegates', () async {
      final provider = await buildProvider();
      when(mockCacheService.getCacheInfo())
          .thenAnswer((_) async => {'count': 42});

      expect(await provider.getCacheInfo(), {'count': 42});
    });
  });
}
