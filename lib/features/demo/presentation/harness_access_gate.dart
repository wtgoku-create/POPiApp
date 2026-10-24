import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/harness_access_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/app_keyboard_dismiss.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../data/harness_access_repository.dart';
import 'harness_access_login_page.dart';

/// Keeps the remote Harness behind its native access session.
///
/// Once created, [authenticatedBuilder] stays mounted behind the login surface
/// if a session expires. This preserves the open conversation and unsent text
/// while the user signs in again.
class HarnessAccessGate extends ConsumerStatefulWidget {
  const HarnessAccessGate({required this.authenticatedBuilder, super.key});

  final WidgetBuilder authenticatedBuilder;

  @override
  ConsumerState<HarnessAccessGate> createState() => _HarnessAccessGateState();
}

class _HarnessAccessGateState extends ConsumerState<HarnessAccessGate> {
  Widget? _authenticatedChild;

  @override
  void initState() {
    super.initState();
    if (ref.read(harnessAccessRequiredProvider)) {
      unawaited(ref.read(harnessAccessProvider.notifier).initialize());
    }
  }

  @override
  Widget build(BuildContext context) {
    final required = ref.watch(harnessAccessRequiredProvider);
    if (!required) {
      return _authenticatedChild ??= widget.authenticatedBuilder(context);
    }

    final access = ref.watch(harnessAccessProvider);
    if (access.authenticated) {
      _authenticatedChild ??= KeyedSubtree(
        key: const ValueKey('harness-authenticated-app'),
        child: widget.authenticatedBuilder(context),
      );
    }
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return ToastificationWrapper(
      config: const ToastificationConfig(itemWidth: 320),
      child: MaterialApp(
        title: 'POPi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => AppKeyboardDismiss(child: child!),
        home: _HarnessAccessStage(
          access: access,
          authenticatedChild: _authenticatedChild,
          onSignIn: ref.read(harnessAccessProvider.notifier).signIn,
        ),
      ),
    );
  }
}

class _HarnessAccessStage extends StatelessWidget {
  const _HarnessAccessStage({
    required this.access,
    required this.authenticatedChild,
    required this.onSignIn,
  });

  final HarnessAccessState access;
  final Widget? authenticatedChild;
  final HarnessSignInCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final child = authenticatedChild;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (child != null)
          Offstage(
            offstage: !access.authenticated,
            child: TickerMode(enabled: access.authenticated, child: child),
          ),
        if (!access.authenticated)
          if (access.loading && child == null)
            const _HarnessAccessLoadingPage()
          else
            HarnessAccessLoginPage(
              authenticating: access.authenticating,
              onSignIn: onSignIn,
              errorMessageBuilder: _errorMessage,
            ),
      ],
    );
  }

  static String _errorMessage(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context)!;
    if (error is! HarnessAccessException) {
      return l10n.harnessAccessUnavailable;
    }
    if (error.invalid) return l10n.harnessAccessInvalidCredentials;
    if (error.rateLimited) {
      final seconds = error.retryAfterSeconds;
      return seconds == null
          ? l10n.harnessAccessRateLimitedUnknown
          : l10n.harnessAccessRateLimited(seconds);
    }
    return l10n.harnessAccessUnavailable;
  }
}

class _HarnessAccessLoadingPage extends StatelessWidget {
  const _HarnessAccessLoadingPage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const Key('harness-access-loading'),
      color: colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: const AppSvgIcon.asset('home_welcome_logo', size: 58),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
