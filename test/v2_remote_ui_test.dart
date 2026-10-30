import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/v2_assets/presentation/v2_import_sheet.dart';
import 'package:popi_ai_app/features/v2_session/presentation/v2_chat_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/features/v2_session/presentation/widgets/v2_preferences_sheet.dart';
import 'package:popi_ai_app/features/v2_session/presentation/widgets/v2_question_card.dart';
import 'package:popi_ai_app/features/v2_session/presentation/widgets/v2_role_create_sheet.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_repository.dart';
import 'package:popi_ai_app/features/v2_shared/domain/v2_models.dart';
import 'package:popi_ai_app/features/v2_shared/presentation/widgets/v2_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

class _Remote extends V2Repository {
  _Remote(super.storage);
  bool fail = false;
  int sends = 0;
  Map<String, Object?>? answer;
  @override
  bool get isRemote => true;
  @override
  Future<void> sendMessage(String id, String text, List<String> assets) async {
    sends++;
    if (fail) throw StateError('Offline');
  }

  @override
  Future<void> respondQuestion(
    String id,
    V2Question question,
    String action,
    Map<String, Object?> answer,
  ) async {
    if (fail) throw StateError('Offline');
    this.answer = answer;
  }
}

const _capture = Key('remote-capture');
Future<void> _screenshot(WidgetTester tester, String name) async {
  final directory = Platform.environment['V2_PREVIEW_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  late _Remote repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = _Remote(
      PreferencesStorage(await SharedPreferences.getInstance()),
    );
  });
  tearDown(() => repository.dispose());
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _capture,
        child: ProviderScope(
          child: ToastificationWrapper(
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('failed send retains composer and acceptance clears it', (
    tester,
  ) async {
    await pump(tester, V2ChatPage(repository: repository, sessionId: 'alice'));
    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('Create an image');
    await tester.pumpAndSettle();
    repository.fail = true;
    await tester.tap(find.byKey(const Key('popi-send-button')));
    await tester.pumpAndSettle();
    expect(repository.sends, 1);
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    expect(composer.controller.markdown, 'Create an image');
    repository.fail = false;
    await tester.tap(find.byKey(const Key('popi-send-button')));
    await tester.pumpAndSettle();
    expect(repository.sends, 2);
    expect(composer.controller.markdown, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  for (final width in [320.0, 1200.0]) {
    for (final name in ['upload', 'character', 'preferences']) {
      testWidgets('$name sheet fits English viewport $width', (tester) async {
        await pump(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: IconButton(
                  key: const Key('open'),
                  icon: const Icon(Icons.add),
                  onPressed: () => V2Sheet.show<void>(
                    context: context,
                    builder: (_) => switch (name) {
                      'upload' => V2ImportSheet(repository: repository),
                      'character' => V2RoleCreateSheet(repository: repository),
                      _ => V2PreferencesSheet(
                        repository: repository,
                        session: repository.session('alice'),
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
          width: width,
        );
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _screenshot(tester, '$name-${width.toInt()}');
      });
    }
  }

  testWidgets(
    'question failure keeps custom answer and allows confirmation again',
    (tester) async {
      const question = V2Question(
        id: 'q',
        revision: 1,
        status: 'pending',
        questions: [
          V2QuestionField(
            id: 'tone',
            question: 'Which tone?',
            options: [V2QuestionOption(label: 'Warm')],
          ),
        ],
      );
      await pump(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: V2QuestionCard(
              question: question,
              repository: repository,
              sessionId: 'alice',
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'Playful');
      repository.fail = true;
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Playful'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repository.answer, {'tone': 'Playful'});
      expect(tester.takeException(), isNull);
    },
  );
}
