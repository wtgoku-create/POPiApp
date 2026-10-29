import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/app.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/h5/presentation/h5_page.dart';
import 'package:popi_ai_app/shared/providers/payment_provider.dart';
import 'package:popi_ai_app/shared/providers/privacy_consent_provider.dart';
import 'package:popi_ai_app/shared/providers/purchase_provider.dart';
import 'package:popi_ai_app/shared/providers/settings_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/legal_document_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/fake_webview.dart';

void main() {
  late SharedPreferences preferences;
  late _FailingStorage storage;
  late _TrackingTokens tokens;
  late ProviderContainer container;
  late List<ProviderBase<Object?>> initialized;
  var readyCalls = 0;
  var routerCreations = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    storage = _FailingStorage(preferences);
    tokens = _TrackingTokens();
    initialized = [];
    readyCalls = 0;
    routerCreations = 0;
    container = ProviderContainer(
      observers: [_StartupObserver(initialized)],
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        preferencesStorageProvider.overrideWithValue(storage),
        secureStorageProvider.overrideWithValue(tokens),
        routerProvider.overrideWith((ref, _) {
          routerCreations++;
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const Scaffold(body: Text('Business home')),
              ),
            ],
          );
          ref.onDispose(router.dispose);
          return router;
        }),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    Locale locale = const Locale('zh'),
  }) async {
    await container.read(localeProvider.notifier).setLocale(locale);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: StarterApp(onReady: () => readyCalls++),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectStartupBlocked() {
    expect(tokens.reads, 0);
    expect(routerCreations, 0);
    expect(initialized, isNot(contains(accessTokenProvider)));
    expect(initialized, isNot(contains(userBootstrapProvider)));
    expect(initialized, isNot(contains(androidPaymentServiceProvider)));
    expect(initialized, isNot(contains(applePurchaseServiceProvider)));
    expect(container.read(privacyConsentProvider), isFalse);
  }

  testWidgets('first launch blocks services, barrier and back dismissal', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byKey(const Key('privacy-consent-dialog')), findsOneWidget);
    expect(readyCalls, 1);
    expectStartupBlocked();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy-consent-dialog')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expectStartupBlocked();
  });

  testWidgets('explicit acceptance persists then opens the business app', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const Key('privacy-consent-accept')));
    await tester.pumpAndSettle();

    expect(find.text('Business home'), findsOneWidget);
    expect(find.byKey(const Key('privacy-consent-dialog')), findsNothing);
    expect(tokens.reads, 1);
    expect(routerCreations, 1);
    expect(readyCalls, 1);
    expect(
      preferences.getString(PrivacyConsentController.storageKey),
      PrivacyConsentController.currentVersion,
    );
  });

  testWidgets('saved consent skips the dialog on subsequent launches', (
    tester,
  ) async {
    await preferences.setString(
      PrivacyConsentController.storageKey,
      PrivacyConsentController.currentVersion,
    );
    await mount(tester);
    expect(find.text('Business home'), findsOneWidget);
    expect(find.byKey(const Key('privacy-consent-dialog')), findsNothing);
  });

  testWidgets(
    'pending acceptance keeps button dimensions and startup blocked',
    (tester) async {
      storage.completion = Completer<void>();
      await mount(tester);
      final accept = find.byKey(const Key('privacy-consent-accept'));
      final initialRect = tester.getRect(accept);
      await tester.tap(accept);
      await tester.pump();
      expect(tester.getRect(accept), initialRect);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      expectStartupBlocked();
      storage.completion!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Business home'), findsOneWidget);
    },
  );

  testWidgets(
    'refusal exits Android without starting services or saving consent',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(tester);
      await tester.tap(find.byKey(const Key('privacy-consent-decline')));
      await tester.pumpAndSettle();

      expect(
        calls.where((call) => call.method == 'SystemNavigator.pop'),
        hasLength(1),
      );
      expect(
        preferences.containsKey(PrivacyConsentController.storageKey),
        isFalse,
      );
      expectStartupBlocked();
      await tester.tap(find.text('查看协议与政策'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacy-consent-dialog')), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('failed saving keeps the dialog and original acceptance action', (
    tester,
  ) async {
    storage.failWrites = true;
    await mount(tester);
    await tester.tap(find.byKey(const Key('privacy-consent-accept')));
    await tester.pumpAndSettle();
    expect(find.text('未能保存您的选择，请再次点击同意并继续'), findsOneWidget);
    expect(find.text('同意并继续'), findsOneWidget);
    expectStartupBlocked();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    storage.failWrites = false;
    await tester.tap(find.byKey(const Key('privacy-consent-accept')));
    await tester.pumpAndSettle();
    expect(find.text('Business home'), findsOneWidget);
  });

  testWidgets(
    'both documents open before consent and return to the same notice',
    (tester) async {
      final platform = FakeWebViewPlatform();
      WebViewPlatform.instance = platform;
      await mount(tester);
      for (final label in ['用户协议', '隐私政策']) {
        final richText = tester.widget<Text>(
          find.descendant(
            of: find.byType(LegalDocumentLinks),
            matching: find.byType(Text),
          ),
        );
        final link = (richText.textSpan! as TextSpan).children!
            .cast<TextSpan>()
            .singleWhere((span) => span.text == label);
        (link.recognizer! as TapGestureRecognizer).onTap!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final page = tester.widget<H5Page>(find.byType(H5Page));
        expect(
          page.url.toString(),
          label == '用户协议' ? userAgreementUrl : privacyPolicyUrl,
        );
        expect(platform.controller.requests.single.headers, isEmpty);
        platform.delegate.onPageFinished(page.url.toString());
        await tester.pump();
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('privacy-consent-dialog')), findsOneWidget);
        expectStartupBlocked();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('small screens can scroll to both actions without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);
    await tester.ensureVisible(find.byKey(const Key('privacy-consent-accept')));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('privacy-consent-accept')));
    await tester.pumpAndSettle();
    expect(find.text('Business home'), findsOneWidget);
  });

  testWidgets('English notice supports large text on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(tester, locale: const Locale('en'));
    await tester.ensureVisible(find.byKey(const Key('privacy-consent-accept')));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('privacy-consent-accept')));
    await tester.pumpAndSettle();
    expect(find.text('Business home'), findsOneWidget);
  });
}

class _TrackingTokens implements TokenStorage {
  int reads = 0;

  @override
  Future<String?> readAccessToken() async {
    reads++;
    return null;
  }

  @override
  Future<void> deleteAccessToken() async {}
  @override
  Future<void> writeAccessToken(String value) async {}
}

class _FailingStorage extends PreferencesStorage {
  _FailingStorage(super.preferences);
  bool failWrites = false;
  Completer<void>? completion;

  @override
  Future<void> setString(String key, String value) async {
    if (key == PrivacyConsentController.storageKey) await completion?.future;
    if (failWrites && key == PrivacyConsentController.storageKey) {
      throw StateError('Storage unavailable');
    }
    await super.setString(key, value);
  }
}

class _StartupObserver extends ProviderObserver {
  _StartupObserver(this.initialized);
  final List<ProviderBase<Object?>> initialized;

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    initialized.add(provider);
  }
}
