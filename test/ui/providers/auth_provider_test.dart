import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inmobarco_app/ui/providers/auth_provider.dart';
import 'package:inmobarco_app/data/services/cache_service.dart';

@GenerateMocks([CacheService])
import 'auth_provider_test.mocks.dart';

void main() {
  late AuthProvider provider;
  late MockCacheService mockCacheService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockCacheService = MockCacheService();
    provider = AuthProvider(cacheService: mockCacheService);
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

      when(mockCacheService.clearAuthSession()).thenAnswer((_) async {});

      await provider.logout();

      expect(provider.isLoggedIn, isFalse);
      expect(provider.user, isNull);
      verify(mockCacheService.clearAuthSession()).called(1);
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
