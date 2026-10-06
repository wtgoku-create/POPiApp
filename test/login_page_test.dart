import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/core/config/app_config.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/data/douyin_auth_api.dart';
import 'package:popi_ai_app/features/auth/data/douyin_login_service.dart';
import 'package:popi_ai_app/features/auth/domain/douyin_app_login.dart';
import 'package:popi_ai_app/features/auth/domain/auth_session.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/domain/user_points.dart';
import 'package:popi_ai_app/features/auth/domain/wechat_app_login.dart';
import 'package:popi_ai_app/features/auth/presentation/login_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  setUp(() => toastification.managers.clear());

  Future<_LoginTestContext> pumpLoginPage(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = const Size(390, 844),
    DouyinLoginService? douyinService,
    DouyinAuthApi? douyinApi,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _FakeAuthApi();
    final storage = _MemoryTokenStorage();
    final repository = AuthRepository(
      api: api,
      secureStorage: storage,
      douyinApi: douyinApi ?? const UnavailableDouyinAuthApi(),
    );
    var loggedIn = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(repository),
          if (douyinService != null)
            douyinLoginServiceProvider.overrideWithValue(douyinService),
        ],
        child: ToastificationWrapper(
            child: MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: LoginPage(onLoginSuccess: () => loggedIn = true),
        )),
      ),
    );
    await tester.pump();
    return _LoginTestContext(
      api: api,
      storage: storage,
      isLoggedIn: () => loggedIn,
    );
  }

  testWidgets('shows phone login and social entries on the first screen',
      (tester) async {
    await pumpLoginPage(tester);
    expect(find.byKey(const Key('login-welcome-illustration')), findsOneWidget);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(find.byKey(const Key('login-code-field')), findsOneWidget);
    expect(find.byKey(const Key('send-code-button')), findsOneWidget);
    expect(find.byKey(const Key('phone-login-button')), findsOneWidget);
    expect(find.byKey(const Key('wechat-login-button')), findsOneWidget);
    final douyin = tester.widget<TextButton>(
      find.byKey(const Key('douyin-login-button')),
    );
    expect(douyin.onPressed, isNotNull);
    expect(find.byKey(const Key('agreement-checkbox')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password entry is available only in development',
      (tester) async {
    await pumpLoginPage(tester);
    expect(
      find.byKey(const Key('login-mode-switch')),
      AppConfig.passwordLoginEnabled ? findsOneWidget : findsNothing,
    );
    expect(find.byKey(const Key('login-password-field')), findsNothing);
  });

  group('password login', () {
    testWidgets('signs in with the original password and initializes the user',
        (tester) async {
      final context = await pumpLoginPage(tester);
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      final passwordField = find.byKey(const Key('login-password-field'));
      expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
      expect(find.byKey(const Key('login-code-field')), findsNothing);
      expect(find.byKey(const Key('send-code-button')), findsNothing);
      await tester.tap(find.byKey(const Key('login-password-visibility')));
      await tester.pump();
      expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
      await tester.enterText(
          find.byKey(const Key('login-phone-field')), '13800138000');
      await tester.enterText(passwordField, ' password ');
      await tester.tap(find.byKey(const Key('agreement-checkbox')));
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(context.api.loggedInPhone, '13800138000');
      expect(context.api.loginPassword, ' password ');
      expect(context.api.currentUserRequested, isTrue);
      expect(context.storage.token, 'password-token');
      expect(context.isLoggedIn(), isTrue);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('requires agreement, valid phone and at least six characters',
        (tester) async {
      final context = await pumpLoginPage(tester);
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('login-password-field')), 'password');
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(find.text('请先阅读并同意用户协议和隐私政策'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agreement-checkbox')));
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(find.text('请输入正确的手机号'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('login-phone-field')), '13800138000');
      await tester.enterText(
          find.byKey(const Key('login-password-field')), '12345');
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(find.text('请输入至少 6 位密码'), findsOneWidget);
      expect(context.api.loginPassword, isNull);
      expect(context.storage.token, isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows rejected password and allows retry', (tester) async {
      final context = await pumpLoginPage(tester);
      context.api.failPasswordLogin = true;
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('login-phone-field')), '13800138000');
      await tester.enterText(
          find.byKey(const Key('login-password-field')), 'wrong-password');
      await tester.tap(find.byKey(const Key('agreement-checkbox')));
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(find.text('密码错误'), findsOneWidget);
      expect(context.storage.token, isNull);
      expect(context.isLoggedIn(), isFalse);
      expect(context.api.currentUserRequested, isFalse);
      context.api.failPasswordLogin = false;
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(context.isLoggedIn(), isTrue);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('switches back to SMS and clears the password', (tester) async {
      await pumpLoginPage(tester, size: const Size(320, 568));
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('login-password-field')), 'password');
      await tester.tap(find.byKey(const Key('login-password-visibility')));
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      expect(find.byKey(const Key('login-code-field')), findsOneWidget);
      expect(find.byKey(const Key('send-code-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      final field = tester
          .widget<TextField>(find.byKey(const Key('login-password-field')));
      expect(field.controller!.text, isEmpty);
      expect(field.obscureText, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }, skip: !AppConfig.passwordLoginEnabled);

  testWidgets('matches the updated Figma form geometry', (tester) async {
    await pumpLoginPage(tester, size: const Size(440, 956));
    expect(
      tester.getSize(find.byKey(const Key('phone-login-button'))),
      const Size(360, 60),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('login-back-button'))),
      const Offset(15, 60),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('phone-login-button'))),
      const Offset(40, 541),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Douyin reports unavailable without backend or SDK',
      (tester) async {
    final context = await pumpLoginPage(tester);
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('douyin-login-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect((await const DouyinLoginService().authorize()).status,
        DouyinAuthorizationStatus.unavailable);
    expect(
        tester
            .widget<TextButton>(find.byKey(const Key('douyin-login-button')))
            .onPressed,
        isNotNull);
    expect(context.isLoggedIn(), isFalse);
    expect(context.storage.token, isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Douyin exchanges authorization and initializes user',
      (tester) async {
    final api = _FakeDouyinApi();
    final context = await pumpLoginPage(tester,
        douyinService: const _AuthorizedDouyinService(), douyinApi: api);
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('douyin-login-button')));
    await tester.pumpAndSettle();
    expect(api.authorizationCode, 'douyin-code');
    expect(context.storage.token, 'douyin-token');
    expect(context.api.currentUserRequested, isTrue);
    expect(context.isLoggedIn(), isTrue);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Douyin phone binding uses its own reserved interface',
      (tester) async {
    final api = _FakeDouyinApi(needsBinding: true);
    final context = await pumpLoginPage(tester,
        douyinService: const _AuthorizedDouyinService(), douyinApi: api);
    if (AppConfig.passwordLoginEnabled) {
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('douyin-login-button')));
    await tester.pump(const Duration(seconds: 4));
    expect(context.storage.token, isNull);
    expect(context.isLoggedIn(), isFalse);
    expect(find.byKey(const Key('login-password-field')), findsNothing);
    expect(find.byKey(const Key('login-mode-switch')), findsNothing);
    await tester.enterText(
        find.byKey(const Key('login-phone-field')), '13800138000');
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.tap(find.byKey(const Key('phone-login-button')));
    await tester.pumpAndSettle();
    expect(api.bindingToken, 'douyin-register-token');
    expect(api.bindingPhone, '13800138000');
    expect(api.bindingCode, '123456');
    expect(context.api.loggedInPhone, isNull);
    expect(context.storage.token, 'douyin-token');
    expect(context.isLoggedIn(), isTrue);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('supports dark mode and compact screens', (tester) async {
    await pumpLoginPage(tester,
        theme: AppTheme.dark, size: const Size(320, 568));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.dark.colorScheme.surface);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates phone and verification code before login',
      (tester) async {
    final context = await pumpLoginPage(tester);

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
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('sends an SMS then initializes the signed-in user',
      (tester) async {
    final context = await pumpLoginPage(tester);

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '13800138000',
    );
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-code-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('login-captcha-field')), findsNothing);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    final captchaImages = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage);
    final providers = tester
        .widgetList<Image>(captchaImages)
        .map((image) => image.image)
        .toList();
    expect(providers, hasLength(2));
    expect(tester.getSize(captchaImages.first).width, greaterThan(280));
    final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('captcha-slider-handle'))));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    final movedProviders = tester
        .widgetList<Image>(captchaImages)
        .map((image) => image.image)
        .toList();
    for (var i = 0; i < providers.length; i++) {
      expect(identical(providers[i], movedProviders[i]), isTrue);
    }
    await gesture.moveBy(const Offset(60, 0));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(context.api.sentPhone, '13800138000');
    expect(context.api.sentCaptchaValue, 'captcha-token');
    final countdown = tester.widget<Text>(find.text('60 秒后重发'));
    expect(countdown.maxLines, 1);
    expect(countdown.softWrap, isFalse);
    final sendButton = find.byKey(const Key('send-code-button'));
    final countdownFit =
        find.descendant(of: sendButton, matching: find.byType(FittedBox));
    expect(countdownFit, findsOneWidget);
    expect(
        tester
            .getRect(sendButton)
            .contains(tester.getRect(countdownFit).center),
        isTrue);
    expect(tester.takeException(), isNull);

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

  testWidgets('rejected slider never sends SMS and refreshes the challenge',
      (tester) async {
    final context = await pumpLoginPage(tester);
    expect(context.api.challengesRequested, 0);
    context.api.failVerification = true;
    await tester.enterText(
        find.byKey(const Key('login-phone-field')), '13800138000');
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.tap(find.byKey(const Key('send-code-button')));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const Key('captcha-slider-handle')), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(context.api.sentPhone, isNull);
    expect(context.api.challengesRequested, 2);
    expect(find.text('验证失败，请重试'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('handles the WeChat Universal Link authorization callback',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _FakeAuthApi();
    final storage = _MemoryTokenStorage();
    final repository = AuthRepository(api: api, secureStorage: storage);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        secureStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider(false));
    router.go(
      'https://app.popi.art/WeChat/wxf99ad5d5c7b4fe37/oauth?code=callback-code&state=state',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(api.wechatAuthorizationCode, 'callback-code');
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(tester.takeException(), isNull);

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
  String? sentCaptchaValue;
  bool failVerification = false;
  int challengesRequested = 0;
  String? loggedInPhone;
  String? loginPassword;
  bool failPasswordLogin = false;
  String? wechatAuthorizationCode;
  bool currentUserRequested = false;

  @override
  Future<CaptchaChallenge> createCaptcha({required String phone}) async {
    challengesRequested++;
    return const CaptchaChallenge(
      id: '10019',
      bgUrl:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      puzzleUrl:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
  }

  @override
  Future<String> verifyCaptcha(SliderCaptchaVerification verification) async {
    if (failVerification) throw StateError('Rejected');
    return 'captcha-token';
  }

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
  Future<AuthSession> loginByPassword({
    required String username,
    required String password,
  }) async {
    loggedInPhone = username;
    loginPassword = password;
    if (failPasswordLogin) {
      throw const ApiException(message: '密码错误');
    }
    return const AuthSession(
      accessToken: 'password-token',
      user: User(id: '1', name: '临时用户', email: ''),
    );
  }

  @override
  Future<WechatAppLoginResponse> loginByWechatApp(
      {required String code}) async {
    wechatAuthorizationCode = code;
    return const WechatAppPhoneBindingRequired('wechat-register-token');
  }

  @override
  Future<AuthSession> registerWechatAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendLoginCode({
    required String phone,
    required String captchaToken,
  }) async {
    sentPhone = phone;
    sentCaptchaValue = captchaToken;
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

class _AuthorizedDouyinService extends DouyinLoginService {
  const _AuthorizedDouyinService();

  @override
  Future<DouyinAuthorizationResult> authorize() async =>
      const DouyinAuthorizationResult.authorized('douyin-code');
}

class _FakeDouyinApi implements DouyinAuthApi {
  _FakeDouyinApi({this.needsBinding = false});

  final bool needsBinding;
  String? authorizationCode;
  String? bindingToken;
  String? bindingPhone;
  String? bindingCode;

  static const session = AuthSession(
    accessToken: 'douyin-token',
    user: User(id: '1', name: '抖音用户', email: ''),
  );

  @override
  Future<DouyinAppLoginResponse> loginByDouyinApp(
      {required String code}) async {
    authorizationCode = code;
    return needsBinding
        ? const DouyinAppPhoneBindingRequired('douyin-register-token')
        : const DouyinAppLoginSucceeded(session);
  }

  @override
  Future<AuthSession> registerDouyinAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    bindingToken = registerToken;
    bindingPhone = phone;
    bindingCode = code;
    return session;
  }
}
