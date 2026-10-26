import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/flutter_env.dart' show loadEnvironmentConfig;

void main() {
  late Directory directory;
  late File base;
  late File local;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flutter-env-test-');
    base = File('${directory.path}/development.json');
    local = File('${directory.path}/development.local.json');
    await base.writeAsString(
      jsonEncode({
        'API_BASE_URL': 'https://gateway.example',
        'AGENT_API_BASE_URL': 'https://gateway.example',
        'RUNTIME_API_BASE_URL': 'https://gateway.example',
        'WECHAT_APP_ID': 'wxOriginal',
        'API_ENABLE_LOGGING': false,
      }),
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('public environment loads unchanged without local overrides', () async {
    final config = await loadEnvironmentConfig(base);
    expect(config['RUNTIME_API_BASE_URL'], 'https://gateway.example');
    expect(config['API_ENABLE_LOGGING'], isFalse);
  });

  test(
    'local addresses override public defaults and preserve native settings',
    () async {
      await local.writeAsString(
        jsonEncode({
          'API_BASE_URL': 'http://192.168.1.100:8080',
          'AGENT_API_BASE_URL': 'http://192.168.1.100:8080',
          'RUNTIME_API_BASE_URL': 'http://192.168.1.100:7801',
          'API_ENABLE_LOGGING': true,
        }),
      );
      final config = await loadEnvironmentConfig(base);
      expect(config['API_BASE_URL'], 'http://192.168.1.100:8080');
      expect(config['AGENT_API_BASE_URL'], 'http://192.168.1.100:8080');
      expect(config['RUNTIME_API_BASE_URL'], 'http://192.168.1.100:7801');
      expect(config['WECHAT_APP_ID'], 'wxOriginal');
      expect(config['API_ENABLE_LOGGING'], isTrue);
      expect(await loadEnvironmentConfig(local), config);
    },
  );

  test('explicit local files also work without a public sibling', () async {
    await base.delete();
    await local.writeAsString(jsonEncode({'APP_ENV': 'custom'}));
    expect(await loadEnvironmentConfig(local), {'APP_ENV': 'custom'});
  });

  test(
    'malformed local configuration fails instead of silently using defaults',
    () async {
      await local.writeAsString('{');
      await expectLater(loadEnvironmentConfig(base), throwsFormatException);
    },
  );

  test('local configuration must be a JSON object', () async {
    await local.writeAsString('[]');
    await expectLater(loadEnvironmentConfig(base), throwsFormatException);
  });
}
