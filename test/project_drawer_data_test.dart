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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('暂无项目'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
