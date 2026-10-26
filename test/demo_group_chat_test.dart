import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_controller.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

DemoSession _groupSession({Map<String, String> memberNames = const {}}) =>
    DemoSession(
      id: 'group',
      title: '创作群',
      kind: DemoSessionKind.project,
      members: const ['writer', 'designer'],
      roles: const [],
      memberNames: memberNames,
      messages: const [
        DemoMessage(id: 'legacy', text: '旧消息没有成员身份。'),
        DemoMessage(
          id: 'writer',
          text: '我先整理故事结构。',
          memberId: 'writer',
          memberName: '旧编剧名称',
          runId: 'run-1',
          configRevision: 4,
        ),
        DemoMessage(
          id: 'designer',
          text: '我补充画面风格。',
          memberId: 'designer',
          memberName: 'designer',
          runId: 'run-1',
          configRevision: 4,
        ),
        DemoMessage(
          id: 'departed',
          text: '声音方案也准备好了。',
          memberId: 'sound',
          memberName: '声音导演',
          runId: 'run-1',
          configRevision: 3,
        ),
        DemoMessage(
          id: 'media',
          text: '',
          memberId: 'writer',
          memberName: '旧编剧名称',
          runId: 'run-2',
          configRevision: 4,
          assetIds: ['result-image'],
        ),
        DemoMessage(
          id: 'skipped',
          text: '',
          memberId: 'designer',
          status: 'skipped',
        ),
        DemoMessage(
          id: 'streaming-empty',
          text: '',
          memberId: 'writer',
          status: 'pending',
        ),
      ],
      configRevision: 4,
      configurationStatus: 'configured',
    );

const _resultAsset = DemoAsset(
  id: 'result-image',
  title: '角色图',
  kind: DemoAssetKind.image,
  cover: 'assets/images/demo_milk_tea.png',
  sessionId: 'group',
  memberId: 'writer',
  runId: 'run-2',
  configRevision: 4,
);

Future<DemoRepository> _repository(
  DemoSession session, {
  List<DemoAsset> assets = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': [session.toJson()],
      'assets': assets.map((asset) => asset.toJson()).toList(),
    }),
  });
  return DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
}

Future<void> _settleController() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'message identity survives local persistence and legacy messages load',
    () async {
      final repository = await _repository(_groupSession());
      addTearDown(repository.dispose);

      final identified = repository.session('group').messages[1];
      expect(identified.memberId, 'writer');
      expect(identified.memberName, '旧编剧名称');
      expect(identified.runId, 'run-1');
      expect(identified.configRevision, 4);

      final legacy = repository.session('group').messages.first;
      expect(legacy.memberId, isEmpty);
      expect(legacy.memberName, isEmpty);
      expect(legacy.runId, isEmpty);
      expect(legacy.configRevision, 0);
    },
  );

  test(
    'controller maps members, updates authors, and hides skipped turns',
    () async {
      final repository = await _repository(
        _groupSession(memberNames: const {'writer': '首席编剧'}),
      );
      addTearDown(repository.dispose);
      final controller = DemoChatController(repository, 'group');
      addTearDown(controller.dispose);
      await _settleController();

      expect(controller.chatController.messages.map((message) => message.id), [
        'legacy',
        'writer',
        'designer',
        'departed',
        'media',
      ]);
      expect(
        controller.chatController.messages
            .firstWhere((message) => message.id == 'legacy')
            .authorId,
        'popi',
      );
      expect(
        controller.chatController.messages
            .firstWhere((message) => message.id == 'media')
            .authorId,
        'writer',
      );

      final l = lookupAppLocalizations(const Locale('zh'));
      expect(controller.resolveUser('writer', l).name, '首席编剧');
      expect(controller.resolveUser('designer', l).name, '角色设计师');
      expect(controller.resolveUser('sound', l).name, '声音导演');

      await repository.updateSession(
        'group',
        (session) => session.copyWith(
          messages: [
            for (final message in session.messages)
              if (message.id == 'writer')
                const DemoMessage(
                  id: 'writer',
                  text: '改由设计师补充。',
                  memberId: 'designer',
                  memberName: '视觉设计',
                  runId: 'run-1',
                  configRevision: 4,
                )
              else
                message,
          ],
        ),
      );
      await _settleController();

      expect(
        controller.chatController.messages
            .firstWhere((message) => message.id == 'writer')
            .authorId,
        'designer',
      );
      expect(controller.chatController.messages, hasLength(5));
      expect(
        controller.chatController.messages.map((message) => message.id).toSet(),
        hasLength(5),
      );
    },
  );

  testWidgets('group messages show each Bot identity without narrow overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repository(
      _groupSession(memberNames: const {'writer': '首席编剧'}),
      assets: const [_resultAsset],
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: DemoChatPage(repository: repository, sessionId: 'group'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('POPi'), findsOneWidget);
    expect(find.text('首席编剧'), findsNWidgets(2));
    expect(find.text('角色设计师'), findsOneWidget);
    expect(find.text('声音导演'), findsOneWidget);
    expect(find.text('角色图'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('demo-message-avatar-media-writer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('demo-message-name-skipped')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('demo-message-name-streaming-empty')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await repository.updateSession(
      'group',
      (session) => session.copyWith(
        memberNames: {...session.memberNames, 'writer': '剧本统筹'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('剧本统筹'), findsNWidgets(2));
    expect(find.text('首席编剧'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
