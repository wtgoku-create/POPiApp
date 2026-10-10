import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/app/router.dart';
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
import 'package:popi_ai_app/shared/providers/social_login_provider.dart';

void main() {
  setUp(() => toastification.managers.clear());

  Future<_LoginTestContext> pumpLoginPage(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = const Size(390, 844),
    DouyinLoginService? douyinService,
    DouyinAuthApi? douyinApi,
    String? wechatAuthorizationCode,
    Locale locale = const Locale('zh'),
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
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: LoginPage(
              onLoginSuccess: () => loggedIn = true,
              wechatAuthorizationCode: wechatAuthorizationCode,
            ),
          ),
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

  testWidgets('shows phone login and social entries on the first screen', (
    tester,
  ) async {
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

  testWidgets('password entry is available', (tester) async {
    await pumpLoginPage(tester);
    expect(find.byKey(const Key('login-mode-switch')), findsOneWidget);
    expect(find.byKey(const Key('login-password-field')), findsNothing);
  });

  group('password login', () {
    testWidgets(
      'signs in with the original password and initializes the user',
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
          find.byKey(const Key('login-phone-field')),
          '13800138000',
        );
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
      },
    );

    testWidgets('requires agreement, valid phone and at least six characters', (
      tester,
    ) async {
      final context = await pumpLoginPage(tester);
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'password',
      );
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
        find.byKey(const Key('login-phone-field')),
        '13800138000',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        '12345',
      );
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
        find.byKey(const Key('login-phone-field')),
        '13800138000',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'wrong-password',
      );
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
        find.byKey(const Key('login-password-field')),
        'password',
      );
      await tester.tap(find.byKey(const Key('login-password-visibility')));
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      expect(find.byKey(const Key('login-code-field')), findsOneWidget);
      expect(find.byKey(const Key('send-code-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('login-mode-switch')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('login-password-field')),
      );
      expect(field.controller!.text, isEmpty);
      expect(field.obscureText, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

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

  testWidgets('Douyin reports unavailable when native SDK cannot authorize', (
    tester,
  ) async {
    const channel = MethodChannel('art.popi/douyin_login');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'status': 'unavailable'},
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final context = await pumpLoginPage(tester);
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('douyin-login-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      (await const DouyinLoginService().authorize()).status,
      DouyinAuthorizationStatus.unavailable,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('douyin-login-button')))
          .onPressed,
      isNotNull,
    );
    expect(context.isLoggedIn(), isFalse);
    expect(context.storage.token, isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Douyin exchanges authorization and initializes user', (
    tester,
  ) async {
    final api = _FakeDouyinApi();
    final context = await pumpLoginPage(
      tester,
      douyinService: const _AuthorizedDouyinService(),
      douyinApi: api,
    );
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

  testWidgets('Douyin phone binding uses its own reserved interface', (
    tester,
  ) async {
    final api = _FakeDouyinApi(needsBinding: true);
    final context = await pumpLoginPage(
      tester,
      douyinService: const _AuthorizedDouyinService(),
      douyinApi: api,
    );
    await tester.tap(find.byKey(const Key('login-mode-switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('douyin-login-button')));
    await tester.pump(const Duration(seconds: 4));
    expect(context.storage.token, isNull);
    expect(context.isLoggedIn(), isFalse);
    expect(find.byKey(const Key('phone-binding-page')), findsOneWidget);
    expect(find.byKey(const Key('douyin-login-button')), findsNothing);
    expect(find.byKey(const Key('wechat-login-button')), findsNothing);
    expect(find.text('请绑定手机号以完成抖音登录'), findsOneWidget);
    expect(find.byKey(const Key('login-password-field')), findsNothing);
    expect(find.byKey(const Key('login-mode-switch')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '13800138000',
    );
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

  testWidgets(
    'Douyin binding sends SMS through captcha and can retry failure',
    (tester) async {
      final api = _FakeDouyinApi(needsBinding: true)..failBinding = true;
      final context = await pumpLoginPage(
        tester,
        douyinService: const _AuthorizedDouyinService(),
        douyinApi: api,
      );
      await tester.tap(find.byKey(const Key('agreement-checkbox')));
      await tester.tap(find.byKey(const Key('douyin-login-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-phone-field')),
        '13800138000',
      );
      await tester.tap(find.byKey(const Key('send-code-button')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('captcha-slider-handle')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      expect(context.api.sentPhone, '13800138000');
      expect(context.api.sentCaptchaValue, 'captcha-token');
      await tester.enterText(
        find.byKey(const Key('login-code-field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('phone-binding-page')), findsOneWidget);
      expect(context.storage.token, isNull);
      expect(context.isLoggedIn(), isFalse);
      expect(find.text('验证码错误'), findsOneWidget);
      api.failBinding = false;
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(api.bindingToken, 'douyin-register-token');
      expect(context.storage.token, 'douyin-token');
      expect(context.isLoggedIn(), isTrue);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final systemBack in [false, true]) {
    testWidgets(
      'leaving phone binding clears its token with systemBack=$systemBack',
      (tester) async {
        final api = _FakeDouyinApi(needsBinding: true);
        final context = await pumpLoginPage(
          tester,
          douyinService: const _AuthorizedDouyinService(),
          douyinApi: api,
        );
        await tester.tap(find.byKey(const Key('agreement-checkbox')));
        await tester.tap(find.byKey(const Key('douyin-login-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login-code-field')),
          '654321',
        );
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byKey(const Key('phone-binding-back-button')));
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('phone-binding-page')), findsNothing);
        expect(find.byKey(const Key('douyin-login-button')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('login-code-field')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.enterText(
          find.byKey(const Key('login-phone-field')),
          '13800138000',
        );
        await tester.enterText(
          find.byKey(const Key('login-code-field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('phone-login-button')));
        await tester.pumpAndSettle();
        expect(api.bindingToken, isNull);
        expect(context.api.loggedInPhone, '13800138000');
        expect(context.isLoggedIn(), isTrue);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'WeChat uses the same binding page and its own binding endpoint',
    (tester) async {
      final context = await pumpLoginPage(
        tester,
        wechatAuthorizationCode: 'wechat-code',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('phone-binding-page')), findsOneWidget);
      expect(find.text('请先绑定手机号以完成微信登录'), findsOneWidget);
      await tester.tap(find.byKey(const Key('agreement-checkbox')));
      await tester.enterText(
        find.byKey(const Key('login-phone-field')),
        '13800138000',
      );
      await tester.enterText(
        find.byKey(const Key('login-code-field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('phone-login-button')));
      await tester.pumpAndSettle();
      expect(context.api.wechatBindingToken, 'wechat-register-token');
      expect(context.api.wechatBindingPhone, '13800138000');
      expect(context.api.wechatBindingCode, '123456');
      expect(context.storage.token, 'wechat-token');
      expect(context.isLoggedIn(), isTrue);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets(
      'phone binding fits a compact dark screen in ${locale.languageCode}',
      (tester) async {
        await pumpLoginPage(
          tester,
          theme: AppTheme.dark,
          size: const Size(320, 568),
          locale: locale,
          wechatAuthorizationCode: 'wechat-code',
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('phone-binding-page')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final field = find.byKey(const Key('login-code-field'));
        final position = tester.getTopLeft(field);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(field);
        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.getTopLeft(field), position);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('supports dark mode and compact screens', (tester) async {
    await pumpLoginPage(
      tester,
      theme: AppTheme.dark,
      size: const Size(320, 568),
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.dark.colorScheme.surface);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates phone and verification code before login', (
    tester,
  ) async {
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

  testWidgets('dismisses the keyboard when tapping outside a field', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.tap(find.byKey(const Key('login-phone-field')));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tapAt(const Offset(360, 300));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('keyboard overlays the login page without moving its fields', (
    tester,
  ) async {
    await pumpLoginPage(tester);
    addTearDown(tester.view.resetViewInsets);
    final field = find.byKey(const Key('login-code-field'));
    final fieldPosition = tester.getTopLeft(field);
    final viewportSize = tester.getSize(
      find.byKey(const Key('login-design-scroll-view')),
    );

    await tester.tap(find.byKey(const Key('login-code-field')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    final visibleBottom =
        tester.view.physicalSize.height -
        tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('login-design-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.getTopLeft(field), fieldPosition);
    expect(
      tester.getSize(find.byKey(const Key('login-design-scroll-view'))),
      viewportSize,
    );
    expect(scrollable.position.pixels, 0);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).resizeToAvoidBottomInset,
      isFalse,
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

  testWidgets('sends an SMS then initializes the signed-in user', (
    tester,
  ) async {
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
      (widget) => widget is Image && widget.image is MemoryImage,
    );
    final providers = tester
        .widgetList<Image>(captchaImages)
        .map((image) => image.image)
        .toList();
    expect(providers, hasLength(2));
    expect(tester.getSize(captchaImages.first).width, greaterThan(280));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('captcha-slider-handle'))),
    );
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
    final countdownFit = find.descendant(
      of: sendButton,
      matching: find.byType(FittedBox),
    );
    expect(countdownFit, findsOneWidget);
    expect(
      tester.getRect(sendButton).contains(tester.getRect(countdownFit).center),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
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

  testWidgets('rejected slider never sends SMS and refreshes the challenge', (
    tester,
  ) async {
    final context = await pumpLoginPage(tester);
    expect(context.api.challengesRequested, 0);
    context.api.failVerification = true;
    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '13800138000',
    );
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.tap(find.byKey(const Key('send-code-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('captcha-slider-handle')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(context.api.sentPhone, isNull);
    expect(context.api.challengesRequested, 2);
    expect(find.text('验证失败，请重试'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('handles the WeChat Universal Link authorization callback', (
    tester,
  ) async {
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
  String? wechatBindingToken;
  String? wechatBindingPhone;
  String? wechatBindingCode;
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
  Future<WechatAppLoginResponse> loginByWechatApp({
    required String code,
  }) async {
    wechatAuthorizationCode = code;
    return const WechatAppPhoneBindingRequired('wechat-register-token');
  }

  @override
  Future<AuthSession> registerWechatAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    wechatBindingToken = registerToken;
    wechatBindingPhone = phone;
    wechatBindingCode = code;
    return const AuthSession(
      accessToken: 'wechat-token',
      user: User(id: '1', name: '微信用户', email: ''),
    );
  }

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
  }) => throw UnimplementedError();

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
  bool failBinding = false;
  String? authorizationCode;
  String? bindingToken;
  String? bindingPhone;
  String? bindingCode;

  static const session = AuthSession(
    accessToken: 'douyin-token',
    user: User(id: '1', name: '抖音用户', email: ''),
  );

  @override
  Future<DouyinAppLoginResponse> loginByDouyinApp({
    required String code,
  }) async {
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
    if (failBinding) throw const ApiException(message: '验证码错误');
    return session;
  }
}
