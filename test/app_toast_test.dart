import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_toast.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('info toast uses the compact surface style and can be closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ToastificationWrapper(
        config: const ToastificationConfig(itemWidth: 320),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => AppToast.info(
                    context,
                    'Hi, Bytedance dance dance',
                  ),
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

    expect(find.text('Hi, Bytedance dance dance'), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    final toastContainer =
        tester.widgetList<Container>(find.byType(Container)).firstWhere(
      (container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration &&
            decoration.borderRadius == BorderRadius.circular(AppRadii.small);
      },
    );
    final decoration = toastContainer.decoration! as BoxDecoration;
    expect(decoration.color?.toARGB32(), AppColors.surface.toARGB32());
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
    expect(toastContainer.constraints?.minHeight, 48);
    expect(toastContainer.constraints?.maxWidth, 320);
    expect(tester.getSize(find.byWidget(toastContainer)).width, 304);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Bytedance dance dance'), findsNothing);
  });
}
