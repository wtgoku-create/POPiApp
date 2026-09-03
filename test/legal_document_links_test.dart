import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/shared/widgets/legal_document_links.dart';

void main() {
  testWidgets('opens the user agreement and privacy policy URLs',
      (tester) async {
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
