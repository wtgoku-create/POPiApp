import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_examples.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

/// Isolated visual preview; account and sidebar data remain local examples.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      projectsProvider.overrideWith(
        (_) async => [
          for (final account in ipAccountExamples)
            Project(id: account.id, title: account.title),
        ],
      ),
      projectSessionsProvider.overrideWith((_, _) async => []),
    ],
  );
  await container
      .read(userProvider.notifier)
      .setUser(const User(id: 'preview', name: 'POPi', email: ''));
  final router = container.read(routerProvider(false))..go('/ip-accounts');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: Uri.base.queryParameters['theme'] == 'dark'
            ? AppTheme.dark
            : AppTheme.light,
        locale: Locale(Uri.base.queryParameters['lang'] ?? 'zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
}
