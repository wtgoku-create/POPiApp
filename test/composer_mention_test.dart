import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pumpComposer(
    WidgetTester tester,
    PopiMessageComposerController controller, {
    required VoidCallback onMention,
    bool active = true,
  }) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PopiMessageComposer(
              controller: controller,
              selectedImages: const [],
              enableMentions: true,
              active: active,
              onMentionRequested: onMention,
              onAttachment: () {},
              onRemoveImage: (_) {},
              onHeightChanged: (_) {},
              onSubmitted: (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('typing @ at the caret opens mention picker once', (
    tester,
  ) async {
    final controller = PopiMessageComposerController(initialText: '前后');
    addTearDown(controller.dispose);
    var requests = 0;
    await pumpComposer(tester, controller, onMention: () => requests++);
    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '前@后',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();

    expect(requests, 1);
  });

  testWidgets('programmatic @ and inactive editor do not open picker', (
    tester,
  ) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);
    var requests = 0;
    await pumpComposer(
      tester,
      controller,
      active: false,
      onMention: () => requests++,
    );

    await controller.setText('@');
    await tester.pump();
    expect(requests, 0);

    await tester.tap(find.byKey(const Key('popi-message-input')));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '@@',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    expect(requests, 0);
  });
}
