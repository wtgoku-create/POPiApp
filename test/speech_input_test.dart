import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/speech/speech_input.dart';
import 'package:popi_ai_app/shared/providers/speech_input_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('art.popi/speech_input');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Future<Object?> Function(MethodCall call)? handler;

  Future<void> sendEvent(Map<String, Object?> event) async {
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall('event', event)),
      (ByteData? _) {},
    );
  }

  setUp(() {
    calls.clear();
    handler = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler?.call(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('factory provider can be replaced with a fake factory', () {
    final fake = _FakeSpeechInput();
    final container = ProviderContainer(
      overrides: [speechInputFactoryProvider.overrideWithValue(() => fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(speechInputFactoryProvider)(), same(fake));
  });

  test(
    'native transport sends locale and routes cumulative snapshots',
    () async {
      final input = createSpeechInput();
      addTearDown(input.dispose);
      final results = <String>[];
      var done = 0;

      await input.start(
        locale: 'zh-CN',
        onResult: results.add,
        onError: (_) => fail('unexpected recognition error'),
        onDone: () => done++,
      );
      final start = calls.single;
      expect(start.method, 'start');
      final arguments = Map<Object?, Object?>.from(start.arguments as Map);
      expect(arguments['locale'], 'zh-CN');
      final sessionId = arguments['sessionId']! as String;

      await sendEvent({
        'sessionId': sessionId,
        'type': 'result',
        'text': '你好',
        'isFinal': false,
      });
      await sendEvent({
        'sessionId': sessionId,
        'type': 'result',
        'text': '你好世界',
        'isFinal': true,
      });
      await input.stop();
      expect(calls.last.method, 'stop');
      expect(results, ['你好', '你好世界']);
      expect(done, 0);

      await sendEvent({'sessionId': sessionId, 'type': 'done'});
      expect(done, 1);
    },
  );

  test('async native error is followed by done exactly once', () async {
    final input = createSpeechInput();
    addTearDown(input.dispose);
    final errors = <String>[];
    var done = 0;
    await input.start(
      locale: 'en-US',
      onResult: (_) {},
      onError: errors.add,
      onDone: () => done++,
    );
    final sessionId = (calls.single.arguments as Map)['sessionId']! as String;

    await sendEvent({
      'sessionId': sessionId,
      'type': 'error',
      'code': 'network',
    });
    await sendEvent({'sessionId': sessionId, 'type': 'done'});

    expect(errors, ['network']);
    expect(done, 1);
  });

  test(
    'start failure throws without invoking asynchronous callbacks',
    () async {
      handler = (call) async {
        if (call.method == 'start') {
          final sessionId = (call.arguments as Map)['sessionId']! as String;
          await sendEvent({
            'sessionId': sessionId,
            'type': 'error',
            'code': 'permission_denied',
          });
          throw PlatformException(code: 'permission_denied');
        }
        return null;
      };
      final input = createSpeechInput();
      addTearDown(input.dispose);
      final errors = <String>[];
      var done = 0;

      await expectLater(
        input.start(
          locale: 'en-US',
          onResult: (_) {},
          onError: errors.add,
          onDone: () => done++,
        ),
        throwsA(
          isA<SpeechInputException>().having(
            (error) => error.code,
            'code',
            'permission_denied',
          ),
        ),
      );
      expect(errors, isEmpty);
      expect(done, 0);
    },
  );

  test('cancel suppresses late callbacks for its session', () async {
    final input = createSpeechInput();
    addTearDown(input.dispose);
    final results = <String>[];
    var done = 0;
    await input.start(
      locale: 'en-US',
      onResult: results.add,
      onError: (_) {},
      onDone: () => done++,
    );
    final sessionId = (calls.single.arguments as Map)['sessionId']! as String;

    await input.cancel();
    expect(calls.last.method, 'cancel');
    await sendEvent({
      'sessionId': sessionId,
      'type': 'result',
      'text': 'stale',
    });
    await sendEvent({'sessionId': sessionId, 'type': 'done'});

    expect(results, isEmpty);
    expect(done, 0);
  });

  test('disposing an old instance does not detach a newer instance', () async {
    final oldInput = createSpeechInput();
    final newInput = createSpeechInput();
    addTearDown(newInput.dispose);
    await oldInput.start(
      locale: 'en-US',
      onResult: (_) {},
      onError: (_) {},
      onDone: () {},
    );
    oldInput.dispose();
    final newerResults = <String>[];
    await newInput.start(
      locale: 'en-US',
      onResult: newerResults.add,
      onError: (_) {},
      onDone: () {},
    );
    final newerStart = calls.lastWhere((call) => call.method == 'start');
    final newerSessionId =
        (newerStart.arguments as Map)['sessionId']! as String;

    await sendEvent({
      'sessionId': newerSessionId,
      'type': 'result',
      'text': 'still listening',
    });

    expect(newerResults, ['still listening']);
  });

  test(
    'cancel wins a late start response and prevents stale callbacks',
    () async {
      final startReply = Completer<void>();
      handler = (call) async {
        if (call.method == 'start') await startReply.future;
        return null;
      };
      final input = createSpeechInput();
      addTearDown(input.dispose);
      final results = <String>[];
      final start = input.start(
        locale: 'en-US',
        onResult: results.add,
        onError: (_) {},
        onDone: () {},
      );
      await Future<void>.delayed(Duration.zero);
      final sessionId = (calls.single.arguments as Map)['sessionId']! as String;
      await input.cancel();
      startReply.complete();

      await expectLater(
        start,
        throwsA(
          isA<SpeechInputException>().having(
            (error) => error.code,
            'code',
            'cancelled',
          ),
        ),
      );
      await sendEvent({
        'sessionId': sessionId,
        'type': 'result',
        'text': 'stale',
      });
      expect(results, isEmpty);
    },
  );
}

final class _FakeSpeechInput implements SpeechInput {
  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}

  @override
  Future<void> start({
    required String locale,
    required void Function(String text) onResult,
    required void Function(String code) onError,
    required void Function() onDone,
  }) async {}

  @override
  Future<void> stop() async {}
}
