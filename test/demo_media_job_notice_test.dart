import 'dart:async';
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
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

DemoMediaJob _job(String id, {String state = 'completed'}) => DemoMediaJob(
  jobId: id,
  state: state,
  operation: 'image',
  model: 'image-2.5-official',
  runId: 'run-$id',
  memberId: 'popi',
  configRevision: id == 'job-2' ? 2 : 1,
  assetIds: state == 'completed' ? const ['output-1'] : const [],
  ingestionState: state == 'completed' ? 'completed' : '',
);

class _FailingDismissalStorage extends PreferencesStorage {
  _FailingDismissalStorage(super.preferences);

  @override
  Future<void> setString(String key, String value) {
    if (key.endsWith('_dismissed_media_jobs_v1')) {
      throw StateError('Disk unavailable');
    }
    return super.setString(key, value);
  }
}

class _ControlledDismissalStorage extends PreferencesStorage {
  _ControlledDismissalStorage(super.preferences);
  final gate = Completer<void>();
  int attempts = 0;

  @override
  Future<void> setString(String key, String value) async {
    if (key.endsWith('_dismissed_media_jobs_v1')) {
      attempts++;
      await gate.future;
    }
    await super.setString(key, value);
  }
}

Future<DemoRepository> _repository({
  List<DemoMediaJob>? jobs,
  bool failDismissal = false,
}) async {
  final session = DemoSession(
    id: 'task-session',
    title: '当前会话',
    kind: DemoSessionKind.conversation,
    members: const ['popi'],
    roles: const [],
    messages: const [DemoMessage(id: 'request', text: '生成一张图片', user: true)],
    mediaJobs: jobs ?? [_job('job-1'), _job('job-2')],
  );
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': [session.toJson()],
      'assets': [
        const DemoAsset(
          id: 'output-1',
          title: '本会话产物',
          kind: DemoAssetKind.script,
          cover: '',
          body: '已生成的内容',
          sessionId: 'task-session',
          jobId: 'job-2',
        ).toJson(),
        const DemoAsset(
          id: 'output-other',
          title: '别的会话产物',
          kind: DemoAssetKind.script,
          cover: '',
          body: '其他内容',
          sessionId: 'other-session',
        ).toJson(),
      ],
    }),
  });
  final preferences = await SharedPreferences.getInstance();
  return DemoRepository(
    failDismissal
        ? _FailingDismissalStorage(preferences)
        : PreferencesStorage(preferences),
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
      child: ToastificationWrapper(
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
          home: DemoChatPage(repository: repository, sessionId: 'task-session'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  testWidgets(
    'completed notice opens the current session Outputs tab and preserves draft',
    (tester) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      await _pump(tester, repository);
      final composer = tester.widget<PopiMessageComposer>(
        find.byType(PopiMessageComposer),
      );
      await composer.controller.setText('保留这份草稿');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('demo-media-job-open-job-2')));
      await tester.pumpAndSettle();
      expect(find.byType(DemoSettingsPage), findsOneWidget);
      expect(
        tester.widget<DemoSegments>(find.byType(DemoSegments).first).selected,
        2,
      );
      expect(find.text('本会话产物').hitTestable(), findsOneWidget);
      expect(find.text('别的会话产物'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(composer.controller.markdown, '保留这份草稿');
      expect(repository.assets, hasLength(2));
      expect(repository.session('task-session').mediaJobs, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'close hides only that notice and survives rebuilding the repository',
    (tester) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      await _pump(tester, repository);
      await tester.tap(
        find.byKey(const ValueKey('demo-media-job-dismiss-job-2')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DemoSettingsPage), findsNothing);
      expect(find.byKey(const ValueKey('demo-media-job-job-2')), findsNothing);
      expect(
        find.byKey(const ValueKey('demo-media-job-job-1')),
        findsOneWidget,
      );
      expect(repository.assets, hasLength(2));
      expect(repository.session('task-session').mediaJobs, hasLength(2));

      await tester.pumpWidget(const SizedBox.shrink());
      final restored = DemoRepository(
        PreferencesStorage(await SharedPreferences.getInstance()),
      )..restore();
      addTearDown(restored.dispose);
      await _pump(tester, restored);
      expect(find.byKey(const ValueKey('demo-media-job-job-2')), findsNothing);
      expect(
        find.byKey(const ValueKey('demo-media-job-job-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending notices remain visible and open a brief without offering dismissal',
    (tester) async {
      final repository = await _repository(
        jobs: [
          _job('job-1'),
          _job('pending', state: 'running'),
        ],
      );
      addTearDown(repository.dispose);
      await _pump(tester, repository, textScale: 1.5);
      final label = AppLocalizations.of(
        tester.element(find.byType(DemoChatPage)),
      )!.demoTaskCreating;
      expect(find.text(label), findsOneWidget);
      expect(
        find.byKey(const ValueKey('demo-media-job-dismiss-pending')),
        findsNothing,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey('demo-media-job-open-pending')),
            )
            .onTap,
        isNotNull,
      );
      expect(
        find.byKey(const ValueKey('demo-media-job-dismiss-job-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissing all terminal notices leaves the composer available', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    await _pump(tester, repository);
    await tester.tap(
      find.byKey(const ValueKey('demo-media-job-dismiss-job-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('demo-media-job-dismiss-job-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('已保存到资产库'), findsNothing);
    expect(
      find.byKey(const Key('popi-message-input')).hitTestable(),
      findsOneWidget,
    );
    expect(repository.session('task-session').mediaJobs, hasLength(2));
    expect(repository.assets, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an older running task stays visible ahead of completed notices',
    (tester) async {
      final repository = await _repository(
        jobs: [
          _job('pending', state: 'running'),
          _job('job-1'),
          _job('job-2'),
        ],
      );
      addTearDown(repository.dispose);
      await _pump(tester, repository);
      expect(
        find.byKey(const ValueKey('demo-media-job-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('demo-media-job-job-2')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('demo-media-job-job-1')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid close taps share one write and never open Outputs', (
    tester,
  ) async {
    (await _repository()).dispose();
    final storage = _ControlledDismissalStorage(
      await SharedPreferences.getInstance(),
    );
    final repository = DemoRepository(storage)..restore();
    addTearDown(repository.dispose);
    await _pump(tester, repository);
    final close = find.byKey(const ValueKey('demo-media-job-dismiss-job-2'));
    final button = tester.widget<IconButton>(close);
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(storage.attempts, 1);
    expect(tester.widget<IconButton>(close).onPressed, isNull);
    await tester.tap(close);
    await tester.pump();
    expect(find.byType(DemoSettingsPage), findsNothing);
    expect(storage.attempts, 1);
    storage.gate.completeError(StateError('Disk unavailable'));
    await tester.pumpAndSettle();
    final errorMessage = AppLocalizations.of(
      tester.element(find.byType(DemoChatPage)),
    )!.demoStorageError;
    expect(find.text(errorMessage), findsOneWidget);
    expect(tester.widget<IconButton>(close).onPressed, isNotNull);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed dismissal keeps notice and draft with a single toast', (
    tester,
  ) async {
    final repository = await _repository(failDismissal: true);
    addTearDown(repository.dispose);
    await _pump(tester, repository);
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    await composer.controller.setText('不要丢失草稿');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('demo-media-job-dismiss-job-2')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('demo-media-job-job-2')), findsOneWidget);
    expect(composer.controller.markdown, '不要丢失草稿');
    final errorMessage = AppLocalizations.of(
      tester.element(find.byType(DemoChatPage)),
    )!.demoStorageError;
    expect(find.text(errorMessage), findsOneWidget);
    expect(find.byType(DemoSettingsPage), findsNothing);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
