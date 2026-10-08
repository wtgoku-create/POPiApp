import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/auth/data/douyin_login_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('art.popi/douyin_login');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'requests native authorization with configured key and correlated state',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'authorize');
        final arguments = call.arguments as Map;
        expect(arguments['clientKey'], 'mobile-client-key');
        expect(arguments['universalLink'], 'https://app.popi.art/WeChat/');
        expect(arguments['state'], isNotEmpty);
        return {
          'status': 'authorized',
          'code': ' code ',
          'state': arguments['state'],
        };
      });
      final result = await const DouyinLoginService(
        clientKey: 'mobile-client-key',
      ).authorize();
      expect(result.status, DouyinAuthorizationStatus.authorized);
      expect(result.code, 'code');
    },
  );

  test('rejects a response from another authorization attempt', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'status': 'authorized',
        'code': 'code',
        'state': 'different-state',
      },
    );
    expect(
      (await const DouyinLoginService().authorize()).status,
      DouyinAuthorizationStatus.failed,
    );
  });

  for (final status in ['canceled', 'unavailable', 'failed']) {
    test(
      'maps native $status without returning an authorization code',
      () async {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => {'status': status},
        );
        final result = await const DouyinLoginService().authorize();
        expect(result.status.name, status);
        expect(result.code, isNull);
      },
    );
  }

  test('rejects successful callbacks without a code', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'status': 'authorized',
        'code': '',
        'state': (call.arguments as Map)['state'],
      },
    );
    expect(
      (await const DouyinLoginService().authorize()).status,
      DouyinAuthorizationStatus.failed,
    );
  });

  test('missing native plugin reports unavailable', () async {
    expect(
      (await const DouyinLoginService().authorize()).status,
      DouyinAuthorizationStatus.unavailable,
    );
  });

  test('platform errors report authorization failure', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'SDK_ERROR'),
    );
    expect(
      (await const DouyinLoginService().authorize()).status,
      DouyinAuthorizationStatus.failed,
    );
  });

  test(
    'timeout clears the matching native request and permits another attempt',
    () async {
      final pending = Completer<Object?>();
      String? pendingState;
      var canceled = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'authorize') {
          if (canceled) {
            return {'status': 'canceled'};
          }
          pendingState = (call.arguments as Map)['state'] as String;
          return pending.future;
        }
        expect(call.method, 'cancelAuthorization');
        expect((call.arguments as Map)['state'], pendingState);
        canceled = true;
        pending.complete({'status': 'canceled'});
        return null;
      });
      const service = DouyinLoginService(timeout: Duration(milliseconds: 10));
      expect(
        (await service.authorize()).status,
        DouyinAuthorizationStatus.failed,
      );
      expect(canceled, isTrue);
      expect(
        (await service.authorize()).status,
        DouyinAuthorizationStatus.canceled,
      );
    },
  );

  test('empty key and unsupported platforms never invoke the SDK', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => fail('SDK must not be invoked'),
    );
    expect(
      (await const DouyinLoginService(clientKey: '').authorize()).status,
      DouyinAuthorizationStatus.unavailable,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(
      (await const DouyinLoginService().authorize()).status,
      DouyinAuthorizationStatus.unavailable,
    );
  });
}
