import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobarco_app/data/services/auth_interceptor.dart';
import 'package:inmobarco_app/data/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend falso con las reglas de la API: rota el par en cada refresh y
/// rechaza el refresh token ya usado.
class _FakeBackend implements HttpClientAdapter {
  String validAccess = 'access-server';
  String validRefresh = 'refresh-1';
  int generation = 1;
  int refreshCalls = 0;
  bool refreshOffline = false;

  /// Detail del 401 para tokens que no son el vigente.
  String rejectDetail = 'token_expired';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshOffline) {
        throw DioException.connectionError(
            requestOptions: options, reason: 'offline');
      }
      final body = options.data as Map;
      if (body['refresh_token'] != validRefresh) {
        return _json(401, {'detail': 'refresh_invalid'});
      }
      generation++;
      validAccess = 'access-$generation';
      validRefresh = 'refresh-$generation';
      return _json(200, {
        'status': 'ok',
        'access_token': validAccess,
        'refresh_token': validRefresh,
        'token_type': 'bearer',
      });
    }

    if (options.headers['Authorization'] == 'Bearer $validAccess') {
      return _json(200, {'path': options.path});
    }
    return _json(401, {'detail': rejectDetail});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeBackend backend;
  late Dio dio;
  late int sessionEndedCalls;

  Future<void> givenTokens(Map<String, String> values) async {
    FlutterSecureStorage.setMockInitialValues(values);
    TokenStorage.resetForTest();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await givenTokens({
      'access_token': 'access-expired',
      'refresh_token': 'refresh-1',
    });
    backend = _FakeBackend();
    sessionEndedCalls = 0;

    final options = BaseOptions(baseUrl: 'http://api.test');
    final plainDio = Dio(options)..httpClientAdapter = backend;
    dio = Dio(options)
      ..httpClientAdapter = backend
      ..interceptors.add(AuthInterceptor(
        plainDio: plainDio,
        onSessionEnded: () => sessionEndedCalls++,
      ));
  });

  test('sends the stored access token', () async {
    await givenTokens({'access_token': 'access-server', 'refresh_token': 'r'});

    final response = await dio.get('/appointments');

    expect(response.statusCode, 200);
    expect(backend.refreshCalls, 0);
  });

  test('renews an expired token and retries without the caller noticing',
      () async {
    final response = await dio.get('/appointments');

    expect(response.data, {'path': '/appointments'});
    expect(backend.refreshCalls, 1);
    expect(await TokenStorage.accessToken, 'access-2');
    expect(await TokenStorage.refreshToken, 'refresh-2');
    expect(sessionEndedCalls, 0);
  });

  test('concurrent expired requests share a single refresh', () async {
    final responses = await Future.wait([
      for (var i = 0; i < 5; i++) dio.get('/r$i'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(backend.refreshCalls, 1);
    expect(sessionEndedCalls, 0);
    expect(await TokenStorage.refreshToken, 'refresh-2');
  });

  test('a rejected refresh ends the session', () async {
    backend.validRefresh = 'revoked-elsewhere';

    await expectLater(
      dio.get('/appointments'),
      throwsA(isA<DioException>()
          .having((e) => e.response?.statusCode, 'status', 401)),
    );

    expect(sessionEndedCalls, 1);
    expect(await TokenStorage.hasSession(), isFalse);
  });

  test('token_invalid ends the session without trying to refresh', () async {
    backend.rejectDetail = 'token_invalid';

    await expectLater(dio.get('/appointments'), throwsA(isA<DioException>()));

    expect(backend.refreshCalls, 0);
    expect(sessionEndedCalls, 1);
    expect(await TokenStorage.hasSession(), isFalse);
  });

  test('user_inactive ends the session', () async {
    backend.rejectDetail = 'user_inactive';

    await expectLater(dio.get('/appointments'), throwsA(isA<DioException>()));

    expect(sessionEndedCalls, 1);
  });

  test('a refresh without network keeps the session', () async {
    backend.refreshOffline = true;

    await expectLater(dio.get('/appointments'), throwsA(isA<DioException>()));

    expect(sessionEndedCalls, 0);
    expect(await TokenStorage.refreshToken, 'refresh-1');
  });

  test('a migrated session without refresh token ends when it expires',
      () async {
    await givenTokens({'access_token': 'access-expired'});

    await expectLater(dio.get('/appointments'), throwsA(isA<DioException>()));

    expect(backend.refreshCalls, 0);
    expect(sessionEndedCalls, 1);
  });

  test('a 401 without session does not report a session end', () async {
    await givenTokens({});
    backend.rejectDetail = 'token_invalid';

    await expectLater(dio.get('/appointments'), throwsA(isA<DioException>()));

    expect(sessionEndedCalls, 0);
  });

  test('non-auth errors pass through untouched', () async {
    await givenTokens({'access_token': 'access-server', 'refresh_token': 'r'});
    final response = await dio.get('/ok');
    expect(response.statusCode, 200);

    backend.validAccess = 'other';
    backend.rejectDetail = 'something_else';
    await expectLater(dio.get('/appointments'), throwsA(isA<DioException>()));
    expect(backend.refreshCalls, 0);
    expect(sessionEndedCalls, 0);
  });
}
