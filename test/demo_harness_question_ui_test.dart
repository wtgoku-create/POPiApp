import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_question_card.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

final _captureKey = GlobalKey();
final _captureDirectory = Platform.environment['CHAT_UX_SCREENSHOTS'];

const _field = ConversationQuestionField(
  id: 'next_step',
  label: '《留个位置》可以进入声音和成片制作了吗？',
  required: true,
  options: ['可以，进入声音和成片', '先再打磨一轮分镜和画面', '之后全程不用停下来问我'],
);

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDirectory == null) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_captureDirectory!).create(recursive: true);
    await File(
      '$_captureDirectory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _pumpCapture(
  WidgetTester tester, {
  required double cardWidth,
  required Size viewport,
  bool dark = false,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _captureDirectory == null
          ? theme
          : theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'ChatCapture'),
            ),
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: _captureKey,
            child: SizedBox(
              width: cardWidth,
              child: IntrinsicHeight(
                child: ConversationQuestionCard(
                  title: _field.label,
                  fields: const [_field],
                  instantSingleChoice: true,
                  onRespond: (_, _) async => false,
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
  setUpAll(() async {
    if (_captureDirectory != null) {
      final font = FontLoader('ChatCapture');
      font.addFont(
        File(
          '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final variant in [
    (
      name: 'question-desktop',
      width: 760.0,
      viewport: const Size(900, 600),
      dark: false,
    ),
    (
      name: 'question-mobile',
      width: 342.0,
      viewport: const Size(390, 720),
      dark: false,
    ),
    (
      name: 'question-dark',
      width: 760.0,
      viewport: const Size(900, 600),
      dark: true,
    ),
  ]) {
    testWidgets('${variant.name} question card reference', (tester) async {
      await _pumpCapture(
        tester,
        cardWidth: variant.width,
        viewport: variant.viewport,
        dark: variant.dark,
      );
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('可以，进入声音和成片')));
      await tester.pumpAndSettle();

      expect(find.text(_field.label), findsOneWidget);
      expect(find.text('可以，进入声音和成片'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, variant.name);
    });
  }

  testWidgets('Harness question selection reaches transport and settles card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final api = _QuestionApi(dio);
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();

    await tester.pumpWidget(
      ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: DemoChatPage(repository: repository, sessionId: 's1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('demo-question-question-1')),
      findsOneWidget,
    );
    await tester.tap(find.text('可以，进入声音和成片'));
    await tester.pumpAndSettle();

    expect(api.actions, ['submit']);
    expect(api.answers.single, {'next_step': '可以，进入声音和成片'});
    expect(find.byType(TextFormField), findsNothing);
    expect(find.widgetWithText(FilledButton, '确认'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _QuestionApi extends NetworkAgentApi {
  _QuestionApi(super.dio);

  final actions = <String>[];
  final answers = <Map<String, Object?>>[];
  var _answered = false;

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [_record],
    'pageInfo': {'page': 1, 'pageSize': 20, 'pageCount': 1, 'total': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => {
    'session': _record,
    'lastSeq': 1,
    'messages': [_questionMessage(answered: _answered)],
    'runs': <Object?>[],
  };

  @override
  Future<Map<String, dynamic>> respondQuestion(
    String sessionId,
    String questionId, {
    String? clientRequestId,
    required int revision,
    required String action,
    Map<String, Object?>? answer,
    CancelToken? cancelToken,
  }) async {
    actions.add(action);
    answers.add(Map<String, Object?>.from(answer ?? const {}));
    _answered = true;
    return {'id': questionId, 'revision': revision, 'status': 'answered'};
  }
}

final _record = <String, Object?>{
  'id': 's1',
  'title': '留个位置',
  'kind': 'conversation',
  'revision': 1,
  'createdAt': '2026-10-24T00:00:00.000Z',
  'updatedAt': '2026-10-24T00:00:00.000Z',
  'archived': false,
  'bindingStatus': 'ready',
  'configurationStatus': 'configured',
  'configRevision': 1,
  'configuration': {
    'members': ['popi'],
    'roles': <String>[],
    'capabilities': <String>[],
    'memberCapabilities': <String, Object?>{},
    'memberNames': <String, String>{},
    'memberInstructions': <String, String>{},
    'memberAvatars': <String, String>{},
    'memberColors': <String, int>{},
    'workMode': 'onDemand',
    'activeMemberId': 'popi',
    'direction': '',
    'positioning': '',
    'roleProfiles': <String, Object?>{},
  },
};

Map<String, Object?> _questionMessage({required bool answered}) => {
  'id': 'assistant-question',
  'role': 'assistant',
  'text': '第四位评审的结论是可以进入下一步。',
  'status': 'completed',
  'createdAt': '2026-10-24T00:00:00.000Z',
  'question': {
    'id': 'question-1',
    'revision': 3,
    'status': answered ? 'answered' : 'pending',
    'title': _field.label,
    'questions': [
      {
        'id': 'next_step',
        'question': _field.label,
        'header': '下一步',
        'options': [
          for (final option in _field.options) {'label': option},
        ],
      },
    ],
    if (answered)
      'answers': [
        {
          'id': 'next_step',
          'selected': ['可以，进入声音和成片'],
        },
      ],
  },
};
