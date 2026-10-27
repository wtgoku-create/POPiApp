import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/demo/presentation/harness_access_login_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:toastification/toastification.dart';

void main() {
  Widget app({
    required HarnessSignInCallback onSignIn,
    HarnessAccessErrorMessageBuilder? errorMessageBuilder,
    bool authenticating = false,
    TextScaler? textScaler,
  }) {
    return ToastificationWrapper(
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: HarnessAccessLoginPage(
          onSignIn: onSignIn,
          errorMessageBuilder: errorMessageBuilder ?? (_, _) => '无法登录测试环境',
          authenticating: authenticating,
        ),
      ),
    );
  }

  testWidgets('defaults to popi and submits the password without trimming it', (
    tester,
  ) async {
    String? username;
    String? password;
    await tester.pumpWidget(
      app(
        onSignIn: (value, secret) async {
          username = value;
          password = secret;
        },
      ),
    );

    final usernameField = tester.widget<TextField>(
      find.byKey(const Key('harness-access-username')),
    );
    final passwordField = tester.widget<TextField>(
      find.byKey(const Key('harness-access-password')),
    );
    expect(usernameField.controller!.text, 'popi');
    expect(passwordField.obscureText, isTrue);
    expect(passwordField.autocorrect, isFalse);
    expect(passwordField.enableSuggestions, isFalse);
    expect(passwordField.smartDashesType, SmartDashesType.disabled);
    expect(passwordField.smartQuotesType, SmartQuotesType.disabled);

    await tester.enterText(
      find.byKey(const Key('harness-access-password')),
      '  Exact Secret  ',
    );
    await tester.tap(find.byKey(const Key('harness-access-submit')));
    await tester.pump();

    expect(username, 'popi');
    expect(password, '  Exact Secret  ');
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await tester.pumpWidget(app(onSignIn: (_, _) async {}));

    await tester.tap(
      find.byKey(const Key('harness-access-password-visibility')),
    );
    await tester.pump();

    final passwordField = tester.widget<TextField>(
      find.byKey(const Key('harness-access-password')),
    );
    expect(passwordField.obscureText, isFalse);
    expect(find.byTooltip('隐藏密码'), findsOneWidget);
  });

  testWidgets('disables repeated submissions while authentication is pending', (
    tester,
  ) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      app(
        onSignIn: (_, _) {
          calls += 1;
          return completer.future;
        },
      ),
    );
    await tester.enterText(
      find.byKey(const Key('harness-access-password')),
      'secret',
    );

    await tester.tap(find.byKey(const Key('harness-access-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('harness-access-submit')));
    await tester.pump();

    expect(calls, 1);
    expect(find.byKey(const Key('harness-access-submitting')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('harness-access-submit')))
          .onPressed,
      isNull,
    );

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('keeps credentials after a failed sign in and shows a toast', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        onSignIn: (_, _) => Future<void>.error(StateError('rejected')),
        errorMessageBuilder: (_, _) => '账号或密码不正确',
      ),
    );
    await tester.enterText(
      find.byKey(const Key('harness-access-password')),
      'kept secret',
    );

    await tester.tap(find.byKey(const Key('harness-access-submit')));
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    final passwordField = tester.widget<TextField>(
      find.byKey(const Key('harness-access-password')),
    );
    expect(passwordField.controller!.text, 'kept secret');
    expect(find.text('账号或密码不正确'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('fits a 320 wide screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(onSignIn: (_, _) async {}, textScaler: const TextScaler.linear(1.5)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('harness-access-submit')), findsOneWidget);
  });
}
