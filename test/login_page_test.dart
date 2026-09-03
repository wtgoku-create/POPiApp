import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/auth_session.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/domain/user_points.dart';
import 'package:popi_ai_app/features/auth/presentation/login_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  Future<_LoginTestContext> pumpLoginPage(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _FakeAuthApi();
    final storage = _MemoryTokenStorage();
    final repository = AuthRepository(api: api, secureStorage: storage);
    var loggedIn = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: LoginPage(onLoginSuccess: () => loggedIn = true),
        ),
      ),
    );
    await tester.pump();
    return _LoginTestContext(
      api: api,
      storage: storage,
      isLoggedIn: () => loggedIn,
    );
  }

  testWidgets('renders phone, graphical captcha and WeChat login methods',
      (tester) async {
    await pumpLoginPage(tester);

    expect(find.text('欢迎登录 POPi'), findsOneWidget);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(find.byKey(const Key('login-captcha-field')), findsOneWidget);
    expect(find.byKey(const Key('captcha-image')), findsOneWidget);
    expect(find.byKey(const Key('login-code-field')), findsOneWidget);
    expect(find.byKey(const Key('phone-login-button')), findsOneWidget);
    expect(find.byKey(const Key('wechat-login-button')), findsOneWidget);
    expect(find.byKey(const Key('agreement-checkbox')), findsOneWidget);
    expect(
      find.byKey(const Key('login-legal-document-links')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses dark surfaces and text colors in dark mode',
      (tester) async {
    await pumpLoginPage(tester, theme: AppTheme.dark);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.dark.colorScheme.surface);

    final title = tester.widget<Text>(find.text('欢迎登录 POPi'));
    expect(title.style?.color, AppTheme.dark.colorScheme.onSurface);

    final subtitle = tester.widget<Text>(find.text('登录后继续创作你的专属 IP'));
    expect(subtitle.style?.color, AppTheme.dark.colorScheme.onSurfaceVariant);

    final captchaSurface = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const Key('refresh-captcha-button')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(captchaSurface.color, AppTheme.dark.colorScheme.surface);
  });

  testWidgets('validates phone and verification code before login',
      (tester) async {
    await pumpLoginPage(tester);

    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-login-button')));
    await tester.pump();

    expect(find.text('请输入正确的手机号'), findsOneWidget);
    expect(find.text('请输入 6 位数字验证码'), findsOneWidget);
  });

  testWidgets('sends an SMS then initializes the signed-in user',
      (tester) async {
    final context = await pumpLoginPage(tester);

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('login-captcha-field')),
      'A2B3',
    );
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-code-button')));
    await tester.pump();

    expect(context.api.sentPhone, '13800138000');
    expect(context.api.sentCaptchaId, '10019');
    expect(context.api.sentCaptchaValue, 'A2B3');

    await tester.enterText(
      find.byKey(const Key('login-code-field')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('phone-login-button')));
    await tester.pump();

    expect(context.api.loggedInPhone, '13800138000');
    expect(context.api.currentUserRequested, isTrue);
    expect(context.storage.token, 'test-token');
    expect(context.isLoggedIn(), isTrue);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class _LoginTestContext {
  const _LoginTestContext({
    required this.api,
    required this.storage,
    required this.isLoggedIn,
  });

  final _FakeAuthApi api;
  final _MemoryTokenStorage storage;
  final bool Function() isLoggedIn;
}

class _FakeAuthApi implements AuthApi {
  String? sentPhone;
  String? sentCaptchaId;
  String? sentCaptchaValue;
  String? loggedInPhone;
  bool currentUserRequested = false;

  @override
  Future<CaptchaChallenge> createCaptcha() async => const CaptchaChallenge(
        id: '10019',
        imageBase64:
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

  @override
  Future<User> currentUser() async {
    currentUserRequested = true;
    return const User(id: '1', name: '已初始化用户', email: 'user@popi.art');
  }

  @override
  Future<AuthSession> loginByCode({
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    loggedInPhone = phone;
    return const AuthSession(
      accessToken: 'test-token',
      user: User(id: '1', name: '临时用户', email: ''),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendLoginCode({
    required String phone,
    required String captchaId,
    required String captchaValue,
  }) async {
    sentPhone = phone;
    sentCaptchaId = captchaId;
    sentCaptchaValue = captchaValue;
  }

  @override
  Future<User> updateUser({
    required String avatar,
    required String name,
    required String signature,
  }) =>
      throw UnimplementedError();

  @override
  Future<UserPoints> userPoints() async => const UserPoints(
        availableMemberPoints: 0,
        availableOtherPoints: 0,
        availableTotalPoints: 0,
        consumePoints: 0,
      );
}

class _MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> deleteAccessToken() async => token = null;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String value) async => token = value;
}
