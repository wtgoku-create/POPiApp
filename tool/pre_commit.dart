import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

Future<void> main(List<String> args) async {
  final total = Stopwatch()..start();
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
    for (final path in changed.where((path) => path.endsWith('.arb'))) {
      final file = File(path);
      if (await file.exists()) {
        try {
          if (jsonDecode(await file.readAsString()) is! Map) {
            throw const FormatException('Expected a JSON object');
          }
        } on FormatException catch (error) {
          throw FormatException('Invalid ARB file $path: $error');
        }
      }
    }
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
    if (plan.deferredTests.isNotEmpty) {
      stdout.writeln(
        '${plan.deferredTests.length} affected test files exceed the local '
        'limit of $maxLocalTestFiles; the full suite will run in CI.\n'
        'Run dart run tool/pre_commit.dart --full to check everything locally.',
      );
    }
    final commands = plan.commands;
    for (var index = 0; index < commands.length; index++) {
      final command = commands[index];
      stdout.writeln(
        '[${index + 1}/${commands.length}] > ${command.join(' ')}',
      );
      final elapsed = Stopwatch()..start();
      final process = await Process.start(
        command.first,
        command.skip(1).toList(),
        mode: ProcessStartMode.inheritStdio,
      );
      final code = await process.exitCode;
      if (code != 0) {
        stderr.writeln(
          'Check failed after ${elapsed.elapsed.inSeconds}s '
          '(exit $code): ${command.take(2).join(' ')}',
        );
        if (command.first == 'dart' && command[1] == 'format') {
          stderr.writeln(
            'The format check does not modify files. Run:\n'
            '  dart format ${plan.format.map(_shellQuote).join(' ')}\n'
            'Then review and stage the formatted files before committing again.',
          );
        }
        exitCode = code < 0 ? 128 - code : code;
        return;
      }
      stdout.writeln('Passed in ${elapsed.elapsed.inSeconds}s.');
    }
    stdout.writeln('Pre-commit checks passed in ${total.elapsed.inSeconds}s.');
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

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

/// Broad changes are checked in CI instead of blocking every local commit.
const maxLocalTestFiles = 20;

/// A deterministic check plan, also used by dry-run and dependency graph tests.
class CheckPlan {
  const CheckPlan({
    required this.reason,
    required this.format,
    required this.analyze,
    required this.tests,
    this.full = false,
    this.resolveDependencies = false,
  });

  final String reason;
  final List<String> format;
  final List<String> analyze;
  final List<String> tests;
  final bool full;
  final bool resolveDependencies;

  List<String> get deferredTests =>
      !full && tests.length > maxLocalTestFiles ? tests : const [];

  List<List<String>> get commands => [
    if (format.isNotEmpty)
      ['dart', 'format', '--output=none', '--set-exit-if-changed', ...format],
    if (resolveDependencies) ['flutter', 'pub', 'get'],
    if (analyze.isNotEmpty) ['flutter', 'analyze', '--no-pub', ...analyze],
    if (full || (tests.isNotEmpty && deferredTests.isEmpty))
      ['flutter', 'test', '--no-pub', if (!full) ...tests],
  ];

  Map<String, Object> toJson() => {
    'full': full,
    'resolveDependencies': resolveDependencies,
    'reason': reason,
    'format': format,
    'analyze': analyze,
    'tests': tests,
    'deferredTests': deferredTests,
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
    resolveDependencies:
        full ||
        changed.any((path) => {'pubspec.yaml', 'pubspec.lock'}.contains(path)),
  );

  if (full) return all('Full checks requested.');
  if (changed.any(_requiresFullChecks)) {
    return all('Shared configuration, assets or check tooling changed.');
  }
  final seeds = changed.where((path) => path.endsWith('.dart')).toSet();
  if (changed.any((path) => path.endsWith('.arb'))) {
    // ARB files are inputs to generated Dart, not importable dependencies.
    final localizations = sources.keys.where(
      (path) => path.startsWith('lib/l10n/') && path.endsWith('.dart'),
    );
    if (localizations.isEmpty) {
      return all('Localization output missing; using full checks.');
    }
    seeds.addAll(localizations);
  }
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
  if (testConfigChanged) {
    return all('Flutter test configuration or its dependencies changed.');
  }
  final analyze = affected.where(sources.containsKey).toList()..sort();
  final tests =
      sources.keys
          .where((path) => _isTest(path) && affected.contains(path))
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
      !path.endsWith('.md');
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
