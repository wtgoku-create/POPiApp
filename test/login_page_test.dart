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
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
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

  testWidgets('renders the welcome design then opens the phone form',
      (tester) async {
    await pumpLoginPage(tester);

    expect(find.text('POPi\n“帮助人类更好的表达”'), findsOneWidget);
    expect(find.byKey(const Key('login-welcome-illustration')), findsOneWidget);
    expect(find.byKey(const Key('login-back-button')), findsOneWidget);
    expect(find.byKey(const Key('login-phone-entry-button')), findsOneWidget);
    expect(find.byKey(const Key('wechat-login-button')), findsOneWidget);
    expect(find.byKey(const Key('agreement-checkbox')), findsOneWidget);
    expect(
      find.byKey(const Key('login-legal-document-links')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('login-phone-field')), findsNothing);

    await tester.tap(find.byKey(const Key('login-phone-entry-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(find.byKey(const Key('login-code-field')), findsOneWidget);
    expect(find.byKey(const Key('send-code-button')), findsOneWidget);
    expect(find.byKey(const Key('phone-login-button')), findsOneWidget);
    expect(find.byKey(const Key('login-back-button')), findsOneWidget);
    expect(find.byKey(const Key('login-captcha-field')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('login-back-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('login-phone-entry-button')), findsOneWidget);
    expect(find.byKey(const Key('login-phone-field')), findsNothing);
  });

  testWidgets('matches the Figma control and illustration geometry',
      (tester) async {
    await pumpLoginPage(tester, size: const Size(440, 956));

    expect(
      tester.getSize(find.byKey(const Key('login-welcome-illustration'))),
      const Size(427, 427),
    );
    expect(
      tester.getSize(find.byKey(const Key('login-phone-entry-button'))),
      const Size(326, 55),
    );
    expect(
      tester.getSize(find.byKey(const Key('wechat-login-button'))),
      const Size(326, 55),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-back-button'))),
      const Offset(20, 76),
    );
  });

  testWidgets('uses dark surfaces and text colors in dark mode',
      (tester) async {
    await pumpLoginPage(tester, theme: AppTheme.dark);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.dark.colorScheme.surface);

    final title = tester.widget<Text>(find.text('POPi\n“帮助人类更好的表达”'));
    expect(title.style?.color, AppTheme.dark.colorScheme.onSurface);

    final wechatButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('wechat-login-button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      wechatButton.style?.backgroundColor?.resolve({}),
      AppTheme.dark.colorScheme.surfaceContainerHighest,
    );

    await tester.tap(find.byKey(const Key('login-phone-entry-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates phone and verification code before login',
      (tester) async {
    final context = await pumpLoginPage(tester);

    await tester.tap(find.byKey(const Key('login-phone-entry-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-login-button')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(context.api.loggedInPhone, isNull);
    expect(context.storage.token, isNull);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('dismisses the keyboard when tapping outside a field',
      (tester) async {
    await pumpLoginPage(tester);

    await tester.tap(find.byKey(const Key('login-phone-entry-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('login-phone-field')));
    await tester.pump();

    expect(
      tester.testTextInput.isVisible,
      isTrue,
    );

    await tester.tapAt(const Offset(360, 300));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('keeps the focused login field visible above the keyboard',
      (tester) async {
    await pumpLoginPage(tester);
    addTearDown(tester.view.resetViewInsets);

    await tester.tap(find.byKey(const Key('login-phone-entry-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('login-code-field')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    final visibleBottom = tester.view.physicalSize.height -
        tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('login-design-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester.getBottomRight(find.byKey(const Key('login-code-field'))).dy,
      lessThanOrEqualTo(visibleBottom),
      reason:
          'viewport=${tester.getSize(find.byKey(const Key('login-design-scroll-view')))}, '
          'pixels=${scrollable.position.pixels}, '
          'max=${scrollable.position.maxScrollExtent}',
    );
    final keyboardBackButton = find.byKey(
      const Key('login-keyboard-back-button'),
    );
    expect(keyboardBackButton, findsOneWidget);
    expect(tester.getTopLeft(keyboardBackButton).dy, greaterThanOrEqualTo(0));
    expect(
      tester.getBottomRight(keyboardBackButton).dy,
      lessThan(visibleBottom),
    );

    await tester.tap(keyboardBackButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('login-phone-field')), findsNothing);
  });

  testWidgets('sends an SMS then initializes the signed-in user',
      (tester) async {
    final context = await pumpLoginPage(tester);

    await tester.tap(find.byKey(const Key('login-phone-entry-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '13800138000',
    );
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-code-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('login-captcha-field')), findsOneWidget);
    expect(find.byKey(const Key('captcha-image')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('login-captcha-field')),
      'A2B3',
    );
    await tester.tap(find.byKey(const Key('confirm-send-code-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

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
