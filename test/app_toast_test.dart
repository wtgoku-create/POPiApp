import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_toast.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('info toast uses the compact surface style and can be closed', (
    tester,
  ) async {
    var message = 'Hi';
    await tester.pumpWidget(
      ToastificationWrapper(
        config: const ToastificationConfig(itemWidth: 320),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => AppToast.info(context, message),
                  child: const Text('Show toast'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show toast'));
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    expect(find.text('Hi'), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    final toastFinder = find.byWidgetPredicate(
      (widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.borderRadius == BorderRadius.circular(AppRadii.small);
      },
    );
    final toastContainer = tester.widget<Container>(toastFinder);
    final decoration = toastContainer.decoration! as BoxDecoration;
    expect(decoration.color?.toARGB32(), AppColors.surface.toARGB32());
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
    expect(toastContainer.constraints?.minHeight, 48);
    expect(toastContainer.constraints?.maxWidth, 320);
    expect(tester.getSize(toastFinder).width, lessThan(304));
    expect(tester.getCenter(toastFinder).dx, 400);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Hi'), findsNothing);

    message = 'A long toast message that wraps while keeping the existing '
        'maximum width and close button visible.';
    await tester.tap(find.text('Show toast'));
    await tester.pumpAndSettle();

    expect(tester.getSize(toastFinder).width, 304);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });
}
