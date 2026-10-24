import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_task_brief_sheet.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _request = '请生成一张南极猫的真实宠物摄影，暖米色背景。';
const _otherRequest = '另一条任务的需求，不属于这张图片。';

DemoMediaJob _job({
  String state = 'pending',
  String runId = 'run-target',
  String operation = 'image',
}) => DemoMediaJob(
  jobId: 'task-1',
  state: state,
  operation: operation,
  model: 'image-2.5-official',
  runId: runId,
  memberId: 'popi',
  configRevision: 4,
  assetIds: state == 'completed' ? const ['asset-1'] : const [],
  ingestionState: state == 'completed' ? 'completed' : '',
);

Future<DemoRepository> _repository({
  DemoMediaJob? job,
  bool includeRequest = true,
}) async {
  final session = DemoSession(
    id: 's1',
    title: '南极创作',
    kind: DemoSessionKind.conversation,
    members: const ['popi'],
    roles: const [],
    configRevision: 9,
    memberNames: const {'popi': '创意搭档'},
    messages: [
      if (includeRequest)
        const DemoMessage(
          id: 'user-1',
          user: true,
          text: _request,
          runId: 'run-target',
        ),
      const DemoMessage(
        id: 'user-2',
        user: true,
        text: _otherRequest,
        runId: 'run-other',
      ),
    ],
    mediaJobs: [job ?? _job()],
  );
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': [session.toJson()],
      'assets': <Object?>[],
    }),
  });
  return DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
}

Future<void> _pump(
  WidgetTester tester,
  DemoRepository repository, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: DemoChatPage(repository: repository, sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _card => find.byKey(const ValueKey('demo-media-job-open-task-1'));
Finder get _sheet => find.byType(DemoTaskBriefSheet);
Finder _within(Finder finder) => find.descendant(of: _sheet, matching: finder);

void main() {
  testWidgets('queued card opens a read-only brief for the correct request', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    await _pump(tester, repository);
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    await composer.controller.setText('保留未发送的草稿');
    await tester.pumpAndSettle();
    final messages = repository.session('s1').messages;
    final jobs = repository.session('s1').mediaJobs;
    await tester.tap(_card);
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(_within(find.text('任务简介')), findsOneWidget);
    expect(_within(find.text(_request)), findsOneWidget);
    expect(_within(find.text(_otherRequest)), findsNothing);
    expect(_within(find.text('图片生成')), findsOneWidget);
    expect(_within(find.text('任务已排队')), findsOneWidget);
    expect(_within(find.text('创意搭档')), findsOneWidget);
    expect(_within(find.text('image-2.5-official')), findsOneWidget);
    expect(_within(find.text('受理配置 v4')), findsOneWidget);
    expect(_within(find.text('受理配置 v9')), findsNothing);
    expect(find.byKey(const Key('demo-task-brief-view-outputs')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(composer.controller.markdown, '保留未发送的草稿');
    expect(repository.session('s1').messages, same(messages));
    expect(repository.session('s1').mediaJobs, same(jobs));
    expect(repository.assets, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final runId in ['missing-run', '']) {
    testWidgets(
      'missing request for run "$runId" never borrows a different task description',
      (tester) async {
        final repository = await _repository(job: _job(runId: runId));
        addTearDown(repository.dispose);
        await _pump(tester, repository);
        await tester.tap(_card);
        await tester.pumpAndSettle();
        expect(_within(find.text('该任务未保存文字简介')), findsOneWidget);
        expect(_within(find.text(_request)), findsNothing);
        expect(_within(find.text(_otherRequest)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'open brief updates with the task and opens Outputs after completion',
    (tester) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      await _pump(tester, repository);
      await tester.tap(_card);
      await tester.pumpAndSettle();
      await repository.updateSession(
        's1',
        (session) => session.copyWith(mediaJobs: [_job(state: 'running')]),
      );
      await tester.pumpAndSettle();
      expect(_within(find.text('正在制作')), findsOneWidget);
      expect(_within(find.text('任务已排队')), findsNothing);
      await repository.updateSession(
        's1',
        (session) => session.copyWith(mediaJobs: [_job(state: 'completed')]),
      );
      await tester.pumpAndSettle();
      expect(_within(find.text('已保存到资产库')), findsOneWidget);
      await tester.tap(find.byKey(const Key('demo-task-brief-view-outputs')));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(find.byType(DemoSettingsPage), findsOneWidget);
      expect(
        tester.widget<DemoSegments>(find.byType(DemoSegments).first).selected,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid taps open only one brief and allow reopening after dismissal',
    (tester) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      await _pump(tester, repository);
      final onTap = tester.widget<InkWell>(_card).onTap!;
      onTap();
      onTap();
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(_card);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed task brief remains readable with narrow large text', (
    tester,
  ) async {
    final repository = await _repository(
      job: _job(state: 'failed', operation: 'tts'),
    );
    addTearDown(repository.dispose);
    await _pump(tester, repository, textScale: 1.5);
    await tester.tap(_card);
    await tester.pumpAndSettle();
    expect(_within(find.text('任务失败')), findsOneWidget);
    expect(_within(find.text('语音合成')), findsOneWidget);
    expect(_within(find.text(_request)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(_within(find.byType(ListView)), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(_within(find.text('task-1')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
