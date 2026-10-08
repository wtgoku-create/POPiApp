import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/data/douyin_login_service.dart';
import 'package:popi_ai_app/features/auth/data/wechat_login_service.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/profile/data/social_app_binding_api.dart';
import 'package:popi_ai_app/features/profile/data/social_app_binding_repository.dart';
import 'package:popi_ai_app/features/profile/domain/social_app_binding.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/widgets/social_app_binding_row.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/social_binding_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/type/social_app_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  late _BindingApi api;
  late _WechatService wechat;
  late _DouyinService douyin;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    api = _BindingApi();
    wechat = _WechatService();
    douyin = _DouyinService();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        socialAppBindingRepositoryProvider.overrideWithValue(
          SocialAppBindingRepository(
            api: api,
            wechatService: wechat,
            douyinService: douyin,
          ),
        ),
      ],
    );
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'user-1', name: 'Test', email: ''));
  });

  tearDown(() {
    toastification.dismissAll(delayForAnimation: false);
    container.dispose();
  });

  Future<void> mount(WidgetTester tester, {bool profile = false}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: profile
                ? const ProfilePage()
                : const Scaffold(
                    body: Column(
                      children: [
                        SizedBox(height: 180),
                        SocialAppBindingRow(app: SocialAppType.wechat),
                        SocialAppBindingRow(app: SocialAppType.douyin),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(SocialAppType app) =>
      find.byKey(Key('profile-${app.name}-binding'));

  Future<void> dismissToasts(WidgetTester tester) async {
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('opening profile queries both accounts without authorization', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, profile: true);
    expect(api.queries, containsAll(SocialAppType.values));
    expect(find.text('未绑定'), findsNWidgets(2));
    expect(wechat.calls, 0);
    expect(douyin.calls, 0);
  });

  for (final app in SocialAppType.values) {
    testWidgets(
      '$app binds once, refreshes nickname, and stays bound on reopening',
      (tester) async {
        final pending = Completer<SocialAppBinding>();
        api.pendingBind = pending.future;
        await mount(tester);
        await tester.tap(row(app));
        await tester.pump();
        await tester.tap(row(app));
        await tester.pump();
        expect(api.bindings, [app]);
        expect(api.codes, [
          app == SocialAppType.wechat ? 'wechat-code' : 'douyin-code',
        ]);
        pending.complete(
          const SocialAppBinding(bound: true, nickname: 'Bound nickname'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bound nickname'), findsOneWidget);
        await dismissToasts(tester);
        await tester.tap(row(app));
        await tester.pumpAndSettle();
        expect(api.bindings, [app]);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        api.pendingBind = null;
        await mount(tester);
        expect(find.text('Bound nickname'), findsOneWidget);
        expect(api.queries.where((value) => value == app).length, 2);
      },
    );

    testWidgets('$app handles cancellation and allows retry', (tester) async {
      wechat.result = const WechatAuthorizationResult.canceled();
      douyin.result = const DouyinAuthorizationResult.canceled();
      await mount(tester);
      await tester.tap(row(app));
      await tester.pumpAndSettle();
      expect(api.bindings, isEmpty);
      expect(find.text('已取消绑定'), findsOneWidget);
      await dismissToasts(tester);
      wechat.result = const WechatAuthorizationResult.authorized('wechat-code');
      douyin.result = const DouyinAuthorizationResult.authorized('douyin-code');
      await tester.tap(row(app));
      await tester.pumpAndSettle();
      expect(api.bindings, [app]);
      await dismissToasts(tester);
    });
  }

  testWidgets('query failure retries independently from the other account', (
    tester,
  ) async {
    api.queryFails = true;
    api.statuses[SocialAppType.douyin] = const SocialAppBinding(bound: true);
    await mount(tester);
    expect(find.text('查询失败，重试'), findsOneWidget);
    expect(find.text('已绑定'), findsOneWidget);
    api.queryFails = false;
    await tester.tap(row(SocialAppType.wechat));
    await tester.pumpAndSettle();
    expect(find.text('未绑定'), findsOneWidget);
    expect(api.bindings, isEmpty);
    expect(api.queries.where((app) => app == SocialAppType.douyin).length, 1);
  });

  testWidgets('binding failure keeps unbound state for retry', (tester) async {
    api.bindFails = true;
    await mount(tester);
    await tester.tap(row(SocialAppType.wechat));
    await tester.pumpAndSettle();
    expect(find.text('绑定失败，请重试'), findsOneWidget);
    expect(find.text('未绑定'), findsNWidgets(2));
    await dismissToasts(tester);
    api.bindFails = false;
    await tester.tap(row(SocialAppType.wechat));
    await tester.pumpAndSettle();
    expect(find.text('Bound nickname'), findsOneWidget);
    await dismissToasts(tester);
  });

  testWidgets('account change clears prior nickname and reloads server state', (
    tester,
  ) async {
    api.statuses[SocialAppType.wechat] = const SocialAppBinding(
      bound: true,
      nickname: 'Old user',
    );
    await mount(tester);
    expect(find.text('Old user'), findsOneWidget);
    api.statuses.clear();
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'user-2', name: 'Next', email: ''));
    await tester.pumpAndSettle();
    expect(find.text('Old user'), findsNothing);
    expect(find.text('未绑定'), findsNWidgets(2));
    expect(api.queries.length, 4);
  });

  testWidgets(
    'account change during authorization prevents binding the next user',
    (tester) async {
      final pending = Completer<WechatAuthorizationResult>();
      wechat.pending = pending.future;
      await mount(tester);
      await tester.tap(row(SocialAppType.wechat));
      await tester.pump();
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'user-2', name: 'Next', email: ''));
      pending.complete(const WechatAuthorizationResult.authorized('old-code'));
      await tester.pumpAndSettle();
      expect(api.bindings, isEmpty);
      expect(find.text('未绑定'), findsNWidgets(2));
    },
  );

  testWidgets('long bound nicknames fit a compact screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    api.statuses[SocialAppType.wechat] = SocialAppBinding(
      bound: true,
      nickname: 'Long nickname ' * 20,
    );
    await mount(tester);
    expect(tester.takeException(), isNull);
  });
}

