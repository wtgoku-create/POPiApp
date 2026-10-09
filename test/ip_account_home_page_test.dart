import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account_home.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/ip_account_home_page.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/ip_accounts_live_page.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/ip_account_provider.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/ip_account_fixtures.dart';
import 'support/project_fixtures.dart';
import 'support/session_fixtures.dart';

class _MemoryUserController extends UserController {
  @override
  Future<void> clearUser() async {
    state = null;
  }
}

class _ProjectRepository extends FixtureProjectRepository {
  final accountIds = <String>[];
  final requestIds = <String>[];
  bool failCreate = false;

  @override
  Future<ProjectSession> createSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    accountIds.add(projectId);
    requestIds.add(clientRequestId);
    if (failCreate) throw StateError('Failed');
    return const ProjectSession(id: 'created-session', title: 'New');
  }
}

void main() {
  late FixtureIpAccountRepository repository;
  late _ProjectRepository projects;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    bool list = false,
    bool signedIn = true,
    bool dark = false,
    String language = 'zh',
    Size size = const Size(440, 956),
    double textScale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(_MemoryUserController.new),
        ipAccountRepositoryProvider.overrideWithValue(repository),
        projectRepositoryProvider.overrideWithValue(projects),
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
      ],
    );
    addTearDown(container.dispose);
    if (signedIn) {
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'user', name: 'User', email: ''));
    }
    router = GoRouter(
      initialLocation: list ? '/ip-accounts' : '/ip-accounts/42',
      routes: [
        GoRoute(
          path: '/ip-accounts',
          builder: (_, _) => const IpAccountsLivePage(),
        ),
        GoRoute(
          path: '/ip-accounts/:id',
          builder: (_, state) =>
              IpAccountHomePage(accountId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/session',
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                Text('session:${state.uri.queryParameters['sessionId']}'),
                Text(state.uri.queryParameters['prompt'] ?? ''),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Login')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> tap(WidgetTester tester, String key) async {
    if (find.byKey(Key(key)).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('ip-account-home-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = FixtureIpAccountRepository();
    projects = _ProjectRepository();
  });
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  testWidgets('list opens the matching home and refreshes renamed titles', (
    tester,
  ) async {
    await pump(tester, list: true);
    await tester.tap(find.text('后来才懂'));
    await tester.pumpAndSettle();
    expect(find.text('账号主页'), findsOneWidget);
    await tap(tester, 'ip-account-edit-nickname');
    await tester.enterText(
      find.byKey(const Key('ip-account-edit-nickname')),
      '新昵称',
    );
    expect(find.byKey(const Key('ip-account-edit-save')), findsNothing);
    await tap(tester, 'ip-account-save-nickname');
    expect(find.text('新昵称'), findsNWidgets(2));
    await tap(tester, 'ip-account-home-back');
    expect(find.text('新昵称'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline nickname retains failed input and stable retry ID', (
    tester,
  ) async {
    await pump(tester);
    final input = find.byKey(const Key('ip-account-edit-nickname'));
    await tester.enterText(input, '重试昵称');
    repository.failSave = true;
    await tap(tester, 'ip-account-save-nickname');
    expect(tester.widget<TextField>(input).controller!.text, '重试昵称');
    expect(repository.title, '后来才懂');
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    repository.failSave = false;
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(repository.title, '重试昵称');
    expect(repository.renameRequestIds.toSet(), hasLength(1));
    expect(repository.renameRevisions, [7, 7]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('publish panel stays at the bottom when overview scrolls', (
    tester,
  ) async {
    await pump(tester);
    final panel = find.byKey(const Key('ip-account-publish-panel'));
    final bounds = tester.getRect(panel);
    expect(bounds.bottom, 956);
    expect(find.text('约1分钟'), findsOneWidget);
    expect(find.text('账号已经准备好，可以从选题、想法、脚本或素材开始。'), findsOneWidget);
    final edit = find.byKey(const Key('ip-account-edit-preferences'));
    expect(tester.getSize(edit), const Size(97, 40));
    expect(
      tester.widget<TextButton>(edit).style!.visualDensity,
      VisualDensity.standard,
    );
    final start = find.byKey(const Key('ip-account-start-content'));
    expect(tester.getSize(start).height, 50);
    expect(
      tester.widget<FilledButton>(start).style!.visualDensity,
      VisualDensity.standard,
    );
    await tester.drag(
      find.byKey(const Key('ip-account-home-list')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(panel), bounds);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preference save preserves other fields and retries with the same ID',
    (tester) async {
      await pump(tester);
      await tap(tester, 'ip-account-edit-preferences');
      await tester.enterText(
        find.byKey(const Key('ip-account-edit-contentDirection')),
        '新方向',
      );
      repository.failSave = true;
      await tap(tester, 'ip-account-edit-save');
      expect(find.text('网络请求失败，请稍后重试'), findsOneWidget);
      expect(
        find.byKey(const Key('ip-account-edit-contentDirection')),
        findsOneWidget,
      );
      repository.failSave = false;
      await tap(tester, 'ip-account-edit-save');
      expect(repository.profile['contentDirection'], '新方向');
      expect(repository.profile['positioning'], '青春里的陪伴与成长');
      expect(repository.profile['preserved'], {'enabled': true});
      expect(repository.saveRequestIds.toSet(), hasLength(1));
      expect(find.text('新方向'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelled positioning edits do not save', (tester) async {
    await pump(tester);
    await tap(tester, 'ip-account-edit-positioning');
    await tester.enterText(
      find.byKey(const Key('ip-account-edit-positioning')),
      '不保存',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.profile['positioning'], '青春里的陪伴与成长');
    expect(repository.saveRequestIds, isEmpty);
  });

  testWidgets('project residents can be selected, saved, and removed', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'ip-account-manage-roles');
    await tap(tester, 'ip-account-select-role-20');
    await tap(tester, 'ip-account-roles-save');
    expect(repository.residents, ['20']);
    await tap(tester, 'ip-account-manage-roles');
    await tap(tester, 'ip-account-select-role-20');
    await tap(tester, 'ip-account-roles-save');
    expect(repository.residents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new content creates an account-bound session and preserves retry ID',
    (tester) async {
      await pump(tester);
      projects.failCreate = true;
      await tap(tester, 'ip-account-start-content');
      projects.failCreate = false;
      await tap(tester, 'ip-account-start-content');
      expect(projects.accountIds, ['42', '42']);
      expect(projects.requestIds.toSet(), hasLength(1));
      expect(find.text('session:created-session'), findsOneWidget);
      expect(find.text('请根据这个账号的定位，帮我制作一条新内容。'), findsOneWidget);
    },
  );

  testWidgets('assets open their saved conversation', (tester) async {
    await pump(tester);
    await tap(tester, 'ip-account-assets');
    await tester.tap(find.text('校园野餐').last);
    await tester.pumpAndSettle();
    expect(find.text('session:work-session'), findsOneWidget);
  });

  testWidgets('empty resources keep header actions and right-side add tiles', (
    tester,
  ) async {
    repository.creations = [];
    await pump(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('ip-account-roles-section')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('ip-account-home-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    for (final name in ['assets', 'roles']) {
      final section = find.byKey(Key('ip-account-$name-section'));
      expect(tester.getSize(section), const Size(400, 125));
      expect(
        find.descendant(of: section, matching: find.byType(Divider)),
        findsNothing,
      );
      final arrow = find.byKey(Key('ip-account-$name'));
      final add = find.byKey(
        Key(
          name == 'assets' ? 'ip-account-add-asset' : 'ip-account-manage-roles',
        ),
      );
      expect(tester.getSize(add), const Size(51.6, 51.6));
      expect(tester.getRect(add).right, tester.getRect(section).right - 20);
      expect(tester.getRect(arrow).top, lessThan(tester.getRect(add).top));
    }
    expect(find.text('暂无作品，去和Agent聊聊做些什么'), findsOneWidget);
    expect(find.text('添加角色，建立自己的创作世界'), findsOneWidget);
    await tap(tester, 'ip-account-roles');
    expect(find.byKey(const Key('ip-account-roles-save')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, 'ip-account-assets');
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset add tile creates content for the current account', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'ip-account-add-asset');
    expect(projects.accountIds, ['42']);
    expect(find.text('session:created-session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty English resources fit a compact screen with enlarged text',
    (tester) async {
      repository.creations = [];
      await pump(
        tester,
        size: const Size(320, 568),
        language: 'en',
        dark: true,
        textScale: 1.3,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('ip-account-manage-roles')),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('ip-account-home-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final section = tester.getRect(
        find.byKey(const Key('ip-account-roles-section')),
      );
      final add = tester.getRect(
        find.byKey(const Key('ip-account-manage-roles')),
      );
      expect(add.right, lessThanOrEqualTo(section.right - 20));
      expect(
        find.text('Add roles to build your creative world.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('logging out dismisses an open assets sheet', (tester) async {
    await pump(tester);
    await tap(tester, 'ip-account-assets');
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    await container.read(userProvider.notifier).clearUser();
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('校园野餐'), findsNothing);
  });

  testWidgets('logging out dismisses edits without saving them', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'ip-account-edit-preferences');
    await container.read(userProvider.notifier).clearUser();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ip-account-edit-save')), findsNothing);
    expect(repository.saveRequestIds, isEmpty);
  });

  testWidgets('switching users dismisses the resident selector', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'ip-account-manage-roles');
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'another', name: 'Another', email: ''));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ip-account-roles-save')), findsNothing);
    expect(repository.residents, isEmpty);
  });

  testWidgets('failed detail loading can be retried', (tester) async {
    repository.failDetail = true;
    await pump(tester);
    expect(find.text('账号资料加载失败，请重试'), findsOneWidget);
    repository.failDetail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('后来才懂'), findsNWidgets(2));
  });

  testWidgets('resource failure leaves account preferences editable', (
    tester,
  ) async {
    repository.failResources = true;
    await pump(tester);
    expect(
      find.byKey(const Key('ip-account-edit-preferences')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('项目资产和角色加载失败'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('ip-account-home-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('项目资产和角色加载失败'), findsOneWidget);
  });

  testWidgets('logging out cancels stale detail results', (tester) async {
    final pending = repository.pendingDetail = Completer<IpAccountHome>();
    await pump(tester, settle: false);
    await container.read(userProvider.notifier).clearUser();
    await tester.pump();
    pending.complete(
      const IpAccountHome(id: '42', title: 'Private', revision: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private'), findsNothing);
    expect(find.text('登录'), findsNothing);
    expect(find.byKey(const Key('ip-account-start-content')), findsNothing);
  });

  for (final dark in [false, true]) {
    for (final language in ['zh', 'en']) {
      testWidgets('compact $language overview and editor fit: dark $dark', (
        tester,
      ) async {
        await pump(
          tester,
          size: const Size(320, 568),
          dark: dark,
          language: language,
          textScale: 1.3,
        );
        await tap(tester, 'ip-account-edit-preferences');
        await tester.ensureVisible(
          find.byKey(const Key('ip-account-edit-save')),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
