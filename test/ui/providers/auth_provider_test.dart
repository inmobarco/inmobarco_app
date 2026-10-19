import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inmobarco_app/ui/providers/auth_provider.dart';
import 'package:inmobarco_app/data/services/cache_service.dart';
import 'package:inmobarco_app/data/services/token_storage.dart';

@GenerateMocks([CacheService])
import 'auth_provider_test.mocks.dart';

void main() {
  late AuthProvider provider;
  late MockCacheService mockCacheService;
  late List<String> revoked;

  void givenTokens(Map<String, String> values) {
    FlutterSecureStorage.setMockInitialValues(values);
    TokenStorage.resetForTest();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    givenTokens({'access_token': 'jwt-abc', 'refresh_token': 'refresh-abc'});
    mockCacheService = MockCacheService();
    revoked = [];
    provider = AuthProvider(
      cacheService: mockCacheService,
      revokeSession: (token) async => revoked.add(token),
    );
  });

  group('initial state', () {
    test('starts logged out', () {
      expect(provider.isLoggedIn, isFalse);
      expect(provider.user, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.displayName, '');
      expect(provider.fullName, '');
    });
  });

  group('loadSession', () {
    test('loads user from cached session', () async {
      when(mockCacheService.loadAuthSession()).thenAnswer((_) async => {
            'username': 'jbarco',
            'role': 'admin',
            'first_name': 'Juan',
            'last_name': 'Barco',
            'phone': '300123',
          });

      await provider.loadSession();

      expect(provider.isLoggedIn, isTrue);
      expect(provider.user!.username, 'jbarco');
      expect(provider.displayName, 'Juan');
      expect(provider.fullName, 'Juan Barco');
    });

    test('stays logged out when no cached session', () async {
      when(mockCacheService.loadAuthSession()).thenAnswer((_) async => null);

      await provider.loadSession();

      expect(provider.isLoggedIn, isFalse);
    });

    test('drops a cached profile that has no tokens', () async {
      givenTokens({});
      when(mockCacheService.loadAuthSession())
          .thenAnswer((_) async => {'username': 'jbarco'});
      when(mockCacheService.clearOnLogout()).thenAnswer((_) async {});

      await provider.loadSession();

      expect(provider.isLoggedIn, isFalse);
      verify(mockCacheService.clearOnLogout()).called(1);
    });

    test('handles cache error gracefully', () async {
      when(mockCacheService.loadAuthSession()).thenThrow(Exception('Corrupted'));

      await provider.loadSession();

      expect(provider.isLoggedIn, isFalse);
      // Should not throw
    });
  });

  group('logout', () {
    test('clears session and user', () async {
      // First, simulate a logged-in state
      when(mockCacheService.loadAuthSession()).thenAnswer((_) async => {
            'username': 'jbarco',
            'role': 'admin',
            'first_name': 'Juan',
            'last_name': 'Barco',
          });
      await provider.loadSession();
      expect(provider.isLoggedIn, isTrue);

      when(mockCacheService.clearOnLogout()).thenAnswer((_) async {});

      await provider.logout();

      expect(provider.isLoggedIn, isFalse);
      expect(provider.user, isNull);
      // Un solo barrido: lo del asesor se va (clientes, bitácoras,
      // residenciales, borrador, perfil, rutero) y se conservan propiedades,
      // ciudades y filtros, que es lo que la app muestra sin sesión.
      verify(mockCacheService.clearOnLogout()).called(1);
    });

    test('drops both tokens and revokes the refresh token', () async {
      when(mockCacheService.clearOnLogout()).thenAnswer((_) async {});

      await provider.logout();

      expect(await TokenStorage.hasSession(), isFalse);
      expect(revoked, ['refresh-abc']);
    });

    test('a session already ended by the API has nothing to revoke', () async {
      givenTokens({});
      when(mockCacheService.clearOnLogout()).thenAnswer((_) async {});

      await provider.logout();

      expect(revoked, isEmpty);
    });
  });

  group('clearError', () {
    test('clears error state', () {
      // We can't easily trigger an error without mocking AuthService (static),
      // but we can verify the method works on the provider.
      provider.clearError();
      expect(provider.error, isNull);
    });
  });
}
