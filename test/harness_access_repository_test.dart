import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/features/demo/data/harness_access_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24, 6);

  test('accepts only the explicit 303 secure Harness cookie', () async {
    final repository = HarnessAccessRepository(
      _LoginApi(
        _response(
          303,
          headers: {
            'location': ['/'],
            'set-cookie': [
              '__Host-popi-test=secret-cookie; Max-Age=3600; Path=/; Secure; HttpOnly; SameSite=Strict',
            ],
          },
        ),
      ),
      origin: 'https://harness.example',
      now: () => now,
      createCacheNamespace: () => '123e4567-e89b-42d3-a456-426614174000',
    );

    final session = await repository.signIn(
      username: 'tester',
      password: 'not-persisted',
    );

    expect(session.cookieHeader, '__Host-popi-test=secret-cookie');
    expect(session.origin, 'https://harness.example');
    expect(session.expiresAt, now.add(const Duration(hours: 1)));
    expect(session.toString(), isNot(contains('secret-cookie')));
  });

  test('does not treat a 302 redirect as successful login', () async {
    final repository = _repository(_response(302), now);

    await expectLater(
      repository.signIn(username: 'tester', password: 'password'),
      throwsA(
        isA<HarnessAccessException>().having(
          (error) => error.type,
          'type',
          HarnessAccessExceptionType.invalidResponse,
        ),
      ),
    );
  });

  test('maps invalid credentials and rate limits to typed failures', () async {
    for (final response in [
      _response(400),
      _response(
        303,
        headers: {
          'location': ['/login?error=invalid'],
        },
      ),
    ]) {
      final invalid = _repository(response, now);
      await expectLater(
        invalid.signIn(username: 'tester', password: 'wrong'),
        throwsA(
          isA<HarnessAccessException>().having(
            (error) => error.invalid,
            'invalid',
            isTrue,
          ),
        ),
      );
    }

    final limited = _repository(
      _response(
        429,
        headers: {
          'retry-after': ['90'],
        },
      ),
      now,
    );
    await expectLater(
      limited.signIn(username: 'tester', password: 'password'),
      throwsA(
        isA<HarnessAccessException>()
            .having((error) => error.rateLimited, 'rateLimited', isTrue)
            .having(
              (error) => error.retryAfterSeconds,
              'retryAfterSeconds',
              90,
            ),
      ),
    );
  });

  test(
    'rejects cookies missing required security attributes or expiry',
    () async {
      for (final cookie in [
        '__Host-popi-test=value; Max-Age=3600; Path=/; HttpOnly',
        '__Host-popi-test=value; Max-Age=3600; Path=/; Secure',
        '__Host-popi-test=value; Max-Age=3600; Path=/nested; Secure; HttpOnly',
        '__Host-popi-test=value; Max-Age=3600; Path=/; Domain=harness.example; Secure; HttpOnly',
        '__Host-popi-test=value; Path=/; Secure; HttpOnly',
        '__Host-popi-test=value; Max-Age=0; Path=/; Secure; HttpOnly',
      ]) {
        final repository = _repository(
          _response(
            303,
            headers: {
              'location': ['/'],
              'set-cookie': [cookie],
            },
          ),
          now,
        );
        await expectLater(
          repository.signIn(username: 'tester', password: 'password'),
          throwsA(isA<HarnessAccessException>()),
          reason: cookie,
        );
      }
    },
  );
}

HarnessAccessRepository _repository(Response<Object?> response, DateTime now) {
  return HarnessAccessRepository(
    _LoginApi(response),
    origin: 'https://harness.example',
    now: () => now,
    createCacheNamespace: () => '123e4567-e89b-42d3-a456-426614174000',
  );
}

Response<Object?> _response(
  int statusCode, {
  Map<String, List<String>> headers = const {},
}) => Response<Object?>(
  requestOptions: RequestOptions(path: '/login'),
  statusCode: statusCode,
  headers: Headers.fromMap(headers),
);

class _LoginApi extends NetworkAgentApi {
  _LoginApi(this.response)
    : super(Dio(BaseOptions(baseUrl: 'https://harness.example')));

  final Response<Object?> response;

  @override
  Future<Response<Object?>> signInHarness({
    required String username,
    required String password,
    CancelToken? cancelToken,
  }) async => response;
}
