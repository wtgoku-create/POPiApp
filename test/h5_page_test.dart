import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/pages/h5_page.dart';

import 'support/fake_webview.dart';

void main() {
  late FakeWebViewPlatform platform;
  final url = Uri.parse('https://example.com/privacy');

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  Future<void> openPage(WidgetTester tester, {Uri? pageUrl}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: H5Page(title: '隐私政策', url: pageUrl ?? url),
      ),
    );
    await tester.pump();
  }

  testWidgets('loads the URL without credentials and shows progress', (
    tester,
  ) async {
    await openPage(tester);
    expect(platform.controller.requests.single.uri, url);
    expect(platform.controller.requests.single.headers, isEmpty);
    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    platform.delegate.onProgress(60);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .6,
    );

    platform.delegate.onPageFinished(url.toString());
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('ignores subresource errors and retries main-frame failures', (
    tester,
  ) async {
    await openPage(tester);
    platform.delegate.onWebResourceError(
      const WebResourceError(
        errorCode: -1,
        description: 'Image unavailable',
        isForMainFrame: false,
      ),
    );
    await tester.pump();
    expect(find.text('页面加载失败，请稍后重试'), findsNothing);

    platform.delegate.onWebResourceError(
      const WebResourceError(
        errorCode: -2,
        description: 'Offline',
        isForMainFrame: true,
      ),
    );
    platform.delegate.onPageFinished(url.toString());
    await tester.pump();
    expect(find.text('页面加载失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(platform.controller.requests.length, 2);
    expect(find.byType(WebViewWidget), findsOneWidget);
  });

  testWidgets('handles HTTP failures and load exceptions', (tester) async {
    await openPage(tester);
    platform.delegate.onHttpError(
      HttpResponseError(
        request: WebResourceRequest(uri: url),
        response: WebResourceResponse(uri: url, statusCode: 503),
      ),
    );
    await tester.pump();
    expect(find.text('重试'), findsOneWidget);

    platform.controller.failNextLoad = true;
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('页面加载失败，请稍后重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('页面加载失败，请稍后重试'), findsNothing);
  });

  testWidgets('rejects non-web URLs and app scheme navigation', (tester) async {
    await openPage(tester, pageUrl: Uri.parse('file:///private/data'));
    expect(platform.controller.requests, isEmpty);
    expect(find.text('页面加载失败，请稍后重试'), findsOneWidget);
    expect(
      await platform.delegate.onNavigationRequest(
        const NavigationRequest(url: 'feishu://open', isMainFrame: true),
      ),
      NavigationDecision.prevent,
    );
    expect(
      await platform.delegate.onNavigationRequest(
        NavigationRequest(url: url.toString(), isMainFrame: true),
      ),
      NavigationDecision.navigate,
    );
  });
}
