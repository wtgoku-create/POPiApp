import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/shared/widgets/popi_drawer_projects.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_dialog.dart';

void main() {
  test(
    'session creation reuses failed request and clears it on success',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [projectRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(projectActionsProvider, (_, __) {});
      addTearDown(subscription.close);
      final actions = container.read(projectActionsProvider.notifier);
      expect(await actions.createSession('p', 'New'), isNull);
      expect(repository.requestIds, isEmpty);
      await container.read(userProvider.notifier).setUser(_user('a'));
      repository.failNext = true;
      await expectLater(
        actions.createSession('p', 'New'),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(projectActionsProvider), isFalse);
      expect((await actions.createSession('p', 'Changed title'))?.title, 'New');
      expect(repository.requestIds[1], repository.requestIds[0]);
      await actions.createSession('p', 'Another');
      expect(repository.requestIds[2], isNot(repository.requestIds[0]));
    },
  );

  test(
    'pending creation rejects duplicates and account change discards result',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [projectRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(projectActionsProvider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(userProvider.notifier).setUser(_user('a'));
      final actions = container.read(projectActionsProvider.notifier);
      final completer = Completer<void>();
      repository.wait = completer.future;
      final pending = actions.createSession('p', 'Old');
      expect(container.read(projectActionsProvider), isTrue);
      expect(await actions.createSession('p', 'Duplicate'), isNull);
      expect(repository.requestIds.length, 1);
      await container.read(userProvider.notifier).setUser(_user('b'));
      expect(repository.lastToken!.isCancelled, isTrue);
      completer.complete();
      expect(await pending, isNull);
      expect(container.read(projectActionsProvider), isFalse);
      repository.wait = null;
      await actions.createSession('p', 'Current');
      expect(repository.requestIds.last, isNot(repository.requestIds.first));
      expect(repository.sessions.last.title, 'Current');
    },
  );

  test(
    'mutation state rejects guests and overlapping commands, then recovers from errors',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [projectRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(projectActionsProvider, (_, __) {});
      addTearDown(subscription.close);
      final actions = container.read(projectActionsProvider.notifier);
      expect(container.read(projectActionsProvider), isFalse);
      expect(await actions.deleteProject('p'), isFalse);
      expect(repository.calls, isEmpty);
      await container.read(userProvider.notifier).setUser(_user('a'));
      final completer = Completer<void>();
      repository.wait = completer.future;
      final first = actions.renameProject('p', 'New');
      expect(container.read(projectActionsProvider), isTrue);
      expect(await actions.deleteProject('p'), isFalse);
      final assertion = expectLater(first, throwsA(isA<ApiException>()));
      completer.completeError(const ApiException());
      await assertion;
      expect(container.read(projectActionsProvider), isFalse);
      expect(repository.projects.first.title, '原项目');
      repository.wait = null;
      expect(await actions.renameProject('p', 'New'), isTrue);
      expect(repository.projects.first.title, 'New');
    },
  );

  Future<ProviderContainer> pumpDrawer(
    WidgetTester tester,
    _Repository repository, {
    Size size = const Size(440, 956),
    bool dark = false,
    String language = 'zh',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [projectRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(userProvider.notifier).setUser(_user('a'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: PopiDrawerProjects(
                onOpenConversation: (selection) {
                  repository.opened++;
                  repository.lastOpened = selection;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> menu(WidgetTester tester, String key) async {
    await tester.longPress(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> dismissToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'project menu creates a session, retries failure and expands the project',
    (tester) async {
      final repository = _Repository();
      await pumpDrawer(tester, repository);
      await tester.tap(find.byKey(const Key('drawer-project-p')));
      await tester.pumpAndSettle();
      final branch = find.byKey(const Key('drawer-project-conversations-p'));
      expect(tester.getSize(branch).height, 0);
      repository.failNext = true;
      await menu(tester, 'drawer-project-p');
      await tester.tap(find.text('新建对话'));
      await tester.pumpAndSettle();
      expect(find.text('服务器拒绝了操作'), findsOneWidget);
      expect(repository.opened, 0);
      await dismissToast(tester);
      await menu(tester, 'drawer-project-p');
      await tester.tap(find.text('新建对话'));
      await tester.pumpAndSettle();
      expect(find.text('新会话'), findsOneWidget);
      expect(tester.getSize(branch).height, greaterThan(0));
      expect(repository.opened, 1);
      expect(repository.lastOpened?.projectId, 'p');
      expect(repository.lastOpened?.session.id, repository.sessions.last.id);
      expect(repository.requestIds[0], repository.requestIds[1]);
      await menu(tester, 'drawer-conversation-p-second');
      expect(find.text('新建对话'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    },
  );

  for (final size in [const Size(440, 956), const Size(320, 568)]) {
    testWidgets('preview preserves text inset while growing at ${size.width}', (
      tester,
    ) async {
      final repository = _Repository();
      await pumpDrawer(tester, repository, size: size);
      for (final (key, title) in [
        ('drawer-project-p', '原项目'),
        ('drawer-conversation-p-second', '第二会话'),
      ]) {
        final source = find.byKey(Key(key));
        final sourceRect = tester.getRect(source);
        final text = find.descendant(of: source, matching: find.text(title));
        final originalInset = tester.getTopLeft(text).dx - sourceRect.left;
        final gesture = await tester.startGesture(tester.getCenter(source));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        final preview = find.byKey(const Key('app-context-menu-preview'));
        final previewRect = tester.getRect(preview);
        final previewText = find.descendant(
          of: preview,
          matching: find.text(title),
        );
        final scale = previewRect.width / sourceRect.width;
        expect(scale, greaterThan(1));
        expect(
          (tester.getTopLeft(previewText).dx - previewRect.left) / scale,
          closeTo(originalInset, .01),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(repository.opened, 0);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'project long press preserves expansion and rename supports retry',
    (tester) async {
      final repository = _Repository();
      await pumpDrawer(tester, repository);
      final branch = find.byKey(const Key('drawer-project-conversations-p'));
      final height = tester.getSize(branch).height;
      await menu(tester, 'drawer-project-p');
      expect(tester.getSize(branch).height, height);
      expect(find.text('置顶会话'), findsNothing);
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('project-rename-input')),
        '   ',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('project-action-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('project-rename-input')),
        '  新项目名  ',
      );
      await tester.pump();
      repository.failNext = true;
      await tester.tap(find.byKey(const Key('project-action-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('服务器拒绝了操作'), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('服务器拒绝了操作'),
        ),
        findsNothing,
      );
      expect(repository.projects.first.title, '原项目');
      await dismissToast(tester);
      await tester.tap(find.byKey(const Key('project-action-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(find.text('新项目名'), findsOneWidget);
      expect(repository.calls, [
        'renameProject:p:新项目名',
        'renameProject:p:新项目名',
      ]);
      await dismissToast(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final project in [true, false]) {
    testWidgets(
      '${project ? 'project' : 'session'} deletion failure uses a toast and can retry',
      (tester) async {
        final repository = _Repository();
        await pumpDrawer(tester, repository);
        await menu(
          tester,
          project ? 'drawer-project-p' : 'drawer-conversation-p-second',
        );
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        repository.failNext = true;
        await tester.tap(find.byKey(const Key('project-action-confirm')));
        await tester.pumpAndSettle();
        expect(find.text('服务器拒绝了操作'), findsOneWidget);
        expect(find.byType(AppDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('服务器拒绝了操作'),
          ),
          findsNothing,
        );
        expect(repository.projects.length, 2);
        expect(repository.sessions.length, 2);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('project-action-confirm')),
              )
              .onPressed,
          isNotNull,
        );
        await dismissToast(tester);
        await tester.tap(find.byKey(const Key('project-action-confirm')));
        await tester.pumpAndSettle();
        expect(find.byType(AppDialog), findsNothing);
        if (project) {
          expect(repository.projects.map((item) => item.id), ['q']);
        } else {
          expect(repository.sessions.map((item) => item.id), ['first']);
        }
        await dismissToast(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'session menu pins, unpins, renames and deletes after confirmation',
    (tester) async {
      final repository = _Repository();
      await pumpDrawer(tester, repository);
      await menu(tester, 'drawer-conversation-p-second');
      expect(repository.opened, 0);
      await tester.tap(find.text('置顶会话'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('第二会话')).dy,
        lessThan(tester.getTopLeft(find.text('第一会话')).dy),
      );
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      await menu(tester, 'drawer-conversation-p-second');
      expect(find.text('取消置顶'), findsOneWidget);
      await tester.tap(find.text('取消置顶'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.push_pin), findsNothing);
      await menu(tester, 'drawer-conversation-p-second');
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('project-rename-input')),
        '新会话名',
      );
      await tester.tap(find.byKey(const Key('project-action-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('新会话名'), findsOneWidget);
      await dismissToast(tester);
      await menu(tester, 'drawer-conversation-p-second');
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除会话「新会话名」？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('新会话名'), findsOneWidget);
      expect(
        repository.calls.where((call) => call.startsWith('delete')),
        isEmpty,
      );
      await menu(tester, 'drawer-conversation-p-second');
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project-action-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('新会话名'), findsNothing);
      expect(find.text('第一会话'), findsOneWidget);
      expect(repository.calls, [
        'pin:second:true',
        'pin:second:false',
        'renameSession:second:新会话名',
        'deleteSession:second',
      ]);
      await dismissToast(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting a project removes its tree and updates count', (
    tester,
  ) async {
    final repository = _Repository();
    await pumpDrawer(tester, repository);
    await menu(tester, 'drawer-project-p');
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除「原项目」及其全部会话？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-action-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-project-p')), findsNothing);
    expect(find.text('第一会话'), findsNothing);
    expect(find.text('项目(1)'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('其他项目')).style?.color,
      AppTheme.light.colorScheme.primary,
    );
    expect(repository.calls, ['deleteProject:p']);
    await dismissToast(tester);
  });

  testWidgets(
    'pending submit is locked and account switch cancels the command',
    (tester) async {
      final repository = _Repository();
      final container = await pumpDrawer(tester, repository);
      await menu(tester, 'drawer-project-p');
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('project-rename-input')),
        '变更',
      );
      final completer = Completer<void>();
      repository.wait = completer.future;
      await tester.tap(find.byKey(const Key('project-action-confirm')));
      await tester.pump();
      expect(container.read(projectActionsProvider), isTrue);
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '取消'),
      );
      expect(cancel.onPressed, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('project-action-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AppDialog), findsOneWidget);
      await container.read(userProvider.notifier).setUser(_user('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(repository.lastToken!.isCancelled, isTrue);
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.text('重命名成功'), findsNothing);
      expect(repository.calls.length, 1);
      expect(container.read(projectActionsProvider), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['zh', 'en']) {
    testWidgets('compact dark $language action dialogs fit', (tester) async {
      final repository = _Repository();
      await pumpDrawer(
        tester,
        repository,
        size: const Size(320, 568),
        dark: true,
        language: language,
      );
      await menu(tester, 'drawer-project-p');
      await tester.tap(find.text(language == 'zh' ? '重命名' : 'Rename'));
      await tester.pumpAndSettle();
      final button = tester.getRect(
        find.byKey(const Key('project-action-confirm')),
      );
      expect(button.right, lessThanOrEqualTo(320));
      expect(button.bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
    });
  }
}

User _user(String id) => User(id: id, name: id, email: '');

class _Repository extends ProjectRepository {
  _Repository() : super(NetworkApi(Dio()));

  final projects = <Project>[
    const Project(id: 'p', title: '原项目'),
    const Project(id: 'q', title: '其他项目'),
  ];
  final sessions = <ProjectSession>[
    const ProjectSession(id: 'first', title: '第一会话'),
    const ProjectSession(id: 'second', title: '第二会话'),
  ];
  final calls = <String>[];
  final requestIds = <String>[];
  bool failNext = false;
  int opened = 0;
  Future<void>? wait;
  CancelToken? lastToken;
  ProjectSessionSelection? lastOpened;

  @override
  Future<ProjectSession> createSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    requestIds.add(clientRequestId);
    await _before('createSession:$projectId:$title', cancelToken);
    final session = ProjectSession(
      id: 'created-${requestIds.length}',
      title: title,
    );
    sessions.add(session);
    return session;
  }

  Future<void> _before(String call, CancelToken? token) async {
    calls.add(call);
    lastToken = token;
    if (failNext) {
      failNext = false;
      throw const ApiException(message: '服务器拒绝了操作');
    }
    await wait;
    if (token?.isCancelled == true) throw token!.cancelError!;
  }

  @override
  Future<List<Project>> listProjects({CancelToken? cancelToken}) async =>
      List.of(projects);
  @override
  Future<List<ProjectSession>> listSessions(
    String projectId, {
    CancelToken? cancelToken,
  }) async => projectId == 'p' ? List.of(sessions) : [];
  @override
  Future<void> renameProject(
    String id,
    String title, {
    CancelToken? cancelToken,
  }) async {
    await _before('renameProject:$id:$title', cancelToken);
    final index = projects.indexWhere((item) => item.id == id);
    projects[index] = Project(id: id, title: title);
  }

  @override
  Future<void> deleteProject(String id, {CancelToken? cancelToken}) async {
    await _before('deleteProject:$id', cancelToken);
    projects.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> renameSession(
    String id,
    String title, {
    CancelToken? cancelToken,
  }) async {
    await _before('renameSession:$id:$title', cancelToken);
    final index = sessions.indexWhere((item) => item.id == id);
    sessions[index] = ProjectSession(
      id: id,
      title: title,
      pinnedAt: sessions[index].pinnedAt,
    );
  }

  @override
  Future<void> deleteSession(String id, {CancelToken? cancelToken}) async {
    await _before('deleteSession:$id', cancelToken);
    sessions.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> setSessionPinned(
    String id,
    bool pinned, {
    CancelToken? cancelToken,
  }) async {
    await _before('pin:$id:$pinned', cancelToken);
    final session = sessions.firstWhere((item) => item.id == id);
    sessions.remove(session);
    sessions.insert(
      pinned ? 0 : sessions.length,
      ProjectSession(
        id: id,
        title: session.title,
        pinnedAt: pinned ? DateTime.utc(2026, 10, 7) : null,
      ),
    );
  }
}
