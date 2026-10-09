import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/features/h5/presentation/h5_page.dart';
import 'package:popi_ai_app/shared/widgets/legal_document_links.dart';

import 'support/fake_webview.dart';

void main() {
  testWidgets('both legal links open the shared H5 page and return', (
    tester,
  ) async {
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    final container = ProviderContainer();
    final appRouter = container.read(routerProvider(false));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: LegalDocumentLinks(
              text: '我已阅读并同意《用户协议》和《隐私政策》',
              userAgreementLabel: '用户协议',
              privacyPolicyLabel: '隐私政策',
              openFailedMessage: '无法打开',
              style: TextStyle(),
              linkStyle: TextStyle(),
            ),
          ),
        ),
        ...appRouter.configuration.routes.where(
          (route) => route is GoRoute && route.path.startsWith('/legal/'),
        ),
      ],
    );
    addTearDown(() {
      router.dispose();
      appRouter.dispose();
      container.dispose();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
    await tester.pumpAndSettle();

    final documents = [
      ('/legal/user-agreement', '用户协议', userAgreementUrl),
      ('/legal/privacy-policy', '隐私政策', privacyPolicyUrl),
    ];
    for (var index = 0; index < documents.length; index++) {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(LegalDocumentLinks),
          matching: find.byType(Text),
        ),
      );
      final links = (text.textSpan! as TextSpan).children!
          .cast<TextSpan>()
          .where((span) => span.recognizer != null)
          .toList();
      (links[index].recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final (path, title, url) = documents[index];
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        path,
      );
      expect(tester.widget<H5Page>(find.byType(H5Page)).title, title);
      expect(platform.controller.requests.single.uri.toString(), url);
      platform.delegate.onPageFinished(url);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(H5Page), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/');
    }
  });

  testWidgets('opens the user agreement and privacy policy URLs', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegalDocumentLinks(
            text: '我已阅读并同意《用户协议》和《隐私政策》',
            userAgreementLabel: '用户协议',
            privacyPolicyLabel: '隐私政策',
            openFailedMessage: '无法打开',
            style: const TextStyle(),
            linkStyle: const TextStyle(decoration: TextDecoration.underline),
            urlLauncher: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text).last);
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    final links = spans.where((span) => span.recognizer != null).toList();
    expect(links.map((span) => span.text), ['用户协议', '隐私政策']);

    (links[0].recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    (links[1].recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();

    expect(opened.map((uri) => uri.toString()), [
      userAgreementUrl,
      privacyPolicyUrl,
    ]);
  });
}
