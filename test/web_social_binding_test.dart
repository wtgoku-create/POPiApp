@TestOn('browser')
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
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
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/type/social_app_type.dart';

void main() {
  late _Api api;
  late _Wechat wechat;
  late _Douyin douyin;
  late SocialAppBindingRepository repository;
  late ProviderContainer container;

  setUp(() async {
    toastification.managers.clear();
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    wechat = _Wechat();
    douyin = _Douyin();
    repository = SocialAppBindingRepository(
      api: api,
      wechatService: wechat,
      douyinService: douyin,
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
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

  Future<void> mount(
    WidgetTester tester, {
    bool profile = false,
    double width = 1200,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                ? ProfilePage(socialBindingRepository: repository)
                : Scaffold(
                    body: SocialAppBindingRow(
                      app: SocialAppType.wechat,
                      repository: repository,
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('profile-wechat-binding')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web-wechat-binding-panel')), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('web-wechat-binding-panel'))),
    )!;
    expect(find.text(l10n.redemptionBindAction), findsOneWidget);
    expect(find.text('微信扫码登录'), findsNothing);
    expect(wechat.calls, 0);
    expect(douyin.calls, 0);
    expect(api.nativeBinds, 0);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  }

  for (final width in [320.0, 1200.0]) {
    testWidgets('Web profile hides Douyin and links WeChat by QR at $width', (
      tester,
    ) async {
      await mount(tester, profile: true, width: width);
      expect(find.byKey(const Key('profile-douyin-binding')), findsNothing);
      expect(api.queries, [SocialAppType.wechat]);
      await tester.ensureVisible(
        find.byKey(const Key('profile-wechat-binding')),
      );
      await open(tester);
      api.binding = const SocialAppBinding(bound: true, nickname: '微信昵称');
      api.checks.single.complete({'bound': true, 'status': 'success'});
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('微信昵称'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  }

  testWidgets('cancel stops polling and ignores a late binding result', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    await tester.tap(find.byKey(const Key('web-social-login-cancel')));
    await tester.pumpAndSettle();
    expect(api.tokens.single.isCancelled, isTrue);
    api.checks.single.complete({'status': 'success', 'bound': true});
    await tester.pumpAndSettle();
    expect(find.text('未绑定'), findsOneWidget);
    expect(api.queries, [SocialAppType.wechat]);
    await tester.pump(const Duration(seconds: 3));
    expect(api.checks.length, 1);
    await finish(tester);
  });

  testWidgets('refresh cancels the old scene and only accepts the new one', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    await tester.tap(find.byKey(const Key('web-social-login-refresh')));
    await tester.pumpAndSettle();
    expect(api.tokens.first.isCancelled, isTrue);
    expect(api.scenes, ['scene-1', 'scene-2']);
    api.checks.first.complete({'status': 'success', 'bound': true});
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    api.binding = const SocialAppBinding(bound: true, nickname: '新二维码绑定');
    api.checks.last.complete({'status': 'success'});
    await tester.pumpAndSettle();
    expect(find.text('新二维码绑定'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await finish(tester);
  });

  testWidgets('polling is serial and QR expiry cancels pending checks', (
    tester,
  ) async {
    api.expireSeconds = 5;
    await mount(tester);
    await open(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(api.checks.length, 1);
    api.checks.first.complete({'status': 'waiting', 'bound': false});
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(api.checks.length, 2);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('授权已过期'), findsOneWidget);
    expect(api.tokens.last.isCancelled, isTrue);
    await tester.tap(find.byKey(const Key('web-social-login-cancel')));
    await tester.pumpAndSettle();
    await finish(tester);
  });

  testWidgets('account change closes QR and cannot update the next user', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'user-2', name: 'Next', email: ''));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(api.tokens.single.isCancelled, isTrue);
    api.checks.single.complete({'bound': true});
    await tester.pumpAndSettle();
    expect(find.text('未绑定'), findsOneWidget);
    expect(container.read(userProvider)?.id, 'user-2');
    await finish(tester);
  });

  testWidgets('nickname refresh failure still completes a confirmed binding', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    api.statusFails = true;
    api.checks.single.complete({'status': 'success'});
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('已绑定'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('QR failure preserves refresh and reports one error', (
    tester,
  ) async {
    api.qrFails = true;
    await mount(tester);
    await open(tester);
    expect(find.text('绑定失败，请重试'), findsOneWidget);
    api.qrFails = false;
    await tester.tap(find.byKey(const Key('web-social-login-refresh')));
    await tester.pumpAndSettle();
    expect(api.checks.length, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(api.tokens.single.isCancelled, isTrue);
    await finish(tester);
  });
}

class _Api extends SocialAppBindingApi {
  _Api() : super(Dio());
  SocialAppBinding binding = const SocialAppBinding(bound: false);
  final queries = <SocialAppType>[];
  final checks = <Completer<Map<String, dynamic>>>[];
  final tokens = <CancelToken>[];
  final scenes = <String>[];
  int challenges = 0;
  int nativeBinds = 0;
  int expireSeconds = 300;
  bool statusFails = false;
  bool qrFails = false;

  @override
  Future<SocialAppBinding> fetchStatus(SocialAppType app) async {
    queries.add(app);
    if (statusFails) throw StateError('offline');
    return binding;
  }

  @override
  Future<SocialAppBinding> bind(SocialAppType app, String code) async {
    nativeBinds++;
    throw StateError('Native binding must not run on Web');
  }

  @override
  Future<Map<String, dynamic>> createWebWechatChallenge({
    required CancelToken cancelToken,
  }) async {
    if (qrFails) throw StateError('offline');
    challenges++;
    return {
      'sceneCode': 'scene-$challenges',
      'qrCodeUrl':
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
      'expireSeconds': expireSeconds,
    };
  }

  @override
  Future<Map<String, dynamic>> checkWebWechatBinding(
    String sceneCode, {
    required CancelToken cancelToken,
  }) {
    tokens.add(cancelToken);
    scenes.add(sceneCode);
    final pending = Completer<Map<String, dynamic>>();
    checks.add(pending);
    return pending.future;
  }
}

class _Wechat extends WechatLoginService {
  int calls = 0;
  @override
  Future<WechatAuthorizationResult> authorize() async {
    calls++;
    throw StateError('Native SDK must not run on Web');
  }
}

class _Douyin extends DouyinLoginService {
  int calls = 0;
  @override
  Future<DouyinAuthorizationResult> authorize() async {
    calls++;
    throw StateError('Native SDK must not run on Web');
  }
}
