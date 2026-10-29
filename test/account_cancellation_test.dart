import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/auth_interceptor.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

const _cancelPath = '/api_client/users/user/cancel';
const _user = User(id: '42', name: 'Account owner', email: '');

void main() {
  late _CancellationFixture fixture;
  setUp(() => fixture = _CancellationFixture());
  tearDown(() {
    fixture.dio.close();
    toastification.dismissAll(delayForAnimation: false);
  });

  for (final wrapped in [false, true]) {
    test(
      'cancels the authenticated account with confirmation, wrapped=$wrapped',
      () async {
        fixture.respond = () =>
            wrapped ? {'status': '0000', 'data': <String, dynamic>{}} : {};
        await fixture.repository.cancelAccount();

        final request = fixture.cancellations.single;
        expect(request.method, 'POST');
        expect(request.data, {'confirm': true});
        expect(request.queryParameters, isEmpty);
        expect(request.headers['Authorization'], 'Bearer current-token');
        expect(fixture.storage.token, isNull);
        expect(
          fixture.requests.any((r) => r.path.endsWith('/logout')),
          isFalse,
        );
      },
    );
  }

  for (final code in ['4000', '4001', '4003', '5000']) {
    test('business error $code retains the local token', () async {
      fixture.respond = () => {'status': code, 'message': 'Cannot cancel'};
      await expectLater(
        fixture.repository.cancelAccount(),
        throwsA(isA<ApiException>()),
      );
      expect(fixture.storage.token, 'current-token');
    });
  }

  test('transport failure retains the local token', () async {
    fixture.respond = () => throw DioException(
      requestOptions: RequestOptions(path: _cancelPath),
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      fixture.repository.cancelAccount(),
      throwsA(isA<ApiException>()),
    );
    expect(fixture.storage.token, 'current-token');
  });

  Future<({ProviderContainer container, GoRouter router})> mount(
    WidgetTester tester, {
    bool guest = false,
    bool english = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        secureStorageProvider.overrideWithValue(fixture.storage),
        dioProvider.overrideWithValue(fixture.dio),
        agentDioProvider.overrideWithValue(fixture.dio),
        authRepositoryProvider.overrideWithValue(fixture.repository),
      ],
    );
    addTearDown(container.dispose);
    if (!guest) {
      await tester.runAsync(() async {
        await container.read(userProvider.notifier).setUser(_user);
        await container.read(userPointsProvider.future);
        await container.read(userPointsProvider.notifier).refresh();
      });
    }
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Login screen')),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = Size(english ? 640 : 390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: english ? AppTheme.dark : AppTheme.light,
          locale: Locale(english ? 'en' : 'zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, router: router);
  }

  Future<void> openConfirmation(WidgetTester tester) async {
    final entry = find.byKey(const Key('profile-cancel-account-menu'));
    await tester.scrollUntilVisible(entry, 200);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
  }

  testWidgets('guest has no account cancellation entry', (tester) async {
    await mount(tester, guest: true);
    expect(find.byKey(const Key('profile-cancel-account-menu')), findsNothing);
    expect(fixture.cancellations, isEmpty);
  });

  for (final english in [false, true]) {
    testWidgets(
      'confirmation can be canceled; success clears login, english=$english',
      (tester) async {
        final state = await mount(tester, english: english);
        final entry = find.byKey(const Key('profile-cancel-account-menu'));
        await tester.scrollUntilVisible(entry, 200);
        await tester.pumpAndSettle();
        final row = tester.widget<SettingsRow>(entry);
        expect(row.foregroundColor, const Color(0xFFD63D43));
        expect(tester.getSize(entry).height, 60);
        expect(
          find.ancestor(of: entry, matching: find.byType(SettingsGroup)),
          findsOneWidget,
        );
        final logout = find.byKey(const Key('profile-logout-menu'));
        await tester.ensureVisible(logout);
        await tester.pumpAndSettle();
        final button = tester.widget<TextButton>(logout);
        expect(button.style!.shape!.resolve({}), isA<StadiumBorder>());
        expect(tester.getSize(logout).height, 50);
        await openConfirmation(tester);
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          find.text(english ? 'Delete your account?' : '确认注销账号？'),
          findsOneWidget,
        );
        expect(
          find.textContaining(english ? 'stop automatic renewal' : '停止自动续费'),
          findsNothing,
        );
        expect(find.textContaining(english ? 'refund' : '退款'), findsNothing);
        expect(
          find.textContaining(
            english
                ? 'Historical data and works will be retained'
                : '历史数据和作品仍会保留',
          ),
          findsOneWidget,
        );
        final cancel = find.widgetWithText(
          TextButton,
          english ? 'Cancel' : '取消',
        );
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(fixture.cancellations, isEmpty);
        expect(state.container.read(userProvider), _user);
        expect(fixture.storage.token, 'current-token');

        await openConfirmation(tester);
        final confirm = find.byKey(const Key('confirm-cancel-account-button'));
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(fixture.cancellations, hasLength(1));
        expect(fixture.storage.token, isNull);
        expect(state.container.read(userProvider), isNull);
        expect(state.container.read(userPointsProvider).valueOrNull, isNull);
        expect(find.text('Login screen'), findsOneWidget);
        expect(
          find.text(english ? 'Account deleted successfully' : '注销成功'),
          findsOneWidget,
        );
        expect(state.router.canPop(), isFalse);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'pending cancellation prevents duplicates; failure allows another confirmation',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      fixture.respond = () => pending.future;
      final state = await mount(tester);
      await openConfirmation(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel-account-button')));
      await tester.pump(const Duration(milliseconds: 400));
      final entry = find.byKey(const Key('profile-cancel-account-menu'));
      expect(tester.widget<SettingsRow>(entry).onTap, isNull);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('profile-logout-menu')))
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(
          of: entry,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(entry);
      await tester.pump();
      expect(fixture.cancellations, hasLength(1));

      pending.complete({'status': '5000', 'message': '网关暂时不可用'});
      await tester.pumpAndSettle();
      expect(find.text('网关暂时不可用'), findsOneWidget);
      expect(find.text('注销成功'), findsNothing);
      expect(state.container.read(userProvider), _user);
      expect(
        state.container
            .read(userPointsProvider)
            .valueOrNull
            ?.availableTotalPoints,
        20,
      );
      expect(fixture.storage.token, 'current-token');
      expect(tester.widget<SettingsRow>(entry).onTap, isNotNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();

      fixture.respond = () => {};
      await openConfirmation(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel-account-button')));
      await tester.pumpAndSettle();
      expect(fixture.cancellations, hasLength(2));
      expect(find.text('Login screen'), findsOneWidget);
      expect(find.text('注销成功'), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
    },
  );
}

class _CancellationFixture {
  _CancellationFixture() {
    dio.interceptors.add(AuthInterceptor(storage));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          try {
            final body = options.path == _cancelPath
                ? await respond()
                : {
                    'status': '0000',
                    'data': {
                      'bound': false,
                      'list': <Object>[],
                      'availableTotalPoints': 20,
                    },
                  };
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: body),
            );
          } on DioException catch (error) {
            handler.reject(error);
          }
        },
      ),
    );
    repository = AuthRepository(
      api: DefaultAuthApi(NetworkApi(dio)),
      secureStorage: storage,
    );
  }

  final dio = Dio();
  final storage = _MemoryTokenStorage();
  final requests = <RequestOptions>[];
  late final AuthRepository repository;
  FutureOr<Map<String, dynamic>> Function() respond = () => {};

  List<RequestOptions> get cancellations =>
      requests.where((r) => r.path == _cancelPath).toList();
}

class _MemoryTokenStorage implements TokenStorage {
  String? token = 'current-token';

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String token) async => this.token = token;

  @override
  Future<void> deleteAccessToken() async => token = null;
}
