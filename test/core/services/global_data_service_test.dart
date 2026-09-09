import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:inmobarco_app/core/services/global_data_service.dart';
import 'package:inmobarco_app/data/services/cache_service.dart';

@GenerateMocks([CacheService])
import 'global_data_service_test.mocks.dart';

/// `GlobalDataService` habla con `ApiService` (estático) y construye su propio
/// `WasiApiService`. Sin dotenv cargado, cualquier intento de salir a la red
/// lanza `NotInitializedError` al resolver la URL base — antes de abrir un
/// socket — y el servicio lo traga por diseño. Así estos tests son
/// deterministas y offline; el ruido en consola es esperado.
void main() {
  late MockCacheService mockCacheService;
  late GlobalDataService service;

  List<Map<String, dynamic>> cities() => [
        {'id': '291', 'name': 'Envigado'},
      ];
  List<Map<String, dynamic>> features() => [
        {'id': '1', 'name': 'Piscina', 'category': 'external'},
      ];
  List<Map<String, dynamic>> zones() => [
        {'id': '10', 'name': 'El Poblado'},
      ];
  List<Map<String, dynamic>> residentials({String zoneId = '10'}) => [
        {
          'id': 5,
          'name': 'TORRES DEL SUR',
          'id_city': '291',
          'id_zone': zoneId,
        },
      ];

  /// Deja los cuatro catálogos en caché con la frescura indicada.
  ///
  /// Cada catálogo tiene su propio TTL en `CacheService` (características 7
  /// días, ciudades y barrios 24 h, residenciales 10 min), así que aquí la
  /// frescura se inyecta por catálogo.
  void stubCache({bool isStale = false}) {
    when(mockCacheService.loadAllowedCities()).thenAnswer(
        (_) async => CachedResult(data: cities(), isStale: isStale));
    when(mockCacheService.loadFeatures()).thenAnswer(
        (_) async => CachedResult(data: features(), isStale: isStale));
    when(mockCacheService.loadZones()).thenAnswer(
        (_) async => CachedResult(data: zones(), isStale: isStale));
    when(mockCacheService.loadResidentialComplexes()).thenAnswer(
        (_) async => CachedResult(data: residentials(), isStale: isStale));
  }

  void stubEmptyCache() {
    when(mockCacheService.loadAllowedCities()).thenAnswer((_) async => null);
    when(mockCacheService.loadFeatures()).thenAnswer((_) async => null);
    when(mockCacheService.loadZones()).thenAnswer((_) async => null);
    when(mockCacheService.loadResidentialComplexes())
        .thenAnswer((_) async => null);
  }

  setUp(() {
    mockCacheService = MockCacheService();
    service = GlobalDataService(cacheService: mockCacheService);
  });

  group('hydrateFromCache', () {
    test('loads the four catalogs from disk', () async {
      stubCache();

      await service.hydrateFromCache();

      expect(service.cities.single['name'], 'Envigado');
      expect(service.features.single['name'], 'Piscina');
      expect(service.zones.single['name'], 'El Poblado');
      expect(service.residentialComplexes.single['name'], 'TORRES DEL SUR');
      expect(service.isInitialized, isTrue);
    });

    test('runs only once', () async {
      stubCache();

      await service.hydrateFromCache();
      await service.hydrateFromCache();

      verify(mockCacheService.loadFeatures()).called(1);
    });

    test('leaves the catalogs empty when there is no cache', () async {
      stubEmptyCache();

      await service.hydrateFromCache();

      expect(service.cities, isEmpty);
      expect(service.features, isEmpty);
    });

    test('serves an expired cache instead of starting empty', () async {
      stubCache(isStale: true);

      await service.hydrateFromCache();

      expect(service.cities.single['name'], 'Envigado');
      expect(service.residentialComplexes, hasLength(1));
    });
  });

  group('refreshStale', () {
    test('does not touch the network when every catalog is fresh', () async {
      stubCache();
      await service.hydrateFromCache();

      await service.refreshStale();

      // Nada que refrescar ⇒ ni siquiera se evalúa el token de WASI, así que
      // un arranque con caché vigente no gasta una sola petición.
      expect(service.isLoading, isFalse);
      verifyNever(mockCacheService.saveFeatures(any));
      verifyNever(mockCacheService.saveAllowedCities(any));
    });

    test('leaves fresh catalogs alone when only residentials expired',
        () async {
      // Es el ciclo normal: los residenciales vencen cada 10 min, y eso no
      // debe arrastrar una re-descarga de barrios (24 h) ni características
      // (7 días).
      stubCache();
      when(mockCacheService.loadResidentialComplexes()).thenAnswer(
          (_) async => CachedResult(data: residentials(), isStale: true));
      await service.hydrateFromCache();

      await service.refreshStale();

      verifyNever(mockCacheService.saveFeatures(any));
      verifyNever(mockCacheService.saveAllowedCities(any));
      verifyNever(mockCacheService.saveZones(any));
      expect(service.residentialComplexes, hasLength(1));
    });

    test('keeps the cached values when the refresh fails', () async {
      stubCache(isStale: true);
      await service.hydrateFromCache();

      await service.refreshStale();

      // Sin red (ni dotenv) el refresco falla, y el último valor conocido
      // debe seguir en pie.
      expect(service.cities.single['name'], 'Envigado');
      expect(service.features.single['name'], 'Piscina');
      expect(service.zones.single['name'], 'El Poblado');
      expect(service.residentialComplexes, hasLength(1));
      expect(service.isLoading, isFalse);
    });
  });
}
