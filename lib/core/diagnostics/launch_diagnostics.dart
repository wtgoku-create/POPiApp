import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Fixed startup checkpoints; never send account, request, or message data.
enum LaunchStage {
  dartBindingReady('dart_binding_ready'),
  preferencesReady('preferences_ready'),
  frostedReady('frosted_ready'),
  runApp('run_app'),
  firstFrame('first_frame'),
  accessRestore('access_restore'),
  accessLogin('access_login'),
  accessAuthenticated('access_authenticated'),
  repositoryRestore('repository_restore'),
  repositoryReady('repository_ready');

  const LaunchStage(this.label);

  final String label;
}

/// Optional device-local diagnostics must never delay or fail application startup.
abstract final class LaunchDiagnostics {
  static const _channel = MethodChannel('art.popi/launch_diagnostics');
  static final _reported = <LaunchStage>{};

  static void mark(LaunchStage stage) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!_reported.add(stage)) return;
    unawaited(_send(stage));
  }

  static Future<void> _send(LaunchStage stage) async {
    try {
      await _channel.invokeMethod<void>('mark', stage.label);
    } on Object {
      // Older native hosts and unavailable diagnostics must remain usable.
    }
  }
}
