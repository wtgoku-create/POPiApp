import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/web_login_progress.dart';
import 'package:popi_ai_app/features/auth/data/web_social_auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/web_social_login.dart';

void main() {
  late Dio dio;
  late _Tokens storage;
  late WebSocialAuthRepository repository;
  late List<RequestOptions> requests;
  Map<String, dynamic> response = {};
  bool failProfile = false;
  Completer<void>? profileWait;

  setUp(() {
    requests = [];
    storage = _Tokens();
    failProfile = false;
    profileWait = null;
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          if (options.path.endsWith('/info')) {
            await profileWait?.future;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'status': failProfile ? '9999' : '0000',
                  'data': {
                    'user': {'id': 101, 'nickname': 'Browser user'},
                  },
                },
              ),
            );
          } else {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: response,
              ),
            );
          }
        },
      ),
    );
    repository = WebSocialAuthRepository(NetworkApi(dio), storage);
    addTearDown(() => dio.close(force: true));
  });

  for (final douyin in [false, true]) {
    test(
      'browser challenge and polling use website contracts: $douyin',
      () async {
        response = {
          'status': '0000',
          'data': douyin
              ? {
                  'state': 'oauth-state',
                  'authUrl': 'https://open.douyin.com/oauth',
                  'expireSeconds': 60,
                }
              : {'scene': 'wx-scene', 'qrUrl': '/media/qr.png'},
        };
        final challenge = await repository.createChallenge(douyin: douyin);
        expect(challenge.state, douyin ? 'oauth-state' : 'wx-scene');
        expect(
          requests.last.path,
          douyin
              ? '/api_client/auth/douyinQrCode'
              : '/api_client/auth/wxghQrCode',
        );
        response = {
          'status': '0000',
          'data': {'status': 'waiting'},
        };
        expect(
          await repository.check(
            douyin: douyin,
            state: challenge.state,
            cancelToken: CancelToken(),
          ),
          isA<WebSocialWaiting>(),
        );
        expect(requests.last.method, 'GET');
        expect(
          requests.last.path,
          douyin
              ? '/api_client/auth/checkDouyinLogin'
              : '/api_client/auth/checkWxghLogin',
        );
        expect(requests.last.queryParameters, {
          douyin ? 'state' : 'sceneCode': challenge.state,
        });
        expect(storage.value, isNull);
      },
    );

    test('browser phone registration uses correct endpoint: $douyin', () async {
      response = {'token': 'browser-token'};
      final user = await repository.registerByPhone(
        douyin: douyin,
        registerToken: 'registration',
        phone: '13800138000',
        code: '123456',
      );
      expect(user.id, '101');
      expect(storage.value, 'browser-token');
      expect(
        requests.first.path,
        douyin
            ? '/api_client/auth/douyinRegisterByPhone'
            : '/api_client/auth/wxghRegisterByPhone',
      );
      expect(requests.first.data, {
        'registerToken': 'registration',
        'phone': '13800138000',
        'code': '123456',
        'inviteCode': '',
      });
    });
  }

  test('first login needs phone binding without creating a session', () async {
    response = {'needBindPhone': true, 'registerToken': 'registration'};
    final result = await repository.check(
      douyin: false,
      state: 'scene',
      cancelToken: CancelToken(),
    );
    expect(
      (result as WebSocialPhoneBindingRequired).registerToken,
      'registration',
    );
    expect(storage.value, isNull);
    response = {'needBindPhone': true};
    await expectLater(
      repository.check(
        douyin: false,
        state: 'scene',
        cancelToken: CancelToken(),
      ),
      throwsFormatException,
    );
  });

  test(
    'successful polling restores user and failed profile removes token',
    () async {
      response = {
        'status': '0000',
        'data': {'token': 'browser-token'},
      };
      final result = await repository.check(
        douyin: true,
        state: 'state',
        cancelToken: CancelToken(),
      );
      expect((result as WebSocialSignInSucceeded).user.id, '101');
      expect(storage.value, 'browser-token');
      failProfile = true;
      await expectLater(
        repository.check(
          douyin: true,
          state: 'state',
          cancelToken: CancelToken(),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(storage.value, isNull);
    },
  );

  test('canceled profile request cannot complete a browser login', () async {
    response = {'token': 'browser-token'};
    profileWait = Completer<void>();
    final cancel = CancelToken();
    final pending = repository.check(
      douyin: false,
      state: 'scene',
      cancelToken: cancel,
    );
    final expectation = expectLater(pending, throwsA(isA<DioException>()));
    while (requests.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    cancel.cancel();
    profileWait!.complete();
    await expectation;
    expect(storage.value, isNull);
  });

  test('backend failures are not treated as waiting', () async {
    response = {'status': '9999', 'message': 'Expired'};
    await expectLater(
      repository.check(
        douyin: false,
        state: 'scene',
        cancelToken: CancelToken(),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'pending OAuth flow restores, validates state, expires and clears',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PreferencesStorage(await SharedPreferences.getInstance());
      final progress = WebLoginProgress(storage);
      expect(progress.restore(), isNull);
      await progress.save(
        state: 'state',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      expect(
        WebLoginProgress(storage).restore(callbackState: 'state')?.state,
        'state',
      );
      expect(progress.restore(callbackState: 'different'), isNull);
      await progress.save(
        state: 'state',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        registerToken: 'registration',
      );
      expect(progress.restore()?.registerToken, 'registration');
      await progress.save(
        state: 'state',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(progress.restore(), isNull);
      await progress.clear();
      expect(progress.restore(), isNull);
      await storage.setString('popibot.douyin.pending-login', '{broken');
      expect(progress.restore(), isNull);
    },
  );
}

class _Tokens implements TokenStorage {
  String? value;
  @override
  Future<String?> readAccessToken() async => value;
  @override
  Future<void> writeAccessToken(String token) async => value = token;
  @override
  Future<void> deleteAccessToken() async => value = null;
}
