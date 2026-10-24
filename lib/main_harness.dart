import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/theme.dart';
import 'core/config/app_config.dart';
import 'core/network/network_agent_api.dart';
import 'features/demo/data/demo_repository.dart';
import 'features/demo/presentation/demo_app.dart';
import 'features/demo/presentation/harness_access_gate.dart';
import 'features/demo/presentation/widgets/demo_frosted_backdrop.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/providers/network_provider.dart';
import 'shared/providers/storage_provider.dart';

/// Shared native and Web client for local or explicitly configured remote Harness.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.harnessEnabled) {
    throw StateError(
      'main_harness.dart requires a local or remote Harness transport',
    );
  }
  final preferences = await SharedPreferences.getInstance();
  await DemoFrostedBackdrop.precache();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const _HarnessDemo(),
    ),
  );
}

class _HarnessDemo extends ConsumerStatefulWidget {
  const _HarnessDemo();

  @override
  ConsumerState<_HarnessDemo> createState() => _HarnessDemoState();
}

class _HarnessDemoState extends ConsumerState<_HarnessDemo> {
  @override
  Widget build(BuildContext context) =>
      const HarnessAccessGate(authenticatedBuilder: _buildHarnessContent);

  static Widget _buildHarnessContent(BuildContext context) =>
      const _HarnessContent();
}

class _HarnessContent extends ConsumerStatefulWidget {
  const _HarnessContent();

  @override
  ConsumerState<_HarnessContent> createState() => _HarnessContentState();
}

class _HarnessContentState extends ConsumerState<_HarnessContent> {
  DemoRepository? _repository;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRepository());
  }

  Future<void> _loadRepository() async {
    setState(() => _loadError = null);
    try {
      final storage = ref.read(preferencesStorageProvider);
      await DemoRepository.prepareHarnessStorage(storage);
      if (!mounted) return;
      final repository = DemoRepository.harness(
        storage,
        NetworkAgentApi(ref.read(agentDioProvider)),
      )..restore();
      if (!mounted) {
        repository.dispose();
        return;
      }
      setState(() => _repository = repository);
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    if (repository != null) {
      return DemoApp(repository: repository, bootstrapUser: false);
    }
    return _HarnessRepositoryLoadingApp(
      failed: _loadError != null,
      onRetry: _loadError == null ? null : _loadRepository,
    );
  }
}

class _HarnessRepositoryLoadingApp extends StatelessWidget {
  const _HarnessRepositoryLoadingApp({required this.failed, this.onRetry});

  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POPi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            body: Center(
              child: failed
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.harnessAccessUnavailable,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: onRetry,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    )
                  : CircularProgressIndicator(color: colorScheme.primary),
            ),
          );
        },
      ),
    );
  }
}
