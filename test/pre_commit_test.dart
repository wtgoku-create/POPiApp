import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/pre_commit.dart';

void main() {
  CheckPlan plan(Set<String> changed, Map<String, String> sources) =>
      planChecks(changed: changed, sources: sources, packageName: 'example');

  test(
    'follows transitive package imports and exports without unrelated tests',
    () {
      final result = plan(
        {'lib/model.dart'},
        {
          'lib/model.dart': 'class Model {}',
          'lib/barrel.dart': "export 'model.dart';",
          'lib/service.dart': "import 'package:example/barrel.dart';",
          'test/service_test.dart': "import '../lib/service.dart';",
          'test/unrelated_test.dart': 'void main() {}',
        },
      );

      expect(result.full, isFalse);
      expect(result.format, ['lib/model.dart']);
      expect(result.analyze, [
        'lib/barrel.dart',
        'lib/model.dart',
        'lib/service.dart',
        'test/service_test.dart',
      ]);
      expect(result.tests, ['test/service_test.dart']);
    },
  );

  test('covers parts, conditional imports and conditional exports', () {
    for (final directive in ['import', 'export']) {
      final result = plan(
        {'lib/native_part.dart'},
        {
          'lib/native.dart': "part 'native_part.dart';",
          'lib/native_part.dart': "part of 'native.dart';",
          'lib/stub.dart': '',
          'lib/service.dart':
              "$directive 'stub.dart' if (dart.library.io) 'native.dart';",
          'test/service_test.dart': "import '../lib/service.dart';",
        },
      );
      expect(result.tests, ['test/service_test.dart']);
    }
  });

  test('handles cycles and ignores comments and external package imports', () {
    final result = plan(
      {'lib/a.dart'},
      {
        'lib/a.dart': "import 'b.dart';",
        'lib/b.dart': "import 'a.dart';",
        'test/a_test.dart': "import '../lib/a.dart';",
        'test/unrelated_test.dart':
            "// import '../lib/a.dart';\nimport 'package:other/a.dart';",
      },
    );
    expect(result.tests, ['test/a_test.dart']);
  });

  test('resolves import paths containing spaces', () {
    final result = plan(
      {'lib/model with spaces.dart'},
      {
        'lib/model with spaces.dart': 'class Model {}',
        'test/model_test.dart': "import '../lib/model with spaces.dart';",
      },
    );
    expect(result.tests, ['test/model_test.dart']);
  });

  test('test-only changes run only that test; helpers include their users', () {
    final sources = {
      'test/support/helper.dart': 'void helper() {}',
      'test/a_test.dart': "import 'support/helper.dart';",
      'test/b_test.dart': "import 'support/helper.dart';",
      'test/c_test.dart': 'void main() {}',
    };
    expect(plan({'test/a_test.dart'}, sources).tests, ['test/a_test.dart']);
    expect(plan({'test/support/helper.dart'}, sources).tests, [
      'test/a_test.dart',
      'test/b_test.dart',
    ]);
  });

  test('deleted and renamed paths still find surviving importers', () {
    final result = plan(
      {'lib/old.dart', 'lib/new.dart'},
      {
        'lib/new.dart': 'class Model {}',
        'test/stale_test.dart': "import '../lib/old.dart';",
        'test/new_test.dart': "import '../lib/new.dart';",
      },
    );
    expect(result.format, ['lib/new.dart']);
    expect(result.analyze, [
      'lib/new.dart',
      'test/new_test.dart',
      'test/stale_test.dart',
    ]);
    expect(result.tests, ['test/new_test.dart', 'test/stale_test.dart']);
  });

  test('implicit Flutter test config dependencies affect all tests', () {
    final result = plan(
      {'test/support/cache.dart'},
      {
        'test/support/cache.dart': '',
        'test/flutter_test_config.dart': "import 'support/cache.dart';",
        'test/a_test.dart': 'void main() {}',
        'test/b_test.dart': 'void main() {}',
      },
    );
    expect(result.tests, ['test/a_test.dart', 'test/b_test.dart']);
    expect(result.full, isFalse);
    expect(result.deferredTests, isEmpty);
  });

  test('broad test initialization dependencies defer tests to CI', () {
    for (final changed in [
      {'test/support/cache.dart'},
      {'assets/shaders/fade.frag'},
    ]) {
      final result = plan(changed, {
        'test/support/cache.dart': "const shader = 'assets/shaders/fade.frag';",
        'test/flutter_test_config.dart': "import 'support/cache.dart';",
        for (var index = 0; index <= maxLocalTestFiles; index++)
          'test/page_${index}_test.dart': 'void main() {}',
      });
      expect(result.full, isFalse);
      expect(result.deferredTests, hasLength(maxLocalTestFiles + 1));
      expect(result.commands.any((command) => command[1] == 'test'), isFalse);
    }
  });

  test('config, native code and hook changes require full checks', () {
    for (final path in [
      'pubspec.yaml',
      'pubspec.lock',
      'analysis_options.yaml',
      'l10n.yaml',
      'dart_test.yaml',
      'test/flutter_test_config.dart',
      'config/env/development.json',
      'ios/Runner/AppDelegate.swift',
      'android/app/build.gradle.kts',
      'lefthook.yml',
      'tool/pre_commit.dart',
    ]) {
      final result = plan(
        {path},
        {'lib/model.dart': '', 'test/a_test.dart': ''},
      );
      expect(result.full, isTrue, reason: path);
      expect(result.commands.first.take(2), ['dart', 'format']);
      expect(
        result.resolveDependencies,
        {'pubspec.yaml', 'pubspec.lock'}.contains(path),
        reason: path,
      );
      expect(result.commands.last, ['flutter', 'test', '--no-pub']);
    }
  });

  test('asset-only changes follow consumers and their transitive tests', () {
    for (final asset in [
      'assets/images/photo.png',
      'assets/icons/a.svg',
      'assets/shaders/fade.frag',
    ]) {
      final result = plan(
        {asset},
        {
          'lib/resource.dart': "const asset = '$asset';",
          'lib/page.dart': "import 'resource.dart';",
          'test/page_test.dart': "import '../lib/page.dart';",
          'test/unrelated_test.dart': 'void main() {}',
        },
      );
      expect(result.full, isFalse, reason: asset);
      expect(result.resolveDependencies, isFalse);
      expect(result.format, isEmpty);
      expect(result.analyze, [
        'lib/page.dart',
        'lib/resource.dart',
        'test/page_test.dart',
      ]);
      expect(result.tests, ['test/page_test.dart']);
      expect(result.commands.last, [
        'flutter',
        'test',
        '--no-pub',
        'test/page_test.dart',
      ]);
    }
  });

  test('asset matching covers directory constants and interpolated paths', () {
    final result = plan(
      {'assets/icons/old.svg', 'assets/icons/new.svg'},
      {
        'lib/directory.dart': "const directory = 'assets/icons/';",
        'lib/interpolated.dart':
            r"String icon(String name) => 'assets/icons/$name.svg';",
        'test/directory_test.dart': "import '../lib/directory.dart';",
        'test/interpolated_test.dart': "import '../lib/interpolated.dart';",
        'test/deleted_asset_test.dart': "const path = 'assets/icons/old.svg';",
        'test/unrelated_test.dart':
            "// assets/icons/new.svg\nconst path = 'assets/icons-other/new.svg';",
      },
    );
    expect(result.full, isFalse);
    expect(result.tests, [
      'test/deleted_asset_test.dart',
      'test/directory_test.dart',
      'test/interpolated_test.dart',
    ]);
    expect(result.format, isEmpty);
  });

  test('mixed asset and Dart edits format only the changed Dart files', () {
    final result = plan(
      {'assets/shaders/fade.frag', 'lib/page.dart'},
      {
        'lib/backdrop.dart': "const shader = 'assets/shaders/fade.frag';",
        'lib/page.dart': "import 'backdrop.dart';",
        'test/page_test.dart': "import '../lib/page.dart';",
      },
    );
    expect(result.full, isFalse);
    expect(result.format, ['lib/page.dart']);
    expect(result.tests, ['test/page_test.dart']);
  });

  test(
    'unreferenced assets defer coverage to CI without full local checks',
    () {
      final result = plan(
        {'assets/images/new.png'},
        {'lib/page.dart': '', 'test/page_test.dart': ''},
      );
      expect(result.full, isFalse);
      expect(result.commands, isEmpty);
      expect(result.reason, contains('full coverage in CI'));
    },
  );

  test('widely used assets respect the local test limit', () {
    final result = plan(
      {'assets/icons/new.svg'},
      {
        'lib/icons.dart':
            r"String icon(String name) => 'assets/icons/$name.svg';",
        for (var index = 0; index <= maxLocalTestFiles; index++)
          'test/page_${index}_test.dart': "import '../lib/icons.dart';",
      },
    );
    expect(result.full, isFalse);
    expect(result.deferredTests, hasLength(maxLocalTestFiles + 1));
    expect(result.commands.single.take(2), ['flutter', 'analyze']);
  });

  test('ARB-only changes follow generated localization dependencies', () {
    final result = plan(
      {'lib/l10n/app_zh.arb'},
      {
        'lib/l10n/generated/app_localizations.dart':
            "import 'app_localizations_zh.dart';",
        'lib/l10n/generated/app_localizations_zh.dart': '',
        'lib/page.dart': "import 'l10n/generated/app_localizations.dart';",
        'test/page_test.dart': "import '../lib/page.dart';",
        'test/service_test.dart': 'void main() {}',
      },
    );
    expect(result.full, isFalse);
    expect(result.resolveDependencies, isFalse);
    expect(result.tests, ['test/page_test.dart']);
    expect(result.analyze, contains('lib/page.dart'));
  });

  test('missing localization output falls back to full checks', () {
    final result = plan({'lib/l10n/app_en.arb'}, {'test/a_test.dart': ''});
    expect(result.full, isTrue);
    expect(result.reason, contains('Localization output missing'));
  });

  test('broad impact defers tests to CI but retains format and analysis', () {
    final sources = {
      'lib/shared.dart': '',
      for (var index = 0; index <= maxLocalTestFiles; index++)
        'test/page_${index}_test.dart': "import '../lib/shared.dart';",
    };
    final result = plan({'lib/shared.dart'}, sources);
    expect(result.tests, hasLength(maxLocalTestFiles + 1));
    expect(result.deferredTests, result.tests);
    expect(result.commands.map((command) => command.take(2)), [
      ['dart', 'format'],
      ['flutter', 'analyze'],
    ]);
    expect(result.toJson()['deferredTests'], result.tests);

    final full = planChecks(
      changed: {'lib/shared.dart'},
      sources: sources,
      packageName: 'example',
      full: true,
    );
    expect(full.deferredTests, isEmpty);
    expect(full.resolveDependencies, isTrue);
    expect(full.commands.last, ['flutter', 'test', '--no-pub']);

    sources.remove('test/page_0_test.dart');
    final limited = plan({'lib/shared.dart'}, sources);
    expect(limited.tests, hasLength(maxLocalTestFiles));
    expect(limited.deferredTests, isEmpty);
    expect(limited.commands.last.take(2), ['flutter', 'test']);
  });

  test('empty staging and documentation changes skip all checks', () {
    for (final changed in [
      <String>{},
      {'README.md', '.github/workflows/README.md'},
    ]) {
      // Syntax errors in unrelated Dart files must not prevent a docs commit.
      final result = plan(changed, {'lib/broken.dart': 'class {'});
      expect(result.commands, isEmpty);
    }
  });

  test('uncovered Dart changes still format and analyze', () {
    final result = plan(
      {'lib/model.dart'},
      {'lib/model.dart': 'class Model {}'},
    );
    expect(result.format, ['lib/model.dart']);
    expect(result.analyze, ['lib/model.dart']);
    expect(result.tests, isEmpty);
    expect(result.commands.map((command) => command.take(2)), [
      ['dart', 'format'],
      ['flutter', 'analyze'],
    ]);
  });

  test('parser failures conservatively use full checks', () {
    final result = plan({'lib/broken.dart'}, {'lib/broken.dart': 'class {'});
    expect(result.full, isTrue);
    expect(result.reason, contains('Dependency parsing failed'));
  });

  test('full format preserves lib/test scope and includes staged tools', () {
    final result = plan(
      {'pubspec.yaml', 'tool/changed.dart'},
      {
        'lib/model.dart': '',
        'test/a_test.dart': '',
        'tool/changed.dart': '',
        'tool/unrelated.dart': '',
      },
    );
    expect(result.format, [
      'lib/model.dart',
      'test/a_test.dart',
      'tool/changed.dart',
    ]);
  });

  test(
    'reads only staged paths and handles filenames with spaces',
    () async {
      final root = Directory.current.path;
      final sandbox = await Directory.systemTemp.createTemp('pre_commit_test_');
      addTearDown(() => sandbox.delete(recursive: true));
      final environment = {...Platform.environment}
        ..removeWhere((key, value) => key.startsWith('GIT_'));

      Future<void> git(List<String> args) async {
        final result = await Process.run(
          'git',
          args,
          workingDirectory: sandbox.path,
          environment: environment,
          includeParentEnvironment: false,
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }

      Future<void> write(String path, String content) async {
        final file = File('${sandbox.path}/$path');
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
      }

      await git(['init', '--quiet']);
      await write('lib/model with spaces.dart', 'class Model {}');
      await write('lib/unstaged.dart', 'class Unstaged {}');
      await write(
        'test/model_test.dart',
        "import '../lib/model with spaces.dart';",
      );
      await write(
        '.dart_tool/package_config.json',
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'example', 'rootUri': '../', 'packageUri': 'lib/'},
          ],
        }),
      );
      await git(['add', '--', 'lib/model with spaces.dart']);
      final listed = await Process.run(
        'git',
        ['ls-files', '--cached', '--others', '--exclude-standard', '-z'],
        workingDirectory: sandbox.path,
        environment: environment,
        includeParentEnvironment: false,
      );
      expect(listed.stdout, contains('test/model_test.dart'));
      // Keep the real package config for loading the script, but use sandbox Git.
      final configFile = File('$root/.dart_tool/package_config.json');
      final config = jsonDecode(await configFile.readAsString()) as Map;
      final flutter = (config['packages'] as List).cast<Map>().singleWhere(
        (package) => package['name'] == 'flutter',
      );
      final flutterRoot = Directory.fromUri(
        configFile.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent;
      final dart =
          '${flutterRoot.path}/bin/cache/dart-sdk/bin/dart'
          '${Platform.isWindows ? '.exe' : ''}';
      final scriptArgs = [
        '--packages=$root/.dart_tool/package_config.json',
        '$root/tool/pre_commit.dart',
      ];
      final result = await Process.run(
        dart,
        [...scriptArgs, '--dry-run'],
        workingDirectory: sandbox.path,
        environment: environment,
        includeParentEnvironment: false,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final output = jsonDecode(result.stdout as String) as Map;
      expect(output['full'], isFalse);
      expect(output['format'], ['lib/model with spaces.dart']);
      expect(output['analyze'], [
        'lib/model with spaces.dart',
        'test/model_test.dart',
      ]);
      expect(output['tests'], ['test/model_test.dart']);

      if (!Platform.isWindows) {
        await write('bin/dart', '#!/bin/sh\nexit 23\n');
        final chmod = await Process.run('chmod', [
          '+x',
          '${sandbox.path}/bin/dart',
        ]);
        expect(chmod.exitCode, 0);
        final failed = await Process.run(
          dart,
          scriptArgs,
          workingDirectory: sandbox.path,
          environment: {
            ...environment,
            'PATH': '${sandbox.path}/bin:${Platform.environment['PATH']}',
          },
          includeParentEnvironment: false,
        );
        expect(failed.exitCode, 23, reason: failed.stderr.toString());
        expect(failed.stdout, contains('> dart format'));
        expect(failed.stderr, contains('Check failed'));
        expect(
          failed.stderr,
          contains("dart format 'lib/model with spaces.dart'"),
        );
        expect(failed.stderr, contains('stage the formatted files'));
        expect(failed.stdout, isNot(contains('> flutter analyze')));
        expect(failed.stdout, isNot(contains('> flutter test')));
      }

      await write('lib/l10n/app_en.arb', '{invalid JSON');
      await git(['add', '--', 'lib/l10n/app_en.arb']);
      final invalidArb = await Process.run(
        dart,
        [...scriptArgs, '--dry-run'],
        workingDirectory: sandbox.path,
        environment: environment,
        includeParentEnvironment: false,
      );
      expect(invalidArb.exitCode, 1);
      expect(
        invalidArb.stderr,
        contains('Invalid ARB file lib/l10n/app_en.arb'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
