import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/payments/data/android_payment_service.dart';
import 'package:popi_ai_app/features/payments/data/android_payment_sdk.dart';
import 'package:popi_ai_app/features/payments/data/payment_repository.dart';
import 'package:popi_ai_app/features/payments/data/pending_payment_storage.dart';
import 'package:popi_ai_app/features/payments/domain/mobile_payment.dart';
import 'package:popi_ai_app/features/payments/presentation/android_payment_page.dart';
import 'package:popi_ai_app/features/profile/presentation/membership_page.dart';
import 'package:popi_ai_app/features/profile/presentation/points_details_page.dart';
import 'package:popi_ai_app/features/profile/domain/product_plan.dart';
import 'package:popi_ai_app/features/profile/domain/point_package.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/payment_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/type/payment_type.dart';

import 'android_payment_test.dart' show FakePaymentSdk;

const _product = PaymentProduct(
  id: 7,
  kind: PaymentProductKind.points,
  title: '600 积分包',
  priceLabel: '¥6.00',
);

void main() {
  late SharedPreferences preferences;
  late AndroidPaymentService service;
  late FakePaymentSdk sdk;
  final requests = <RequestOptions>[];
  var paid = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    sdk = FakePaymentSdk();
    requests.clear();
    paid = false;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'status': '0000',
                  'data': {
                    'trade_no': 'PTSUSR7',
                    'amount_fen': 600,
                    'order_string': 'signed',
                    'payment_status': paid ? 'paid' : 'pending_payment',
                    'fulfillment_status': paid ? 'completed' : 'pending',
                    'refund_status': 'none',
                  },
                },
              ),
            );
          },
        ),
      );
    service = AndroidPaymentService(
      repository: PaymentRepository(NetworkApi(dio)),
      storage: PendingPaymentStorage(PreferencesStorage(preferences), 'user-1'),
      sdk: sdk,
      supported: true,
      pollAttempts: 1,
      pollInterval: Duration.zero,
    );
  });

  Future<GoRouter> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Locale locale = const Locale('zh'),
    ThemeData? theme,
    Widget? entry,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: entry == null ? '/payment' : '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => entry ?? const Scaffold()),
        GoRoute(
          path: '/payment',
          builder: (_, __) => const AndroidPaymentPage(product: _product),
        ),
        GoRoute(
          path: '/payment/android',
          builder: (_, state) =>
              AndroidPaymentPage(product: state.extra! as PaymentProduct),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        androidPaymentServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(
          const User(id: 'user-1', name: 'User', email: 'user@popi.art'),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ToastificationWrapper(
          child: MaterialApp.router(
            theme: theme ?? AppTheme.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'selects Alipay and queries the existing order instead of creating again',
    (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('payment-method-wechat')), findsOneWidget);
      await tester.tap(find.byKey(const Key('payment-method-alipay')));
      await tester.tap(find.byKey(const Key('payment-confirm')));
      await tester.pumpAndSettle();
      expect(
        requests.first.path,
        '/api_client/users/pointPackage/payByGatewayAppAliPay',
      );
      expect(find.text('再次查询'), findsOneWidget);
      expect(find.text('PTSUSR7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('payment-confirm')));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps confirm disabled while the SDK is running', (
    tester,
  ) async {
    final native = Completer<PaymentSdkOutcome>();
    sdk.onPay = (_) => native.future;
    await pump(tester);
    await tester.tap(find.byKey(const Key('payment-confirm')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('payment-confirm')))
          .onPressed,
      isNull,
    );
    native.complete(PaymentSdkOutcome.unknown);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'restores an unfinished order on page open without another SDK call',
    (tester) async {
      await service.storage.save(
        const PendingPayment(
          product: _product,
          channel: PaymentChannel.alipay,
          tradeNo: 'PTSUSR7',
        ),
      );
      await pump(tester);
      expect(find.text('PTSUSR7'), findsOneWidget);
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(sdk.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new purchase requires an explicit dialog and retains the old order',
    (tester) async {
      await service.storage.save(
        const PendingPayment(
          product: _product,
          channel: PaymentChannel.alipay,
          tradeNo: 'PTSUSR7',
        ),
      );
      await pump(tester);
      await tester.tap(find.text('重新购买'));
      await tester.pumpAndSettle();
      expect(find.textContaining('可能导致重复付款'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(service.storage.read(_product), isNotNull);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  for (final variant in [
    ('compact', const Size(320, 568), const Locale('en'), AppTheme.light),
    ('dark', const Size(390, 844), const Locale('zh'), AppTheme.dark),
    ('desktop', const Size(1280, 800), const Locale('en'), AppTheme.light),
  ]) {
    testWidgets('checkout layout fits ${variant.$1} viewport', (tester) async {
      await pump(
        tester,
        size: variant.$2,
        locale: variant.$3,
        theme: variant.$4,
      );
      expect(find.byKey(const Key('payment-confirm')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('payment-confirm'))).bottom,
        lessThanOrEqualTo(variant.$2.height),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('points purchase opens the shared checkout', (tester) async {
    final package = PointPackage.fromJson({
      'id': 7,
      'name': '600 points',
      'enabled': true,
      'price_amount': 6,
      'currency': 'CNY',
    });
    await pump(
      tester,
      entry: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => purchasePointPackage(context, ref, package),
            child: const Text('Buy points'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buy points'));
    await tester.pumpAndSettle();
    expect(find.byType(AndroidPaymentPage), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('membership purchase opens the same checkout with the plan ID', (
    tester,
  ) async {
    final plan = ProductPlan.fromJson({
      'id': 7,
      'title': 'Starter',
      'level': 1,
      'price': 600,
      'custom_info': {'buttonText': 'Buy membership'},
    });
    await pump(
      tester,
      size: const Size(440, 956),
      entry: MembershipPage(initialPlans: [plan], loadPlansOnOpen: false),
    );
    await tester.tap(find.byKey(const Key('membership-open-button')));
    await tester.pumpAndSettle();
    expect(find.byType(AndroidPaymentPage), findsOneWidget);
    expect(requests.first.path, '/api_client/trade/subscription/previewApp');
    expect(requests.first.data, {'subscriptionId': 7});
  });
}