class _BindingApi extends SocialAppBindingApi {
  _BindingApi() : super(Dio());

  final queries = <SocialAppType>[];
  final bindings = <SocialAppType>[];
  final codes = <String>[];
  final statuses = <SocialAppType, SocialAppBinding>{};
  bool queryFails = false;
  bool bindFails = false;
  Future<SocialAppBinding>? pendingBind;

  @override
  Future<SocialAppBinding> fetchStatus(SocialAppType app) async {
    queries.add(app);
    if (queryFails && app == SocialAppType.wechat) throw Exception('offline');
    return statuses[app] ?? const SocialAppBinding(bound: false);
  }

  @override
  Future<SocialAppBinding> bind(SocialAppType app, String code) async {
    bindings.add(app);
    codes.add(code);
    if (bindFails) throw Exception('bind failed');
    final binding =
        await (pendingBind ??
            Future.value(
              const SocialAppBinding(bound: true, nickname: 'Bound nickname'),
            ));
    statuses[app] = binding;
    return binding;
  }
}

class _WechatService extends WechatLoginService {
  int calls = 0;
  WechatAuthorizationResult result = const WechatAuthorizationResult.authorized(
    'wechat-code',
  );
  Future<WechatAuthorizationResult>? pending;

  @override
  Future<WechatAuthorizationResult> authorize() async {
    calls++;
    return pending ?? result;
  }
}

class _DouyinService extends DouyinLoginService {
  int calls = 0;
  DouyinAuthorizationResult result = const DouyinAuthorizationResult.authorized(
    'douyin-code',
  );

  @override
  Future<DouyinAuthorizationResult> authorize() async {
    calls++;
    return result;
  }
}
