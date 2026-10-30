import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/h5/presentation/h5_page.dart';
import 'package:popi_ai_app/features/notifications/domain/app_notification.dart';
import 'package:popi_ai_app/features/notifications/presentation/notification_detail_page.dart';
import 'package:popi_ai_app/features/privacy/presentation/privacy_consent_page.dart';
import 'package:popi_ai_app/features/profile/presentation/about_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/legal_document_links.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/fake_webview.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  ProviderContainer? container,
}) async {
  final app = MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
  await tester.pumpWidget(
    container == null
        ? ProviderScope(child: app)
        : UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
}

void _tapLegalLink(WidgetTester tester, String label) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byType(LegalDocumentLinks),
      matching: find.byType(Text),
    ),
  );
  final link = (text.textSpan! as TextSpan).children!
      .cast<TextSpan>()
      .singleWhere((span) => span.text == label);
  (link.recognizer! as TapGestureRecognizer).onTap!();
}

void main() {
  tearDown(() {
    H5Page.debugBrowserLauncher = null;
    toastification.dismissAll(delayForAnimation: false);
  });

  if (!kIsWeb) {
    testWidgets(
      'native H5 navigation keeps the embedded page and original URL',
      (tester) async {
        final platform = FakeWebViewPlatform();
        WebViewPlatform.instance = platform;
        final url = Uri.parse('https://example.com/document?a=1#section');
        await _pump(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    H5Page.open(context, title: 'Document', url: url),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(H5Page), findsOneWidget);
        expect(platform.controller.requests.single.uri, url);
        expect(platform.controller.requests.single.headers, isEmpty);
        platform.delegate.onPageFinished(url.toString());
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
      },
    );
    return;
  }

  final opened = <Uri>[];
  setUp(() {
    opened.clear();
    H5Page.debugBrowserLauncher =
        (url, {required mode, required webOnlyWindowName}) async {
          expect(mode, LaunchMode.externalApplication);
          expect(webOnlyWindowName, '_blank');
          opened.add(url);
          return true;
        };
  });

  testWidgets('Web About links launch both original URLs without routing', (
    tester,
  ) async {
    await _pump(tester, const AboutPage());
    for (final (key, url) in [
      ('profile-about-user-agreement', userAgreementUrl),
      ('profile-about-privacy-policy', privacyPolicyUrl),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(opened.last, Uri.parse(url));
      expect(find.byType(AboutPage), findsOneWidget);
      expect(find.byType(H5Page), findsNothing);
    }
  });

  testWidgets('Web consent document links leave the blocking notice intact', (
    tester,
  ) async {
    await _pump(tester, const PrivacyConsentPage());
    for (final label in ['用户协议', '隐私政策']) {
      _tapLegalLink(tester, label);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacy-consent-dialog')), findsOneWidget);
      expect(find.byType(H5Page), findsNothing);
    }
    expect(opened, [Uri.parse(userAgreementUrl), Uri.parse(privacyPolicyUrl)]);
  });

  testWidgets('Web legal links open tabs without requiring an app router', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(
        body: LegalDocumentLinks(
          text: 'Read Terms and Privacy',
          userAgreementLabel: 'Terms',
          privacyPolicyLabel: 'Privacy',
          style: TextStyle(),
          linkStyle: TextStyle(),
          openFailedMessage: 'Open failed',
        ),
      ),
    );
    for (final label in ['Terms', 'Privacy']) {
      _tapLegalLink(tester, label);
      await tester.pumpAndSettle();
      expect(find.byType(H5Page), findsNothing);
      expect(find.byType(LegalDocumentLinks), findsOneWidget);
    }
    expect(opened, [Uri.parse(userAgreementUrl), Uri.parse(privacyPolicyUrl)]);
    expect(find.text('Open failed'), findsNothing);
  });

  testWidgets(
    'Web notification destinations open a tab and retain the detail',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: 'User', email: ''));
      final url = Uri.parse('https://example.com/news?source=notice#detail');
      await _pump(
        tester,
        NotificationDetailPage(
          notification: AppNotification(
            id: 1,
            title: 'News',
            content: 'Details',
            isUnread: false,
            target: NotificationTarget.web(url),
          ),
          userId: '1',
        ),
        container: container,
      );
      await tester.tap(find.byKey(const Key('notification-detail-action')));
      await tester.pumpAndSettle();
      expect(opened, [url]);
      expect(find.byType(NotificationDetailPage), findsOneWidget);
      expect(find.byType(H5Page), findsNothing);
    },
  );

  for (final failure in ['false', 'throw', 'invalid']) {
    testWidgets(
      'Web launch failure ($failure) preserves input and shows one toast',
      (tester) async {
        var attempts = 0;
        H5Page.debugBrowserLauncher =
            (url, {required mode, required webOnlyWindowName}) async {
              attempts++;
              if (failure == 'throw') throw StateError('Unavailable');
              return false;
            };
        await _pump(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const TextField(),
                  TextButton(
                    onPressed: () => H5Page.open(
                      context,
                      title: 'Document',
                      url: Uri.parse(
                        failure == 'invalid'
                            ? 'javascript:alert(1)'
                            : 'https://example.com',
                      ),
                      openFailedMessage: 'Open failed',
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Unsent draft');
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Open failed'), findsOneWidget);
        expect(find.text('Unsent draft'), findsOneWidget);
        expect(find.byType(H5Page), findsNothing);
        expect(attempts, failure == 'invalid' ? 0 : 1);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
      },
    );
  }
}
