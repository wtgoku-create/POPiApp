import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/home/presentation/widgets/popi_drawer_projects.dart';
import 'package:popi_ai_app/features/projects/data/project_api.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  Future<ProviderContainer> pumpProjects(
    WidgetTester tester,
    _Repository repository, {
    bool loggedIn = true,
    bool reduceMotion = false,
    ValueChanged<ProjectSessionSelection>? onOpen,
  }) async {
    final container = ProviderContainer(
      overrides: [projectRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    if (loggedIn) {
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: 'User', email: ''));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: PopiDrawerProjects(onOpenConversation: onOpen ?? (_) {}),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('guest prompts login without fetching projects', (tester) async {
    final repository = _Repository();
    await pumpProjects(tester, repository, loggedIn: false);
    await tester.pumpAndSettle();
    expect(find.text('登录后查看项目'), findsOneWidget);
    expect(find.text('项目(0)'), findsOneWidget);
    expect(repository.projectCalls, 0);
    expect(repository.sessionCalls, isEmpty);
  });

  testWidgets('shows loading then the empty project state', (tester) async {
    final completer = Completer<List<Project>>();
    final repository = _Repository()..loadProjects = () => completer.future;
    await pumpProjects(tester, repository);
    await tester.pump();
    final skeleton = find.byKey(const Key('drawer-projects-skeleton'));
    expect(skeleton, findsOneWidget);
    expect(find.text('项目(0)'), findsNothing);
    expect(find.byKey(const Key('drawer-projects-empty')), findsNothing);
    final bounds = tester.getRect(skeleton);
    final fade = find.descendant(
      of: skeleton,
      matching: find.byType(FadeTransition),
    );
    final before = tester.widget<FadeTransition>(fade).opacity.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<FadeTransition>(fade).opacity.value, isNot(before));
    expect(tester.getRect(skeleton), bounds);
    completer.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('暂无项目'), findsOneWidget);
    expect(find.byKey(const Key('drawer-projects-empty')), findsOneWidget);
    expect(skeleton, findsNothing);
    await tester.drag(
      find.byKey(const Key('drawer-project-list')),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    expect(repository.projectCalls, 2);
    expect(find.byKey(const Key('drawer-projects-empty')), findsOneWidget);
  });

  testWidgets('reduced motion keeps the skeleton static until data arrives', (
    tester,
  ) async {
    final completer = Completer<List<Project>>();
    final repository = _Repository()..loadProjects = () => completer.future;
    await pumpProjects(tester, repository, reduceMotion: true);
    await tester.pumpAndSettle();
    final skeleton = find.byKey(const Key('drawer-projects-skeleton'));
    final fade = find.descendant(
      of: skeleton,
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    completer.complete([const Project(id: 'p', title: '真实项目')]);
    await tester.pumpAndSettle();
    expect(skeleton, findsNothing);
    expect(find.text('真实项目'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conversation skeleton gives way to the loaded conversation', (
    tester,
  ) async {
    final completer = Completer<List<ProjectSession>>();
    final repository = _Repository();
    repository.loadProjects = () async => [
      const Project(id: 'p', title: '真实项目'),
    ];
    repository.loadSessions = (_) => completer.future;
    await pumpProjects(tester, repository);
    await tester.pump();
    await tester.pump();
    final skeleton = find.byKey(const Key('drawer-sessions-skeleton-p'));
    expect(skeleton, findsOneWidget);
    expect(find.text('暂无历史'), findsNothing);
    completer.complete([const ProjectSession(id: 's', title: '真实会话')]);
    await tester.pumpAndSettle();
    expect(skeleton, findsNothing);
    expect(find.text('真实会话'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project failure retries and shows real backend titles', (
    tester,
  ) async {
    final repository = _Repository()
      ..loadProjects = () => Future.error(const ApiException());
    await pumpProjects(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('项目加载失败'), findsOneWidget);
    repository.loadProjects = () async => [
      const Project(id: 'account-id', title: '真实项目'),
    ];
    await tester.tap(find.byTooltip('重试'));
    await tester.pumpAndSettle();
    expect(find.text('项目加载失败'), findsNothing);
    expect(find.text('真实项目'), findsOneWidget);
    expect(find.text('暂无历史'), findsOneWidget);
    expect(repository.projectCalls, 2);
  });

  testWidgets(
    'refresh keeps populated projects and sessions without skeletons',
    (tester) async {
      final repository = _Repository();
      repository.loadProjects = () async => [
        const Project(id: 'p', title: '真实项目'),
      ];
      repository.loadSessions = (_) async => [
        const ProjectSession(id: 's', title: '真实会话'),
      ];
      final container = await pumpProjects(tester, repository);
      await tester.pumpAndSettle();
      final projects = Completer<List<Project>>();
      final sessions = Completer<List<ProjectSession>>();
      repository.loadProjects = () => projects.future;
      repository.loadSessions = (_) => sessions.future;
      container.invalidate(projectsProvider);
      container.invalidate(projectSessionsProvider('p'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('真实项目'), findsOneWidget);
      expect(find.text('真实会话'), findsOneWidget);
      expect(find.text('项目(1)'), findsOneWidget);
      expect(find.byKey(const Key('drawer-projects-skeleton')), findsNothing);
      expect(find.byKey(const Key('drawer-sessions-skeleton-p')), findsNothing);
      projects.complete([const Project(id: 'p', title: '更新项目')]);
      sessions.complete([const ProjectSession(id: 's', title: '更新会话')]);
      await tester.pumpAndSettle();
      expect(find.text('更新项目'), findsOneWidget);
      expect(find.text('更新会话'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh of an empty list displays skeletons again', (
    tester,
  ) async {
    final repository = _Repository();
    final container = await pumpProjects(tester, repository);
    await tester.pumpAndSettle();
    final pending = Completer<List<Project>>();
    repository.loadProjects = () => pending.future;
    container.invalidate(projectsProvider);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('drawer-projects-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('drawer-projects-empty')), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-projects-skeleton')), findsNothing);
    expect(find.byKey(const Key('drawer-projects-empty')), findsOneWidget);
  });

  testWidgets('sessions load lazily, retry and pass backend IDs on selection', (
    tester,
  ) async {
    ProjectSessionSelection? selected;
    final repository = _Repository();
    repository.loadProjects = () async => [
      for (final id in ['first', 'second', 'third']) Project(id: id, title: id),
    ];
    repository.loadSessions = (id) =>
        id == 'third' ? Future.error(const ApiException()) : Future.value([]);
    await pumpProjects(tester, repository, onOpen: (value) => selected = value);
    await tester.pumpAndSettle();
    expect(repository.sessionCalls, ['first', 'second']);
    await tester.tap(find.byKey(const Key('drawer-project-third')));
    await tester.pumpAndSettle();
    expect(find.text('会话加载失败'), findsOneWidget);
    repository.loadSessions = (_) async => [
      const ProjectSession(id: 'session-id', title: '真实会话'),
    ];
    await tester.tap(find.byTooltip('重试'));
    await tester.pumpAndSettle();
    expect(find.text('真实会话'), findsOneWidget);
    await tester.tap(find.text('真实会话'));
    expect(selected?.projectId, 'third');
    expect(selected?.session.id, 'session-id');
    final calls = repository.sessionCalls.length;
    await tester.tap(find.byKey(const Key('drawer-project-third')));
    await tester.pumpAndSettle();
    expect(find.text('真实会话'), findsNothing);
    await tester.tap(find.byKey(const Key('drawer-project-third')));
    await tester.pumpAndSettle();
    expect(find.text('真实会话'), findsOneWidget);
    expect(repository.sessionCalls.length, calls);
  });
}

class _Repository extends ProjectRepository {
  _Repository() : super(ProjectApi(Dio()));

  Future<List<Project>> Function() loadProjects = () async => [];
  Future<List<ProjectSession>> Function(String) loadSessions = (_) async => [];
  int projectCalls = 0;
  final sessionCalls = <String>[];

  @override
  Future<List<Project>> listProjects({CancelToken? cancelToken}) {
    projectCalls++;
    return loadProjects();
  }

  @override
  Future<List<ProjectSession>> listSessions(
    String projectId, {
    CancelToken? cancelToken,
  }) {
    sessionCalls.add(projectId);
    return loadSessions(projectId);
  }
}
