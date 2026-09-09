import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:inmobarco_app/data/services/cache_service.dart';
import 'package:inmobarco_app/data/services/wasi_api_service.dart';
import 'package:inmobarco_app/domain/models/client.dart';
import 'package:inmobarco_app/ui/providers/client_provider.dart';

@GenerateMocks([WasiApiService, CacheService])
import 'client_provider_test.mocks.dart';

/// `ClientProvider` reaches the static `ApiService` for the CRM log
/// (`loadLatestNotes`) and for the advisor-map fallback. With dotenv unloaded
/// those calls throw `NotInitializedError` while resolving the base URL —
/// before any socket is opened — and the provider swallows it by design. So
/// these tests are deterministic and offline; the console noise is expected.
///
/// Stubbing `cacheService.loadAdvisorMap()` is what keeps the advisor id
/// resolution away from the network.
void main() {
  late MockWasiApiService mockApiService;
  late MockCacheService mockCacheService;
  late ClientProvider provider;

  const advisorPropertyId = '999';

  Map<String, dynamic> wasiClient({
    required int id,
    required String firstName,
    required String lastName,
  }) =>
      {
        'id_client': id,
        'first_name': firstName,
        'last_name': lastName,
        'cell_phone': '30012345$id',
        'email': '',
        'id_client_status': 2,
      };

  void stubAdvisorFromCache() {
    when(mockCacheService.loadAdvisorMap())
        .thenAnswer((_) async => {'id_property_wasi': advisorPropertyId});
  }

  setUp(() {
    mockApiService = MockWasiApiService();
    mockCacheService = MockCacheService();
    when(mockCacheService.saveClients(any)).thenAnswer((_) async {});
    when(mockCacheService.loadClients()).thenAnswer((_) async => null);
    provider = ClientProvider(
      apiService: mockApiService,
      cacheService: mockCacheService,
    );
  });

  group('ensureAdvisorMap', () {
    test('resolves the advisor property from cache', () async {
      stubAdvisorFromCache();

      final id = await provider.ensureAdvisorMap();

      expect(id, advisorPropertyId);
      expect(provider.advisorPropertyId, advisorPropertyId);
    });

    test('is idempotent: cache is read only once', () async {
      stubAdvisorFromCache();

      await provider.ensureAdvisorMap();
      await provider.ensureAdvisorMap();

      verify(mockCacheService.loadAdvisorMap()).called(1);
    });

    test('returns null without throwing when nothing resolves', () async {
      when(mockCacheService.loadAdvisorMap()).thenAnswer((_) async => null);

      final id = await provider.ensureAdvisorMap();

      expect(id, isNull);
      expect(provider.advisorPropertyId, isNull);
    });

    test('ignores a cached entry with an empty id', () async {
      when(mockCacheService.loadAdvisorMap())
          .thenAnswer((_) async => {'id_property_wasi': ''});

      expect(await provider.ensureAdvisorMap(), isNull);
    });
  });

  group('loadClients', () {
    test('maps WASI clients and sorts them by full name', () async {
      stubAdvisorFromCache();
      when(mockApiService.getClientsByProperty(advisorPropertyId))
          .thenAnswer((_) async => [
                wasiClient(id: 2, firstName: 'Zoe', lastName: 'Ruiz'),
                wasiClient(id: 1, firstName: 'Ana', lastName: 'Gómez'),
              ]);

      await provider.loadClients();

      expect(provider.clients.map((c) => c.fullName),
          ['Ana Gómez', 'Zoe Ruiz']);
      expect(provider.clients.first.idClientWasi, 1);
      expect(provider.clients.first.cellPhone, '300123451');
      expect(provider.clients.first.email, isNull, reason: 'empty → null');
      expect(provider.clients.first.statusLabel, 'En Proceso');
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('caches the mapped list', () async {
      stubAdvisorFromCache();
      when(mockApiService.getClientsByProperty(advisorPropertyId))
          .thenAnswer((_) async => [
                wasiClient(id: 1, firstName: 'Ana', lastName: 'Gómez'),
              ]);

      await provider.loadClients();

      final saved = verify(mockCacheService.saveClients(captureAny))
          .captured
          .single as List<Client>;
      expect(saved.single.idClientWasi, 1);
    });

    test('skips WASI entirely when the advisor has no property', () async {
      when(mockCacheService.loadAdvisorMap()).thenAnswer((_) async => null);

      await provider.loadClients();

      expect(provider.clients, isEmpty);
      verifyNever(mockApiService.getClientsByProperty(any));
      verifyNever(mockCacheService.saveClients(any));
    });

    test('surfaces the error when WASI fails', () async {
      stubAdvisorFromCache();
      when(mockApiService.getClientsByProperty(advisorPropertyId))
          .thenThrow(Exception('WASI 500'));

      await provider.loadClients();

      expect(provider.error, contains('WASI 500'));
      expect(provider.isLoading, isFalse);
    });
  });

  group('ensureLoaded', () {
    test('serves the cached list without touching WASI', () async {
      when(mockCacheService.loadClients()).thenAnswer((_) async => CachedResult(
            data: [
              Client(idClientWasi: 1, firstName: 'Ana', lastName: 'Gómez'),
            ],
            isStale: false,
          ));

      await provider.ensureLoaded();

      expect(provider.clients.single.fullName, 'Ana Gómez');
      verifyNever(mockApiService.getClientsByProperty(any));
    });

    test('runs only once', () async {
      when(mockCacheService.loadClients()).thenAnswer((_) async => CachedResult(
            data: [
              Client(idClientWasi: 1, firstName: 'Ana', lastName: 'Gómez'),
            ],
            isStale: false,
          ));

      await provider.ensureLoaded();
      await provider.ensureLoaded();

      verify(mockCacheService.loadClients()).called(1);
    });

    test('paints an expired cache and refreshes in the background', () async {
      stubAdvisorFromCache();
      when(mockCacheService.loadClients()).thenAnswer((_) async => CachedResult(
            data: [
              Client(idClientWasi: 1, firstName: 'Ana', lastName: 'Gómez'),
            ],
            isStale: true,
          ));
      when(mockApiService.getClientsByProperty(advisorPropertyId))
          .thenAnswer((_) async => [
                wasiClient(id: 2, firstName: 'Beto', lastName: 'Ruiz'),
              ]);

      await provider.ensureLoaded();
      await pumpEventQueue();

      // El caché vencido se sirve de inmediato y la red lo reemplaza después.
      verify(mockApiService.getClientsByProperty(advisorPropertyId)).called(1);
      expect(provider.clients.single.idClientWasi, 2);
    });

    test('falls through to the network when the cache is empty', () async {
      stubAdvisorFromCache();
      when(mockCacheService.loadClients()).thenAnswer((_) async => null);
      when(mockApiService.getClientsByProperty(advisorPropertyId))
          .thenAnswer((_) async => [
                wasiClient(id: 1, firstName: 'Ana', lastName: 'Gómez'),
              ]);

      await provider.ensureLoaded();

      verify(mockApiService.getClientsByProperty(advisorPropertyId)).called(1);
      expect(provider.clients.single.idClientWasi, 1);
    });
  });

  group('createClient', () {
    test('throws when the advisor has no CRM property', () async {
      when(mockCacheService.loadAdvisorMap()).thenAnswer((_) async => null);

      expect(
        () => provider.createClient(firstName: 'Ana', cellPhone: '3001'),
        throwsException,
      );
    });

    test('creates in WASI, links the property and reloads', () async {
      stubAdvisorFromCache();
      when(mockApiService.createClient(
        firstName: anyNamed('firstName'),
        cellPhone: anyNamed('cellPhone'),
        lastName: anyNamed('lastName'),
        email: anyNamed('email'),
        query: anyNamed('query'),
      )).thenAnswer((_) async => 'C1');
      when(mockApiService.addPropertyToClient(any, any))
          .thenAnswer((_) async {});
      when(mockApiService.getClientsByProperty(advisorPropertyId))
          .thenAnswer((_) async => [
                wasiClient(id: 1, firstName: 'Ana', lastName: 'Gómez'),
              ]);

      await provider.createClient(
        firstName: 'Ana',
        cellPhone: '3001',
        lastName: 'Gómez',
      );

      verify(mockApiService.addPropertyToClient('C1', advisorPropertyId))
          .called(1);
      expect(provider.clients.single.fullName, 'Ana Gómez');
    });
  });

  group('updateClient', () {
    test('sends the editable fields and reloads', () async {
      stubAdvisorFromCache();
      when(mockApiService.updateClient(any, any)).thenAnswer((_) async {});
      when(mockApiService.getClientsByProperty(advisorPropertyId))
          .thenAnswer((_) async => []);

      await provider.updateClient(
        7,
        firstName: 'Ana',
        lastName: 'Gómez',
        email: null,
        query: 'busca apto',
        idClientStatus: 3,
      );

      verify(mockApiService.updateClient('7', {
        'first_name': 'Ana',
        'last_name': 'Gómez',
        'email': '',
        'query': 'busca apto',
        'id_client_status': 3,
      })).called(1);
    });
  });

  group('clear', () {
    test('resets state so ensureLoaded runs again', () async {
      when(mockCacheService.loadClients()).thenAnswer((_) async => CachedResult(
            data: [
              Client(idClientWasi: 1, firstName: 'Ana', lastName: 'Gómez'),
            ],
            isStale: false,
          ));
      await provider.ensureLoaded();
      expect(provider.clients, isNotEmpty);

      provider.clear();

      expect(provider.clients, isEmpty);
      expect(provider.error, isNull);
      expect(provider.advisorPropertyId, isNull);
      expect(provider.latestNoteFor(1), isNull);

      await provider.ensureLoaded();
      verify(mockCacheService.loadClients()).called(2);
    });
  });
}
