import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/activities/presentation/activities_page.dart';
import 'package:popi_ai_app/features/activities/presentation/activity_detail_page.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:toastification/toastification.dart';

import 'support/activity_fixtures.dart';

const _previewDirectory = String.fromEnvironment('ACTIVITY_SCREENSHOT_DIR');
const _previewFont = String.fromEnvironment('ACTIVITY_SCREENSHOT_FONT');

void main() {
  setUpAll(() async {
    if (_previewFont.isNotEmpty) {
      final loader = FontLoader('ActivityPreview');
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File(_previewFont).readAsBytes()),
        ),
      );
      await loader.load();
    }
  });
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  Future<ProviderContainer> pumpPage(
    WidgetTester tester,
    ActivityFixture fixture, {
    String route = '/activities',
    User? user = const User(id: '1', name: 'User', email: '', memberLevel: 1),
    Size size = const Size(440, 956),
    bool dark = false,
    Locale locale = const Locale('zh'),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => fixture.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(fixture.dio)],
    );
    addTearDown(container.dispose);
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.only(top: 52, bottom: 34));
    if (user != null) await container.read(userProvider.notifier).setUser(user);
    final router = container.read(routerProvider(false));
    router.go(route);
    addTearDown(router.dispose);
    var theme = dark ? AppTheme.dark : AppTheme.light;
    if (_previewFont.isNotEmpty) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'ActivityPreview'),
      );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const Key('activity-test-boundary'),
          child: ToastificationWrapper(
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: theme,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> submit(WidgetTester tester, String code) async {
    final input = find.byKey(const Key('activity-code-input'));
    await tester.ensureVisible(input);
    await tester.enterText(input, code);
    await tester.pump();
    final button = find.byKey(const Key('activity-submit'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (_previewDirectory.isEmpty) return;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/activity_exchange_banner.png'),
        tester.element(find.byKey(const Key('activity-test-boundary'))),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('activity-test-boundary')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('$_previewDirectory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> clearToasts(WidgetTester tester) async {
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets(
    'list navigates to the selected activity and back preserves its catalog',
    (tester) async {
      final fixture = ActivityFixture();
      await pumpPage(tester, fixture);
      expect(find.text('活动中心'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      await tester.tap(find.byKey(const Key('activity-2')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDetailPage), findsOneWidget);
      expect(find.text('订单编号'), findsOneWidget);
      expect(
        fixture.requests.where((item) => item.path.endsWith('/activity/list')),
        hasLength(1),
      );
      await tester.tap(find.byKey(const Key('activity-back')).last);
      await tester.pumpAndSettle();
      expect(find.byType(ActivitiesPage), findsOneWidget);
      expect(
        fixture.requests.where((item) => item.path.endsWith('/activity/list')),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('list errors retry and empty activities remain refreshable', (
    tester,
  ) async {
    final fixture = ActivityFixture()..listFails = true;
    await pumpPage(tester, fixture);
    expect(find.text('活动加载失败，请重试'), findsOneWidget);
    fixture.listFails = false;
    fixture.activities = [];
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('暂无活动'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets(
    'ordinary redemption posts a code, clears it and refreshes benefits',
    (tester) async {
      final fixture = ActivityFixture();
      final container = await pumpPage(tester, fixture, route: '/activities/1');
      await submit(tester, ' CODE ');
      await tester.pumpAndSettle();
      expect(
        fixture.requests
            .where((item) => item.path.endsWith('/activeCode/use'))
            .single
            .data,
        {'code': 'CODE'},
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('activity-code-input')))
            .controller!
            .text,
        isEmpty,
      );
      expect(container.read(userProvider)?.allCoins, 500);
      expect(find.text('兑换成功'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await clearToasts(tester);
    },
  );

  testWidgets('failed redemption retains the code for retry', (tester) async {
    final fixture = ActivityFixture()..activationStatus = '9999';
    await pumpPage(tester, fixture, route: '/activities/1');
    await submit(tester, 'INVALID');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      fixture.requests.where((item) => item.path.endsWith('/activeCode/use')),
      hasLength(1),
    );
    expect(find.text('兑换码无效'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('activity-code-input')))
          .controller!
          .text,
      'INVALID',
    );
    expect(
      fixture.requests.where((item) => item.path.endsWith('/user/info')),
      isEmpty,
    );
    await clearToasts(tester);
    fixture.activationStatus = '0000';
    await tester.tap(find.byKey(const Key('activity-submit')));
    await tester.pumpAndSettle();
    expect(
      fixture.requests.where((item) => item.path.endsWith('/activeCode/use')),
      hasLength(2),
    );
    await clearToasts(tester);
  });

  testWidgets('disallowed membership and guests cannot submit codes', (
    tester,
  ) async {
    final fixture = ActivityFixture();
    await pumpPage(
      tester,
      fixture,
      route: '/activities/2',
      user: const User(id: '1', name: 'User', email: ''),
    );
    expect(find.textContaining('当前活动仅限'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('activity-code-input')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('activity-submit')))
          .onPressed,
      isNull,
    );
    expect(
      fixture.requests.where((item) => item.path.endsWith('/activeCode/use')),
      isEmpty,
    );
  });

  testWidgets(
    'guests can browse campaigns and receive a login action on details',
    (tester) async {
      final fixture = ActivityFixture();
      await pumpPage(tester, fixture, route: '/activities/1', user: null);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('activity-submit')),
      );
      expect(button.onPressed, isNotNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('activity-code-input')))
            .enabled,
        isFalse,
      );
      expect(
        fixture.requests.where((item) => item.path.endsWith('/activeCode/use')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'book-card acknowledgement gates redemption and displays its QR result',
    (tester) async {
      final fixture = ActivityFixture()
        ..qrUrl = '[QR](https://example.test/qr.png)';
      await pumpPage(tester, fixture, route: '/activities/2');
      await submit(tester, 'ORDER');
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('activity-final-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(
        fixture.requests.where((item) => item.path.endsWith('/activeCode/use')),
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('activity-refund-acknowledgement')),
        '我已知晓领取后不可退款',
      );
      await tester.pump();
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        fixture.requests
            .where((item) => item.path.endsWith('/activeCode/use'))
            .single
            .data,
        {'code': 'ORDER'},
      );
      expect(find.text('活动二维码'), findsOneWidget);
      final image = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.semanticLabel == '活动二维码',
        ),
      );
      expect((image.image as NetworkImage).url, 'https://example.test/qr.png');
      expect(find.byKey(const Key('activity-code-input')), findsNothing);
      expect(tester.takeException(), isNull);
      await clearToasts(tester);
    },
  );

  testWidgets('cancelled book-card acknowledgement does not redeem', (
    tester,
  ) async {
    final fixture = ActivityFixture();
    await pumpPage(tester, fixture, route: '/activities/2');
    await submit(tester, 'ORDER');
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      fixture.requests.where((item) => item.path.endsWith('/activeCode/use')),
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('activity-code-input')))
          .controller!
          .text,
      'ORDER',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('activity-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'pending redemption cannot submit twice or refresh another account',
    (tester) async {
      final fixture = ActivityFixture()..pendingActivation = Completer<void>();
      final container = await pumpPage(tester, fixture, route: '/activities/1');
      await submit(tester, 'CODE');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('activity-submit')))
            .onPressed,
        isNull,
      );
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '2', name: 'Other', email: ''));
      fixture.pendingActivation!.complete();
      await tester.pumpAndSettle();
      expect(container.read(userProvider)?.id, '2');
      expect(
        fixture.requests.where((item) => item.path.endsWith('/user/info')),
        isEmpty,
      );
      expect(find.text('兑换成功'), findsNothing);
    },
  );

  testWidgets('a late benefit refresh cannot restore the previous account', (
    tester,
  ) async {
    final fixture = ActivityFixture()..pendingRefresh = Completer<void>();
    final container = await pumpPage(tester, fixture, route: '/activities/1');
    await submit(tester, 'CODE');
    await tester.pump(const Duration(milliseconds: 200));
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '2', name: 'Other', email: ''));
    fixture.pendingRefresh!.complete();
    await tester.pumpAndSettle();
    expect(container.read(userProvider)?.id, '2');
    expect(container.read(userProvider)?.allCoins, 0);
    await clearToasts(tester);
  });

  testWidgets('expired deep links display an unavailable state', (
    tester,
  ) async {
    final fixture = ActivityFixture();
    await pumpPage(tester, fixture, route: '/activities/999');
    expect(find.text('活动已结束或暂未开放'), findsOneWidget);
    expect(find.byKey(const Key('activity-submit')), findsNothing);
  });

  for (final size in [
    const Size(440, 956),
    const Size(320, 640),
    const Size(1024, 768),
  ]) {
    testWidgets('activity list and detail fit $size with accessible controls', (
      tester,
    ) async {
      final fixture = ActivityFixture();
      if (size.width != 440) {
        fixture.activities.first['name'] =
            'A campaign with a long descriptive title';
        fixture.activities.first['desp'] =
            'Redemption benefits for eligible creators';
      }
      await pumpPage(
        tester,
        fixture,
        size: size,
        dark: size.width == 320,
        locale: Locale(size.width == 440 ? 'zh' : 'en'),
        scale: size.width == 440 ? 1 : 1.3,
      );
      await screenshot(tester, 'list-${size.width.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('activity-1')));
      await tester.pumpAndSettle();
      await screenshot(tester, 'detail-${size.width.toInt()}');
      await tester.ensureVisible(find.byKey(const Key('activity-code-input')));
      await tester.enterText(
        find.byKey(const Key('activity-code-input')),
        'CODE',
      );
      await tester.ensureVisible(find.byKey(const Key('activity-submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('activity-submit')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
