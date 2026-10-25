import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/harness_access_storage.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/auth_session.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/domain/user_points.dart';
import 'package:popi_ai_app/features/auth/domain/wechat_app_login.dart';
import 'package:popi_ai_app/features/demo/domain/harness_access_session.dart';
import 'package:popi_ai_app/features/demo/presentation/harness_access_gate.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  testWidgets('confirming profile logout clears session and opens login page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _FakeAuthApi();
    final tokenStorage = _MemoryTokenStorage()..token = 'access-token';
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('登录页面')),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          harnessAccessRequiredProvider.overrideWithValue(false),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(api: api, secureStorage: tokenStorage),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logoutMenu = find.byKey(const Key('profile-logout-menu'));
    await tester.ensureVisible(logoutMenu);
    await tester.pumpAndSettle();
    await tester.tap(logoutMenu);
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('确认退出登录？'), findsOneWidget);
    expect(find.text('退出登录不会丢失任何数据\n你仍可以登录此账号'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(
      tester
          .getSize(
            find.descendant(of: dialog, matching: find.byType(SizedBox)).first,
          )
          .width,
      330,
    );
    final shape = tester.widget<Dialog>(dialog).shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(26));
    final cancel = find.widgetWithText(TextButton, '取消');
    final confirm = find.byKey(const Key('confirm-logout-button'));
    expect(tester.getTopLeft(cancel).dy, tester.getTopLeft(confirm).dy);
    expect(tester.getSize(confirm), const Size(130, 50));
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(api.logoutCalls, 0);
    expect(tokenStorage.token, 'access-token');
    await tester.tap(logoutMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-logout-button')));
    await tester.pumpAndSettle();

    expect(api.logoutCalls, 1);
    expect(tokenStorage.token, isNull);
    expect(find.text('登录页面'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets(
    'native Harness logout clears only its access session and returns to its gate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final session = HarnessAccessSession(
        cookieValue: 'private-test-cookie',
        origin: 'https://test.popi.art',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        cacheNamespace: '123e4567-e89b-42d3-a456-426614174000',
      );
      final storage = _MemoryHarnessAccessStorage(session);
      final controller = HarnessAccessController(
        storage: storage,
        repository: null,
        required: true,
        expectedOrigin: session.origin,
      );
      final api = _FakeAuthApi();
      final tokenStorage = _MemoryTokenStorage()..token = 'production-token';

      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            harnessAccessRequiredProvider.overrideWithValue(true),
            harnessAccessProvider.overrideWith((_) => controller),
            authRepositoryProvider.overrideWithValue(
              AuthRepository(api: api, secureStorage: tokenStorage),
            ),
          ],
          child: HarnessAccessGate(
            authenticatedBuilder: (_) => MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const ProfilePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.state.authenticated, isTrue);
      expect(storage.session, same(session));
      expect(find.byKey(const Key('harness-access-username')), findsNothing);

      final logoutMenu = find.byKey(const Key('profile-logout-menu'));
      await tester.ensureVisible(logoutMenu);
      await tester.tap(logoutMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();

      expect(controller.state.session, same(session));
      expect(storage.session, same(session));
      expect(storage.deletes, 0);
      expect(api.logoutCalls, 0);
      expect(tokenStorage.token, 'production-token');

      await tester.tap(logoutMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-logout-button')));
      await tester.pumpAndSettle();

      expect(controller.state.authenticated, isFalse);
      expect(storage.session, isNull);
      expect(storage.deletes, 1);
      expect(find.byKey(const Key('harness-access-username')), findsOneWidget);
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(ProfilePage, skipOffstage: false), findsOneWidget);
      expect(api.logoutCalls, 0);
      expect(tokenStorage.token, 'production-token');
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryHarnessAccessStorage implements HarnessAccessStorage {
  _MemoryHarnessAccessStorage(this.session);

  HarnessAccessSession? session;
  int deletes = 0;

  @override
  Future<void> deleteSession() async {
    deletes++;
    session = null;
  }

  @override
  Future<HarnessAccessSession?> readSession() async => session;

  @override
  Future<void> writeSession(HarnessAccessSession session) async =>
      this.session = session;
}

class _FakeAuthApi implements AuthApi {
  @override
  Future<AuthSession> loginByPassword({
    required String username,
    required String password,
  }) => throw UnimplementedError();

  int logoutCalls = 0;

  @override
  Future<void> cancelAccount() => throw UnimplementedError();

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<CaptchaChallenge> createCaptcha({required String phone}) =>
      throw UnimplementedError();

  @override
  Future<String> verifyCaptcha(SliderCaptchaVerification verification) async =>
      'captcha-token';

  @override
  Future<User> currentUser() => throw UnimplementedError();

  @override
  Future<AuthSession> loginByCode({
    required String phone,
    required String code,
    String inviteCode = '',
  }) => throw UnimplementedError();

  @override
  Future<WechatAppLoginResponse> loginByWechatApp({required String code}) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> registerWechatAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) => throw UnimplementedError();

  @override
  Future<void> sendLoginCode({
    required String phone,
    required String captchaToken,
  }) => throw UnimplementedError();

  @override
  Future<User> updateUser({
    required String avatar,
    required String name,
    required String signature,
  }) => throw UnimplementedError();

  @override
  Future<UserPoints> userPoints() => throw UnimplementedError();
}

class _MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> deleteAccessToken() async => token = null;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String token) async => this.token = token;
}
