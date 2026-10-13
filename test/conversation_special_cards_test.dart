import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_creation.dart';
import 'package:popi_ai_app/features/session/domain/conversation_generation.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_generation_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_task_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:toastification/toastification.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card.dart';

import 'conversation_events_test.dart' show chatId;
import 'support/session_fixtures.dart';

class _CardRepository extends FixtureSessionRepository {
  int estimates = 0;
  bool failEstimateOnce = false;
  ConversationGenerationSelection? submitted;
  final controls = <String>[];
  @override
  Future<num> estimateGeneration(
    String mediaType,
    HomeConfig config, {
    CancelToken? cancelToken,
  }) async {
    estimates++;
    if (failEstimateOnce) {
      failEstimateOnce = false;
      throw StateError('offline');
    }
    return 10;
  }

  @override
  Future<void> confirmGeneration(
    String userId,
    String sessionId,
    ConversationBlock card,
    ConversationGenerationSelection selection, {
    CancelToken? cancelToken,
  }) async {
    submitted = selection;
  }

  @override
  Future<void> controlTask(
    String userId,
    ConversationBlock task,
    String action, {
    Map<String, Object?>? capabilities,
    CancelToken? cancelToken,
  }) async {
    controls.add(action);
  }
}

ConversationBlock _generation() => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'plan',
  'data': {
    'id': 'image-plan',
    'kind': 'generation',
    'title': 'Character three-view',
    'status': 'ready',
    'revision': 1,
    'allowedActions': ['confirm', 'cancel'],
    'roleImage': {'requirements': 'Keep the character silhouette and costume'},
    'presentation': {'requirements': 'A clean character sheet'},
    'plan': {
      'items': [
        {
          'key': 'three_view',
          'mediaType': 'image',
          'modelId': 'model',
          'params': {'ratio': '16:9'},
        },
      ],
    },
  },
});

ConversationBlock _task({bool home = false}) => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'task',
  'action': home ? 'home' : 'workflow',
  'data': {
    'id': 'task',
    'title': 'Story production',
    'state': home ? 'awaiting_confirmation' : 'paused',
    'confirmationPending': home,
    'allowedActions': ['resume', 'cancel'],
    'steps': [
      {
        'key': 'script',
        'state': 'completed',
        'output': {
          'title': 'Episode script',
          'kind': 'script',
          'body': 'Scene 1: A letter arrives.',
        },
      },
      {'key': 'storyboard', 'state': 'pending'},
      {'key': 'video', 'state': 'pending'},
    ],
  },
});

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  GlobalKey? capture,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: const String.fromEnvironment('CONVERSATION_CAPTURE_FONT').isEmpty
          ? AppTheme.light
          : AppTheme.light.copyWith(
              textTheme: AppTheme.light.textTheme.apply(
                fontFamily: 'ConversationCapture',
              ),
            ),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: RepaintBoundary(
          key: capture,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 660,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [child],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const path = String.fromEnvironment('CONVERSATION_CAPTURE_FONT');
    if (path.isEmpty) return;
    await (FontLoader(
      'ConversationCapture',
    )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'estimate failure uses toast and the original generation action can recover',
    (tester) async {
      final repository = _CardRepository()..failEstimateOnce = true;
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ConversationGenerationCard(
          block: _generation(),
          controller: controller,
        ),
      );
      expect(find.text('Request failed. Please try again'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ConversationCard),
          matching: find.text('Request failed. Please try again'),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Retry'), findsNothing);
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      expect(repository.estimates, 2);
      await tester.tap(find.text('Generate').last);
      await tester.pumpAndSettle();
      expect(
        repository.submitted?.requirements,
        'Keep the character silhouette and costume',
      );
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('generation card fits $size at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _CardRepository();
        final controller = ConversationController(repository, 'a')
          ..sessionId = chatId;
        addTearDown(controller.dispose);
        final capture = GlobalKey();
        await _pump(
          tester,
          ConversationGenerationCard(
            block: _generation(),
            controller: controller,
          ),
          capture: capture,
          textScale: scale,
        );
        expect(find.text('Estimated cost: 10 points'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        if (scale == 1 &&
            const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final pixels = await boundary.toImage();
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/conversation-generation-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'generation estimates debounce and confirmation uses current input',
    (tester) async {
      final repository = _CardRepository();
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ConversationGenerationCard(
          block: _generation(),
          controller: controller,
        ),
      );
      expect(repository.estimates, 1);
      final field = find.byType(TextField);
      await tester.enterText(field, 'First requirement');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'Final requirement');
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.estimates, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(repository.estimates, 2);
      await tester.ensureVisible(find.text('Generate'));
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      expect(repository.submitted, isNull);
      await tester.tap(find.text('Generate').last);
      await tester.pumpAndSettle();
      expect(repository.submitted!.requirements, 'Final requirement');
      expect(repository.submitted!.estimatedPoints, 10);
      expect(repository.submitted!.mediaPreferencesRevision, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('workflow controls use capabilities and step content expands', (
    tester,
  ) async {
    final repository = _CardRepository();
    final controller = ConversationController(repository, 'a')
      ..sessionId = chatId;
    addTearDown(controller.dispose);
    await _pump(
      tester,
      ConversationTaskCard(block: _task(), controller: controller),
    );
    expect(
      find.byKey(const Key('conversation-task-pause-task')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('conversation-task-resume-task')),
      findsNothing,
    );
    expect(find.text('Scene 1: A letter arrives.'), findsNothing);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text('Scene 1: A letter arrives.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('conversation-task-pause-task')));
    await tester.pumpAndSettle();
    expect(repository.controls, ['pause']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home video confirmation and profile diff have actual actions', (
    tester,
  ) async {
    final repository = _CardRepository();
    final controller = ConversationController(repository, 'a')
      ..sessionId = chatId;
    addTearDown(controller.dispose);
    final profile = ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'plan',
      'data': {
        'id': 'profile',
        'kind': 'profile_update',
        'title': 'Character profile',
        'before': {'description': 'Before description'},
        'changes': {'description': 'After description'},
        'status': 'ready',
        'allowedActions': ['confirm', 'cancel'],
      },
    });
    await _pump(
      tester,
      Column(
        children: [
          ConversationTaskCard(
            block: _task(home: true),
            controller: controller,
          ),
          ConversationObjectView(block: profile, controller: controller),
        ],
      ),
    );
    expect(find.text('Before description'), findsOneWidget);
    expect(find.text('After description'), findsOneWidget);
    final confirm = find.widgetWithText(
      FilledButton,
      'Confirm video generation',
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repository.controls, ['confirm-video']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
