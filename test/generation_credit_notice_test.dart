import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/generation_credit_notice.dart';

void main() {
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'credit notice emphasizes non-refundable points in $locale at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: const Scaffold(
                    body: Padding(
                      padding: EdgeInsets.all(24),
                      child: GenerationCreditNotice(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = lookupAppLocalizations(locale);
          final text = tester.widget<Text>(
            find.text(l10n.generationCreditNotice),
          );
          final spans = (text.textSpan! as TextSpan).children!;
          final emphasized = spans.whereType<TextSpan>().singleWhere(
            (span) => span.style?.fontWeight == FontWeight.bold,
          );
          expect(emphasized.text, l10n.generationCreditNoticeNonRefundable);
          expect(text.textSpan!.toPlainText(), l10n.generationCreditNotice);
          expect(
            tester.getSize(find.byType(RichText)).width,
            lessThanOrEqualTo(272),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
