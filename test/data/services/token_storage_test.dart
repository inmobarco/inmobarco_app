import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobarco_app/data/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TokenStorage.resetForTest();
  });

  test('starts without session', () async {
    expect(await TokenStorage.hasSession(), isFalse);
    expect(await TokenStorage.accessToken, isNull);
    expect(await TokenStorage.refreshToken, isNull);
  });

  test('save replaces both tokens and survives a restart', () async {
    await TokenStorage.save(accessToken: 'a1', refreshToken: 'r1');
    await TokenStorage.save(accessToken: 'a2', refreshToken: 'r2');

    TokenStorage.resetForTest();

    expect(await TokenStorage.accessToken, 'a2');
    expect(await TokenStorage.refreshToken, 'r2');
    expect(await TokenStorage.hasSession(), isTrue);
  });

  test('clear removes both tokens from disk', () async {
    await TokenStorage.save(accessToken: 'a1', refreshToken: 'r1');
    await TokenStorage.clear();

    TokenStorage.resetForTest();

    expect(await TokenStorage.hasSession(), isFalse);
  });

  test('migrates the access token stored by previous versions', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'legacy-jwt'});

    expect(await TokenStorage.accessToken, 'legacy-jwt');
    expect(await TokenStorage.refreshToken, isNull);
    expect(await TokenStorage.hasSession(), isTrue);

    // Ya no queda en SharedPreferences, que no está cifrado.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);

    TokenStorage.resetForTest();
    expect(await TokenStorage.accessToken, 'legacy-jwt');
  });
}
