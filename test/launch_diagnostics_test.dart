import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/diagnostics/launch_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('art.popi/launch_diagnostics');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('an unanswered native diagnostic cannot block startup', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final pending = Completer<void>();
    final received = Completer<MethodCall>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      received.complete(call);
      await pending.future;
      return null;
    });

    LaunchDiagnostics.mark(LaunchStage.preferencesReady);
    final call = await received.future;
    expect(call.method, 'mark');
    expect(call.arguments, 'preferences_ready');
    expect(pending.isCompleted, isFalse);
    pending.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('missing and failing native diagnostics do not break startup', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    LaunchDiagnostics.mark(LaunchStage.dartBindingReady);
    await Future<void>.delayed(Duration.zero);

    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    LaunchDiagnostics.mark(LaunchStage.firstFrame);
    await Future<void>.delayed(Duration.zero);
  });

  test('other native platforms do not invoke the diagnostic channel', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return null;
    });
    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.iOS) continue;
      debugDefaultTargetPlatformOverride = platform;
      LaunchDiagnostics.mark(LaunchStage.runApp);
    }
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);
  });

  test(
    'rebuilding a startup surface sends each checkpoint only once',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return null;
      });
      for (var i = 0; i < 100; i++) {
        LaunchDiagnostics.mark(LaunchStage.repositoryRestore);
      }
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    },
  );
}
