import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/web_login_progress.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/auth/data/web_social_auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/web_social_login.dart';
import 'package:popi_ai_app/features/auth/presentation/login_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/social_login_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';

void main() {
  late _WebAuth repository;

  Future<void> pumpLogin(
    WidgetTester tester, {
    bool restoreBinding = false,
  }) async {
    toastification.managers.clear();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    if (restoreBinding) {
      await WebLoginProgress(PreferencesStorage(preferences)).save(
        state: 'state',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        registerToken: 'registration',
      );
    }
    repository = _WebAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          webSocialAuthRepositoryProvider.overrideWithValue(repository),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const LoginPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startWechat(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('agreement-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.ensureVisible(find.byKey(const Key('wechat-login-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wechat-login-button')));
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'Web WeChat requests QR instead of invoking native authorization',
    (tester) async {
      await pumpLogin(tester);
      await startWechat(tester);
      expect(repository.challenges, 1);
      expect(repository.checks, 1);
      expect(find.byKey(const Key('web-social-login-panel')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(repository.checks, 1);
      repository.pending.complete(const WebSocialWaiting());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(repository.checks, 2);
      await tester.tap(find.byTooltip('返回上一页'));
      await tester.pumpAndSettle();
      expect(repository.cancelToken!.isCancelled, isTrue);
      expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
      repository.pending.complete(const WebSocialPhoneBindingRequired('late'));
      await tester.pump();
      expect(find.byKey(const Key('phone-binding-page')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !kIsWeb,
  );

  testWidgets('Web QR first login enters the shared phone binding form', (
    tester,
  ) async {
    await pumpLogin(tester);
    await startWechat(tester);
    repository.pending.complete(
      const WebSocialPhoneBindingRequired('registration'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-binding-page')), findsOneWidget);
    expect(find.byKey(const Key('login-code-field')), findsOneWidget);
    expect(find.byKey(const Key('login-password-field')), findsNothing);
    await tester.tap(find.byKey(const Key('phone-binding-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web-social-login-panel')), findsNothing);
    expect(find.byKey(const Key('wechat-login-button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, skip: !kIsWeb);

  testWidgets(
    'Web refresh restores Douyin phone binding and cancellation clears it',
    (tester) async {
      await pumpLogin(tester, restoreBinding: true);
      expect(find.byKey(const Key('phone-binding-page')), findsOneWidget);
      expect(repository.challenges, 0);
      expect(repository.checks, 0);
      await tester.tap(find.byKey(const Key('phone-binding-back-button')));
      await tester.pumpAndSettle();
      final preferences = await SharedPreferences.getInstance();
      expect(
        WebLoginProgress(PreferencesStorage(preferences)).restore(),
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
    skip: !kIsWeb,
  );
}

class _WebAuth extends WebSocialAuthRepository {
  _WebAuth() : super(NetworkApi(Dio()), _Tokens());
  int challenges = 0;
  int checks = 0;
  CancelToken? cancelToken;
  Completer<WebSocialSignInResult> pending = Completer();

  @override
  Future<WebSocialLoginChallenge> createChallenge({
    required bool douyin,
  }) async {
    expect(douyin, isFalse);
    challenges++;
    return const WebSocialLoginChallenge(
      state: 'scene',
      url:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
      expiresIn: Duration(minutes: 5),
    );
  }

  @override
  Future<WebSocialSignInResult> check({
    required bool douyin,
    required String state,
    required CancelToken cancelToken,
  }) {
    checks++;
    this.cancelToken = cancelToken;
    if (pending.isCompleted) pending = Completer();
    return pending.future;
  }
}

class _Tokens implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> writeAccessToken(String token) async {}
  @override
  Future<void> deleteAccessToken() async {}
}
