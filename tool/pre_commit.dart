import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

Future<void> main(List<String> args) async {
  if (args.any((arg) => !['--full', '--dry-run'].contains(arg))) {
    stderr.writeln('Usage: dart run tool/pre_commit.dart [--full] [--dry-run]');
    exitCode = 64;
    return;
  }
  try {
    final root = (await _git(['rev-parse', '--show-toplevel'])).trim();
    Directory.current = root;
    // Disable rename detection so both the deleted and added paths are seeds.
    final changed = _paths(
      await _git(['diff', '--cached', '--name-only', '--no-renames', '-z']),
    );
    final files = _paths(
      await _git([
        'ls-files',
        '--cached',
        '--others',
        '--exclude-standard',
        '-z',
      ]),
    );
    final sources = <String, String>{};
    for (final path in files.where((path) => path.endsWith('.dart'))) {
      final file = File(path);
      if (await file.exists()) sources[path] = await file.readAsString();
    }
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final package = (config['packages'] as List).cast<Map>().singleWhere(
      (package) =>
          configFile.uri
              .resolve(package['rootUri'] as String)
              .normalizePath() ==
          Directory.current.uri.normalizePath(),
    );
    final plan = planChecks(
      changed: changed,
      sources: sources,
      packageName: package['name'] as String,
      full: args.contains('--full'),
    );
    if (args.contains('--dry-run')) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(plan.toJson()));
      return;
    }
    stdout.writeln(plan.reason);
    for (final command in plan.commands) {
      stdout.writeln('> ${command.join(' ')}');
      final process = await Process.start(
        command.first,
        command.skip(1).toList(),
        mode: ProcessStartMode.inheritStdio,
      );
      final code = await process.exitCode;
      if (code != 0) {
        exitCode = code < 0 ? 128 - code : code;
        return;
      }
    }
  } catch (error) {
    stderr.writeln('Pre-commit checks failed: $error');
    exitCode = 1;
  }
}

Future<String> _git(List<String> args) async {
  final result = await Process.run('git', args);
  if (result.exitCode != 0) throw StateError(result.stderr.toString());
  return result.stdout as String;
}

Set<String> _paths(String output) =>
    output.split('\x00').where((path) => path.isNotEmpty).toSet();

/// A deterministic check plan, also used by dry-run and dependency graph tests.
class CheckPlan {
  const CheckPlan({
    required this.reason,
    required this.format,
    required this.analyze,
    required this.tests,
    this.full = false,
  });

  final String reason;
  final List<String> format;
  final List<String> analyze;
  final List<String> tests;
  final bool full;

  List<List<String>> get commands => [
    if (full) ['flutter', 'pub', 'get'],
    if (format.isNotEmpty)
      ['dart', 'format', '--output=none', '--set-exit-if-changed', ...format],
    if (analyze.isNotEmpty) ['flutter', 'analyze', '--no-pub', ...analyze],
    if (full || tests.isNotEmpty)
      ['flutter', 'test', '--no-pub', if (!full) ...tests],
  ];

  Map<String, Object> toJson() => {
    'full': full,
    'reason': reason,
    'format': format,
    'analyze': analyze,
    'tests': tests,
    'commands': commands,
  };
}

/// Follows reverse imports, exports, parts and all conditional import branches.
CheckPlan planChecks({
  required Set<String> changed,
  required Map<String, String> sources,
  required String packageName,
  bool full = false,
}) {
  CheckPlan all(String reason) => CheckPlan(
    reason: reason,
    format:
        sources.keys
            .where(
              (path) =>
                  path.startsWith('lib/') ||
                  path.startsWith('test/') ||
                  changed.contains(path),
            )
            .toList()
          ..sort(),
    analyze: const ['.'],
    tests: sources.keys.where(_isTest).toList()..sort(),
    full: true,
  );

  if (full) return all('Full checks requested.');
  if (changed.any(_requiresFullChecks)) {
    return all('Shared configuration, assets or check tooling changed.');
  }
  final seeds = changed.where((path) => path.endsWith('.dart')).toSet();
  if (seeds.isEmpty) {
    return const CheckPlan(
      reason:
          'No staged Dart or runtime configuration changes; checks skipped.',
      format: [],
      analyze: [],
      tests: [],
    );
  }

  final importers = <String, Set<String>>{};
  try {
    for (final entry in sources.entries) {
      final unit = parseString(content: entry.value, path: entry.key).unit;
      for (final directive in unit.directives) {
        final uris = <String?>[];
        if (directive is UriBasedDirective) {
          uris.add(directive.uri.stringValue);
        }
        if (directive is ImportDirective) {
          uris.addAll(
            directive.configurations.map((item) => item.uri.stringValue),
          );
        } else if (directive is ExportDirective) {
          uris.addAll(
            directive.configurations.map((item) => item.uri.stringValue),
          );
        }
        for (final uri in uris.nonNulls) {
          final dependency = _dependency(entry.key, uri, packageName);
          if (dependency != null) {
            importers.putIfAbsent(dependency, () => {}).add(entry.key);
          }
        }
      }
    }
  } catch (error) {
    return all('Dependency parsing failed; using full checks: $error');
  }

  final affected = {...seeds};
  final pending = seeds.toList();
  while (pending.isNotEmpty) {
    for (final importer in importers[pending.removeLast()] ?? <String>{}) {
      if (affected.add(importer)) pending.add(importer);
    }
  }
  // Flutter loads these implicitly rather than through a test's imports.
  final testConfigChanged = affected.any(
    (path) => path.split('/').last == 'flutter_test_config.dart',
  );
  final analyze = affected.where(sources.containsKey).toList()..sort();
  final tests =
      sources.keys
          .where(
            (path) =>
                _isTest(path) && (testConfigChanged || affected.contains(path)),
          )
          .toList()
        ..sort();
  return CheckPlan(
    reason:
        'Incremental checks: ${seeds.length} changed Dart files, '
        '${analyze.length} files to analyze, ${tests.length} test files.',
    format: seeds.where(sources.containsKey).toList()..sort(),
    analyze: analyze,
    tests: tests,
  );
}

bool _isTest(String path) =>
    path.startsWith('test/') && path.endsWith('_test.dart');

bool _requiresFullChecks(String path) {
  if ({
    'pubspec.yaml',
    'pubspec.lock',
    'analysis_options.yaml',
    'l10n.yaml',
    'dart_test.yaml',
    'build.yaml',
    'lefthook.yml',
    'lefthook-local.yml',
    '.metadata',
    '.fvmrc',
    'tool/pre_commit.dart',
    'test/pre_commit_test.dart',
  }.contains(path)) {
    return true;
  }
  return [
            'assets/',
            'config/',
            'android/',
            'ios/',
            'macos/',
            'linux/',
            'windows/',
            'web/',
            '.github/workflows/',
          ].any(path.startsWith) &&
          !path.endsWith('.md') ||
      path.endsWith('.arb');
}

String? _dependency(String importer, String value, String packageName) {
  final uri = Uri.parse(value);
  final String path;
  if (uri.scheme == 'package') {
    if (uri.pathSegments.firstOrNull != packageName) return null;
    path = 'lib/${uri.pathSegments.skip(1).join('/')}';
  } else if (!uri.hasScheme && !uri.hasAbsolutePath) {
    path = Uri(path: importer).resolveUri(uri).pathSegments.join('/');
  } else {
    return null;
  }
  return path.startsWith('../') ? null : path;
}
