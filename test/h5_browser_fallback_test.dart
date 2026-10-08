import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/pages/h5_page.dart';

void main() {
  testWidgets('offers browser fallback on unsupported platforms', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: H5Page(
          title: '隐私政策',
          url: Uri.parse('https://example.com/privacy'),
        ),
      ),
    );
    expect(find.text('请在浏览器中查看此页面'), findsOneWidget);
    expect(find.text('在浏览器中打开'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
  });
}
