import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_project_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';
import 'package:popi_ai_app/shared/widgets/app_skeleton.dart';
import 'package:toastification/toastification.dart';

import 'support/project_fixtures.dart';

class _ProjectUserController extends UserController {
  @override
  User? build() => const User(id: 'user', name: 'User', email: '');
}

class _ProjectRepository extends FixtureProjectRepository {
  int projectRequests = 0;
  final pages = <(int, int)>[];
  bool failProjects = false;
  bool failSessions = false;
  Completer<List<Project>>? pendingProjects;
  final sessionRequests = <String>[];
  final createdSessions = <({String projectId, String title})>[];
  List<ProjectSession> sessions = [
    ProjectSession(id: 'older', title: 'Older', updatedAt: DateTime(2025)),
    ProjectSession(id: 'latest', title: 'Latest', updatedAt: DateTime(2026)),
    const ProjectSession(id: 'undated', title: 'Undated'),
  ];

  @override
  Future<ListPage<Project>> listProjects({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    projectRequests++;
    pages.add((page, pageSize));
    if (failProjects) throw StateError('Project loading failed');
    if (pendingProjects != null) {
      return fixturePage(
        await pendingProjects!.future,
        page: page,
        pageSize: pageSize,
      );
    }
    return fixturePage(
      [
        for (var index = 0; index < 180; index++)
          Project(
            id: '$index',
            title: index.isEven
                ? 'Project $index with a longer title that wraps on narrow screens'
                : 'Project $index',
          ),
      ],
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<ProjectSession?> boundSession(
    String projectId, {
    CancelToken? cancelToken,
  }) async {
    sessionRequests.add(projectId);
    if (failSessions) throw StateError('Session loading failed');
    final sorted = [...sessions]
      ..sort(
        (a, b) => (b.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
          a.updatedAt?.millisecondsSinceEpoch ?? 0,
        ),
      );
    return sorted.firstOrNull;
  }

  @override
  Future<ProjectSession> createSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    createdSessions.add((projectId: projectId, title: title));
    return ProjectSession(id: 'created', title: title);
  }
}

void main() {
  late _ProjectRepository repository;
  Object? selection;

  setUp(() {
    repository = _ProjectRepository();
    selection = null;
  });
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  Future<void> pumpSheet(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool forHomeCreation = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(_ProjectUserController.new),
        projectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => IconButton(
                key: const Key('open-project-sheet'),
                icon: const Icon(Icons.folder),
                onPressed: () async {
                  selection = await AppSheet.show<Object>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        RoleProjectSheet(forHomeCreation: forHomeCreation),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-project-sheet')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Finder project(String id) => find.byKey(Key('role-project-select-$id'));
  Finder projectScroll() => find.descendant(
    of: find.byKey(const Key('role-project-list')),
    matching: find.byType(Scrollable),
  );
  Finder confirm() => find.byKey(const Key('role-project-confirm'));

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('project list builds lazily and retains selection at $size', (
      tester,
    ) async {
      await pumpSheet(tester, size: size);
      expect(repository.pages, [(1, 20)]);
      expect(project('0'), findsOneWidget);
      expect(project('179'), findsNothing);
      expect(find.byType(ListTile).evaluate().length, lessThan(30));
      await tester.tap(project('0'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        project('179'),
        500,
        scrollable: projectScroll(),
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      expect(project('0'), findsNothing);
      expect(find.byType(ListTile).evaluate().length, lessThan(30));
      await tester.scrollUntilVisible(
        project('0'),
        -500,
        scrollable: projectScroll(),
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(project('0')).selected, isTrue);
      await tester.scrollUntilVisible(
        project('179'),
        500,
        scrollable: projectScroll(),
        maxScrolls: 100,
      );
      await tester.tap(project('179'));
      await tester.pumpAndSettle();
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      final result = selection! as ProjectSessionSelection;
      expect(result.projectId, '179');
      expect(result.session.id, 'latest');
      expect(repository.sessionRequests, ['179']);
      expect(repository.createdSessions, isEmpty);
      expect(find.byType(RoleProjectSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home creation returns the selected project ID', (tester) async {
    await pumpSheet(tester, forHomeCreation: true);
    await tester.scrollUntilVisible(
      project('179'),
      500,
      scrollable: projectScroll(),
      maxScrolls: 100,
    );
    await tester.tap(project('179'));
    await tester.pumpAndSettle();
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(selection, '179');
    expect(repository.sessionRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening failure keeps selection for retry', (tester) async {
    await pumpSheet(tester);
    await tester.tap(project('0'));
    await tester.pumpAndSettle();
    repository.failSessions = true;
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(selection, isNull);
    expect(tester.widget<ListTile>(project('0')).selected, isTrue);
    final context = tester.element(find.byType(RoleProjectSheet));
    expect(
      find.text(AppLocalizations.of(context)!.projectSessionsLoadFailed),
      findsOneWidget,
    );
    toastification.dismissAll(delayForAnimation: false);
    repository.failSessions = false;
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect((selection! as ProjectSessionSelection).projectId, '0');
    expect(repository.sessionRequests, ['0', '0']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('projects loading failure recovers when reopening', (
    tester,
  ) async {
    repository.failProjects = true;
    await pumpSheet(tester);
    expect(find.byType(ListTile), findsNothing);
    repository.failProjects = false;
    toastification.dismissAll(delayForAnimation: false);
    Navigator.of(tester.element(find.byType(RoleProjectSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-project-sheet')));
    await tester.pumpAndSettle();
    expect(project('0'), findsOneWidget);
    expect(project('179'), findsNothing);
    expect(repository.projectRequests, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project without sessions creates a conversation', (
    tester,
  ) async {
    repository.sessions = [];
    await pumpSheet(tester);
    await tester.tap(project('1'));
    await tester.pumpAndSettle();
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    final result = selection! as ProjectSessionSelection;
    expect(result.projectId, '1');
    expect(result.session.id, 'created');
    expect(repository.createdSessions, [(projectId: '1', title: 'Project 1')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading transitions to an empty project list', (tester) async {
    repository.pendingProjects = Completer<List<Project>>();
    await pumpSheet(tester, settle: false);
    expect(find.byType(AppSkeleton), findsOneWidget);
    repository.pendingProjects!.complete([]);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(RoleProjectSheet));
    expect(find.text(AppLocalizations.of(context)!.noProjects), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(selection, isNull);
    expect(repository.sessionRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
