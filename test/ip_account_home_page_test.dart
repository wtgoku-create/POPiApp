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
import 'package:popi_ai_app/features/ip_accounts/domain/account_preferences.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/ip_account_home_page.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/ip_account_history_page.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/ip_accounts_live_page.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/widgets/account_preferences_sheet.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/account_archives_page.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/ip_account_provider.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_dialog.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';

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
  final historyAccountIds = <String>[];
  final bindingAccountIds = <String>[];
  final contentRequests = <String>[];
  ProjectSession? binding;
  Completer<ProjectSession?>? pendingBinding;
  bool failBinding = false;
  bool failCreate = false;

  @override
  Future<ProjectSession?> boundSession(
    String accountId, {
    CancelToken? cancelToken,
  }) async {
    bindingAccountIds.add(accountId);
    contentRequests.add('lookup');
    if (failBinding) throw StateError('Failed');
    if (pendingBinding != null) return pendingBinding!.future;
    return binding;
  }

  @override
  Future<ListPage<ProjectSession>> listSessions(
    String projectId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    historyAccountIds.add(projectId);
    throw StateError('History must use the creation archive API');
  }

  @override
  Future<ProjectSession> createSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    contentRequests.add('create');
    accountIds.add(projectId);
    requestIds.add(clientRequestId);
    if (failCreate) throw StateError('Failed');
    return const ProjectSession(id: 'created-session', title: 'New');
  }
}

class _AccountRepository extends FixtureIpAccountRepository {
  final updates = <Map<String, Object?>>[];
  int preferenceLoads = 0;
  bool failPreferenceOptions = false;
  bool includeHiddenPreference = false;
  final historyAccountIds = <String>[];
  final historyKeywords = <String>[];
  final historyPages = <int>[];
  final detailRequests = <(String, String, String?)>[];
  Completer<AccountArchivePage>? pendingHistory;
  bool failHistory = false;
  int archivePageSize = 20;

  @override
  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  }) async {
    preferenceLoads++;
    if (failPreferenceOptions) throw StateError('Failed');
    return [
      ...await super.preferenceOptions(cancelToken: cancelToken),
      if (includeHiddenPreference)
        const AccountPreferenceStep(
          key: 'hiddenPreference',
          title: 'Hidden server preference',
          required: true,
        ),
    ];
  }

  @override
  Future<void> update(
    String id, {
    String? title,
    Map<String, Object?>? preferences,
    String? userPrompt,
    CancelToken? cancelToken,
  }) async {
    updates.add({
      'id': id,
      if (title != null) 'title': title,
      if (preferences != null) 'preferences': preferences,
      if (userPrompt != null) 'userPrompt': userPrompt,
    });
    await super.update(
      id,
      title: title,
      preferences: preferences,
      userPrompt: userPrompt,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<AccountArchivePage> archives(
    String id, {
    String keyword = '',
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    historyAccountIds.add(id);
    historyKeywords.add(keyword);
    historyPages.add(page);
    if (failHistory) throw StateError('Failed');
    if (pendingHistory != null) return pendingHistory!.future;
    final matching = creations
        .where((c) => c.title.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
    return AccountArchivePage(
      items: matching
          .skip((page - 1) * archivePageSize)
          .take(archivePageSize)
          .toList(),
      page: page,
      pageCount: (matching.length / archivePageSize).ceil(),
      total: matching.length,
    );
  }

  @override
  Future<AccountCreationArchive> archiveDetail(
    String id,
    String creationId, {
    String? versionId,
    CancelToken? cancelToken,
  }) async {
    detailRequests.add((id, creationId, versionId));
    return AccountCreationArchive.fromJson({
      'creationId': creationId,
      'title': 'Archive detail',
      'versionId': versionId,
      'script': 'Archived script',
    });
  }
}

void main() {
  late _AccountRepository repository;
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
    double bottomInset = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(_MemoryUserController.new),
        ipAccountRepositoryProvider.overrideWithValue(repository),
        projectRepositoryProvider.overrideWithValue(projects),
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(EdgeInsets.only(bottom: bottomInset));
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
          routes: [
            GoRoute(
              path: 'history',
              builder: (_, state) =>
                  IpAccountHistoryPage(accountId: state.pathParameters['id']!),
            ),
          ],
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

  Future<void> openArchives(WidgetTester tester) async {
    unawaited(
      Navigator.of(tester.element(find.byType(IpAccountHomePage))).push<void>(
        MaterialPageRoute(
          builder: (_) => const AccountArchivesPage(accountId: '42'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterCustom(
    WidgetTester tester,
    String group,
    String text,
  ) async {
    await tap(tester, 'account-custom-$group');
    await tester.enterText(find.byKey(const Key('app-expanded-input')), text);
    await tap(tester, 'app-expanded-editor-confirm');
  }

  setUp(() {
    repository = _AccountRepository();
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
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('重命名项目'), findsOneWidget);
    expect(find.text('确认修改账号昵称为：\n新昵称'), findsOneWidget);
    expect(repository.renameRequestIds, isEmpty);
    await tap(tester, 'ip-account-confirm-nickname');
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
    await tap(tester, 'ip-account-confirm-nickname');
    expect(tester.widget<TextField>(input).controller!.text, '重试昵称');
    expect(repository.title, '后来才懂');
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    repository.failSave = false;
    await tester.showKeyboard(input);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);
    expect(repository.renameRequestIds, hasLength(1));
    await tap(tester, 'ip-account-confirm-nickname');
    expect(repository.title, '重试昵称');
    expect(repository.renameRequestIds.toSet(), hasLength(1));
    expect(repository.renameRevisions, [7, 7]);
    expect(tester.takeException(), isNull);
  });

  for (final dismiss in ['cancel', 'barrier', 'back']) {
    testWidgets('dismissed rename confirmation keeps input: $dismiss', (
      tester,
    ) async {
      await pump(tester);
      final input = find.byKey(const Key('ip-account-edit-nickname'));
      await tester.enterText(input, '未保存昵称');
      await tap(tester, 'ip-account-save-nickname');
      if (dismiss == 'cancel') {
        await tester.tap(find.widgetWithText(TextButton, '取消'));
      } else if (dismiss == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(repository.renameRequestIds, isEmpty);
      expect(repository.title, '后来才懂');
      expect(tester.widget<TextField>(input).controller!.text, '未保存昵称');
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('ip-account-save-nickname')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final logout in [false, true]) {
    testWidgets('user changes dismiss rename confirmation: logout=$logout', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(
        find.byKey(const Key('ip-account-edit-nickname')),
        'Private rename',
      );
      await tap(tester, 'ip-account-save-nickname');
      if (logout) {
        await container.read(userProvider.notifier).clearUser();
      } else {
        await container
            .read(userProvider.notifier)
            .setUser(const User(id: 'another', name: 'Another', email: ''));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(find.textContaining('Private rename'), findsNothing);
      expect(repository.renameRequestIds, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rename confirmation fits long names on a small English screen', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(320, 568),
      language: 'en',
      dark: true,
      textScale: 1.3,
    );
    final name = List.filled(15, '名').join();
    await tester.enterText(
      find.byKey(const Key('ip-account-edit-nickname')),
      name,
    );
    await tap(tester, 'ip-account-save-nickname');
    final bounds = tester.getRect(
      find
          .descendant(
            of: find.byType(AppDialog),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(bounds.left, greaterThanOrEqualTo(20));
    expect(bounds.right, lessThanOrEqualTo(300));
    final confirm = find.byKey(const Key('ip-account-confirm-nickname'));
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    expect(confirm.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final bottomInset in [0.0, 16.0, 34.0]) {
    testWidgets('publish action counts bottom inset once: $bottomInset', (
      tester,
    ) async {
      await pump(tester, bottomInset: bottomInset);
      final action = find.byKey(const Key('ip-account-start-content'));
      expect(
        tester.getBottomLeft(action).dy,
        closeTo(956 - (bottomInset < 20 ? 20 : bottomInset), .01),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('publish panel stays at the bottom when overview scrolls', (
    tester,
  ) async {
    await pump(tester);
    final panel = find.byKey(const Key('ip-account-publish-panel'));
    final bounds = tester.getRect(panel);
    expect(bounds.bottom, 956);
    expect(find.text('约1分钟'), findsNothing);
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
    expect(find.text('账号记忆'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preference save preserves other fields and retries with the same ID',
    (tester) async {
      repository.includeHiddenPreference = true;
      await pump(tester);
      await tap(tester, 'ip-account-edit-preferences');
      expect(find.byKey(const Key('account-form-title')), findsNothing);
      expect(find.byKey(const Key('account-form-prompt')), findsNothing);
      expect(find.text('Hidden server preference'), findsNothing);
      for (final key in [
        'contentDirections',
        'audienceFeelings',
        'presentationFormats',
        'targetAudience',
        'creativeConstraints',
      ]) {
        expect(find.byKey(Key('account-custom-$key')), findsOneWidget);
      }
      await enterCustom(tester, 'contentDirections', '新方向');
      repository.failSave = true;
      await tap(tester, 'ip-account-edit-save');
      expect(find.text('网络请求失败，请稍后重试'), findsOneWidget);
      expect(
        find.byKey(const Key('account-custom-contentDirections')),
        findsOneWidget,
      );
      repository.failSave = false;
      await tap(tester, 'ip-account-edit-save');
      expect(repository.preferences['contentDirections'], ['新方向']);
      expect(repository.profile['positioning'], '青春里的陪伴与成长');
      expect(repository.profile['preserved'], {'enabled': true});
      expect(repository.saveRequestIds.toSet(), hasLength(1));
      expect(repository.updates, [
        for (var i = 0; i < 2; i++)
          {
            'id': '42',
            'preferences': {
              'contentDirections': ['新方向'],
            },
          },
      ]);
      expect(find.text('新方向'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('custom input replaces presets and presets clear custom input', (
    tester,
  ) async {
    repository.preferences['contentDirections'] = ['校园'];
    await pump(tester);
    await tap(tester, 'ip-account-edit-preferences');
    final chip = find.widgetWithText(FilterChip, '校园');
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    await enterCustom(tester, 'contentDirections', '独立音乐\n日常创作');
    expect(tester.widget<FilterChip>(chip).selected, isFalse);
    final input = find.descendant(
      of: find.byKey(const Key('account-custom-contentDirections')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(input).controller!.text, '独立音乐\n日常创作');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, '');
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    await enterCustom(tester, 'contentDirections', '独立音乐');
    await tap(tester, 'ip-account-edit-save');
    expect(repository.preferences['contentDirections'], ['独立音乐']);
    await tap(tester, 'ip-account-edit-preferences');
    expect(tester.widget<TextField>(input).controller!.text, '独立音乐');
    expect(repository.updates, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening legacy mixed preferences preserves every stored value', (
    tester,
  ) async {
    repository.preferences['contentDirections'] = ['校园', '旧方向一', '旧方向二'];
    await pump(tester);
    await tap(tester, 'ip-account-edit-preferences');
    expect(find.widgetWithText(InputChip, '旧方向一'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '旧方向二'), findsOneWidget);
    await tap(tester, 'ip-account-edit-save');
    expect(repository.updates, isEmpty);
    expect(repository.preferences['contentDirections'], ['校园', '旧方向一', '旧方向二']);
  });

  testWidgets(
    'expanded custom editor limits graphemes and retains edits on close',
    (tester) async {
      await pump(tester, size: const Size(320, 640));
      await tap(tester, 'ip-account-edit-preferences');
      await tap(tester, 'account-custom-contentDirections');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byKey(const Key('popi-expanded-editor'))).dy,
        lessThanOrEqualTo(400),
      );
      final editorInput = find.byKey(const Key('app-expanded-input'));
      await tester.enterText(editorInput, List.filled(51, '名').join());
      expect(
        tester
            .widget<TextField>(editorInput)
            .controller!
            .text
            .characters
            .length,
        50,
      );
      await tester.enterText(editorInput, '修改后保留\n第二行');
      await tap(tester, 'popi-expanded-editor-close');
      final input = find.descendant(
        of: find.byKey(const Key('account-custom-contentDirections')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(input).controller!.text, '修改后保留\n第二行');
      expect(repository.updates, isEmpty);
      await tester.ensureVisible(find.widgetWithText(TextButton, '取消'));
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(repository.updates, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('logout closes the nested custom editor and its parent form', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'ip-account-edit-preferences');
    await tap(tester, 'account-custom-contentDirections');
    await tester.enterText(
      find.byKey(const Key('app-expanded-input')),
      'Private custom answer',
    );
    await container.read(userProvider.notifier).clearUser();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('popi-expanded-editor')), findsNothing);
    expect(find.byKey(const Key('ip-account-edit-save')), findsNothing);
    expect(find.textContaining('Private custom answer'), findsNothing);
    expect(repository.updates, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled positioning edits do not save', (tester) async {
    await pump(tester);
    await tap(tester, 'ip-account-edit-positioning');
    expect(find.text('账号定位'), findsNWidgets(2));
    expect(find.text('用户提示词'), findsNothing);
    await tester.enterText(find.byKey(const Key('account-form-prompt')), '不保存');
    await tester.ensureVisible(find.text('取消'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.profile['positioning'], '青春里的陪伴与成长');
    expect(repository.saveRequestIds, isEmpty);
  });

  for (final card in ['preferences', 'positioning']) {
    testWidgets('unchanged $card closes without an empty update', (
      tester,
    ) async {
      await pump(tester);
      await tap(tester, 'ip-account-edit-$card');
      await tap(tester, 'ip-account-edit-save');
      expect(find.byKey(const Key('ip-account-edit-save')), findsNothing);
      expect(repository.updates, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final prompt in ['新的账号定位', '']) {
    testWidgets('positioning editor saves only its prompt: "$prompt"', (
      tester,
    ) async {
      repository.failPreferenceOptions = true;
      final previousPreferences = Map<String, Object?>.of(
        repository.preferences,
      );
      await pump(tester, size: const Size(320, 568), textScale: 1.3);
      await tap(tester, 'ip-account-edit-positioning');
      expect(find.byKey(const Key('account-form-title')), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(
        find.byKey(const Key('account-custom-contentDirections')),
        findsNothing,
      );
      final input = find.byKey(const Key('account-form-prompt'));
      expect(input, findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, '青春里的陪伴与成长');
      expect(repository.preferenceLoads, 0);
      await tester.enterText(input, prompt);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final actions = find.byKey(const Key('account-form-actions'));
      final actionBounds = tester.getRect(actions);
      expect(actionBounds.bottom, lessThanOrEqualTo(568 - 200));
      expect(
        find.byKey(const Key('ip-account-edit-save')).hitTestable(),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const Key('account-form-scroll')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(actions), actionBounds);
      repository.failSave = true;
      await tap(tester, 'ip-account-edit-save');
      expect(tester.widget<TextField>(input).controller!.text, prompt);
      repository.failSave = false;
      await tap(tester, 'ip-account-edit-save');
      expect(repository.updates, [
        {'id': '42', 'userPrompt': prompt},
        {'id': '42', 'userPrompt': prompt},
      ]);
      expect(repository.profile['positioning'], prompt);
      expect(repository.preferences, previousPreferences);
      expect(repository.title, '后来才懂');
      expect(input, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'new content opens an account draft without creating or prefilling',
    (tester) async {
      await pump(tester);
      expect(find.text('开始一条新内容'), findsOneWidget);
      await tap(tester, 'ip-account-start-content');
      expect(projects.accountIds, isEmpty);
      expect(projects.bindingAccountIds, ['42']);
      expect(projects.contentRequests, ['lookup']);
      expect(router.state.uri.queryParameters, {'accountId': '42'});
      expect(find.text('请根据这个账号的定位，帮我制作一条新内容。'), findsNothing);
    },
  );

  testWidgets('new content opens the bound session without creating', (
    tester,
  ) async {
    projects.binding = const ProjectSession(
      id: 'bound-session',
      title: 'Bound',
    );
    await pump(tester);
    expect(projects.bindingAccountIds, ['42']);
    expect(find.text('继续对话'), findsOneWidget);
    expect(find.text('开始一条新内容'), findsNothing);
    await tap(tester, 'ip-account-start-content');
    expect(projects.bindingAccountIds, ['42']);
    expect(projects.accountIds, isEmpty);
    expect(find.text('session:bound-session'), findsOneWidget);
    expect(
      GoRouterState.of(
        tester.element(find.text('session:bound-session')),
      ).uri.queryParameters,
      {'sessionId': 'bound-session'},
    );
  });

  testWidgets('a failed binding lookup cannot create and can be retried', (
    tester,
  ) async {
    projects.failBinding = true;
    await pump(tester);
    await tap(tester, 'ip-account-start-content');
    expect(projects.accountIds, isEmpty);
    expect(find.byType(IpAccountHomePage), findsOneWidget);
    projects.failBinding = false;
    projects.binding = const ProjectSession(
      id: 'bound-session',
      title: 'Bound',
    );
    await tap(tester, 'ip-account-start-content');
    expect(projects.bindingAccountIds, ['42', '42', '42']);
    expect(projects.accountIds, isEmpty);
    expect(find.text('session:bound-session'), findsOneWidget);
  });

  testWidgets('pending binding lookup ignores repeat taps and logout', (
    tester,
  ) async {
    projects.pendingBinding = Completer<ProjectSession?>();
    await pump(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 400));
    final button = find.byKey(const Key('ip-account-start-content'));
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(projects.bindingAccountIds, ['42']);
    expect(projects.accountIds, isEmpty);
    await container.read(userProvider.notifier).clearUser();
    await tester.pumpAndSettle();
    projects.pendingBinding!.complete(null);
    await tester.pumpAndSettle();
    expect(projects.accountIds, isEmpty);
    expect(find.text('session:created-session'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'returning from a draft reloads the binding and changes the action',
    (tester) async {
      await pump(tester);
      await tap(tester, 'ip-account-start-content');
      projects.binding = const ProjectSession(
        id: 'bound-session',
        title: 'Bound',
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('继续对话'), findsOneWidget);
      await tap(tester, 'ip-account-start-content');
      expect(projects.accountIds, isEmpty);
      expect(projects.contentRequests, ['lookup', 'lookup']);
      expect(find.text('session:bound-session'), findsOneWidget);
    },
  );

  testWidgets('archives page remains searchable', (tester) async {
    await pump(tester);
    await openArchives(tester);
    expect(find.byType(AccountArchivesPage), findsOneWidget);
    expect(find.byKey(const Key('account-archive-search')), findsOneWidget);
    expect(find.text('校园野餐').last, findsOneWidget);
  });

  testWidgets(
    'overview keeps history without archives, asset or role entries',
    (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('ip-account-history-section')),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('ip-account-home-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      for (final key in [
        'account-all-archives',
        'ip-account-assets-section',
        'ip-account-roles-section',
        'ip-account-add-asset',
        'ip-account-manage-roles',
      ]) {
        expect(find.byKey(Key(key)), findsNothing);
      }
      expect(find.text('创作档案'), findsNothing);
      expect(find.text('创作历史'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history shows three archives in API order and opens detail', (
    tester,
  ) async {
    repository.creations = [
      for (var i = 1; i <= 3; i++)
        IpAccountCreation(
          id: 'history-$i',
          title: 'Creation $i',
          versionId: 'version-$i',
          summary: 'Summary $i',
        ),
      const IpAccountCreation(id: 'fourth', title: 'Hidden'),
    ];
    await pump(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('ip-account-history-history-1')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('ip-account-home-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(repository.historyAccountIds, ['42']);
    expect(projects.historyAccountIds, isEmpty);
    expect(find.text('Hidden'), findsNothing);
    expect(find.text('Summary 3'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Creation 1')).dy,
      lessThan(tester.getTopLeft(find.text('Creation 3')).dy),
    );
    await tap(tester, 'ip-account-history-history-3');
    expect(find.byType(AccountArchiveDetailPage), findsOneWidget);
    expect(repository.detailRequests, [('42', 'history-3', 'version-3')]);
    expect(projects.accountIds, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(repository.historyAccountIds, ['42', '42']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history arrow opens the history page and returns after detail', (
    tester,
  ) async {
    repository.creations = [
      for (var i = 1; i <= 4; i++)
        IpAccountCreation(id: 'history-$i', title: 'Creation $i'),
    ];
    await pump(tester);
    await tap(tester, 'ip-account-history-all');
    expect(find.byType(IpAccountHistoryPage), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/ip-accounts/42/history',
    );
    expect(find.byKey(const Key('ip-account-history-search')), findsOneWidget);
    expect(find.byKey(const Key('ip-account-history-list')), findsOneWidget);
    final first = find.descendant(
      of: find.byKey(const Key('ip-account-history-list')),
      matching: find.byKey(const Key('ip-account-history-history-1')),
    );
    await tester.ensureVisible(first);
    await tester.pumpAndSettle();
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.byType(AccountArchiveDetailPage), findsOneWidget);
    expect(repository.detailRequests, [('42', 'history-1', null)]);
    expect(find.byKey(const Key('ip-account-history-list')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(IpAccountHistoryPage), findsOneWidget);
    await tap(tester, 'ip-account-history-back');
    expect(find.byType(IpAccountHomePage), findsOneWidget);
  });

  testWidgets('history searches the API, clears, and shows no matches', (
    tester,
  ) async {
    repository.creations = [
      const IpAccountCreation(id: 'picnic', title: '校园野餐'),
      const IpAccountCreation(id: 'trip', title: 'Weekend TRIP'),
    ];
    await pump(tester);
    await tap(tester, 'ip-account-history-all');
    final search = find.byKey(const Key('ip-account-history-search'));
    final searchHeight = tester.getSize(search).height;
    final loads = repository.historyAccountIds.length;
    await tester.enterText(search, ' trip ');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Weekend TRIP'), findsOneWidget);
    expect(find.text('校园野餐'), findsNothing);
    expect(tester.getSize(search).height, searchHeight);
    await tester.enterText(search, 'missing');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('未找到匹配的创作历史'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ip-account-history-clear-search')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('校园野餐'), findsOneWidget);
    expect(find.text('Weekend TRIP'), findsOneWidget);
    expect(repository.historyAccountIds.length, loads + 3);
    expect(repository.historyKeywords.skip(loads), ['trip', 'missing', '']);
    expect(projects.historyAccountIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history page retries loading and preserves search on refresh', (
    tester,
  ) async {
    await pump(tester);
    repository.failHistory = true;
    await tap(tester, 'ip-account-history-all');
    expect(find.text('创作历史加载失败'), findsOneWidget);
    repository.failHistory = false;
    repository.creations = [const IpAccountCreation(id: '1', title: '校园野餐')];
    await tap(tester, 'ip-account-history-page-retry');
    final search = find.byKey(const Key('ip-account-history-search'));
    await tester.enterText(search, '校园');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    repository.creations = [const IpAccountCreation(id: '2', title: '校园日常')];
    await tester.drag(
      find.byKey(const Key('ip-account-history-list')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(find.text('校园日常'), findsOneWidget);
    expect(find.text('校园野餐'), findsNothing);
    expect(tester.widget<TextField>(search).controller!.text, '校园');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history pagination retries without losing records and resets on search',
    (tester) async {
      repository.archivePageSize = 2;
      repository.creations = [
        for (var i = 1; i <= 4; i++)
          IpAccountCreation(id: '$i', title: 'Archive $i'),
      ];
      await pump(tester);
      await tap(tester, 'ip-account-history-all');
      repository.failHistory = true;
      await tap(tester, 'ip-account-history-load-more');
      expect(find.text('Archive 1'), findsOneWidget);
      expect(find.text('Archive 2'), findsOneWidget);
      expect(find.text('创作历史加载失败'), findsOneWidget);
      repository.failHistory = false;
      await tap(tester, 'ip-account-history-page-retry');
      expect(repository.historyPages, [1, 1, 2, 2]);
      expect(
        find.byKey(const Key('ip-account-history-load-more')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const Key('ip-account-history-search')),
        'Archive 4',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repository.historyPages.last, 1);
      expect(repository.historyKeywords.last, 'Archive 4');
      expect(find.byKey(const Key('ip-account-history-4')), findsOneWidget);
      expect(find.text('Archive 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new search ignores an older response during debounce', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'ip-account-history-all');
    final pending = repository.pendingHistory = Completer<AccountArchivePage>();
    final search = find.byKey(const Key('ip-account-history-search'));
    await tester.enterText(search, 'old');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(search, '校园');
    repository.pendingHistory = null;
    pending.complete(
      const AccountArchivePage(
        items: [IpAccountCreation(id: 'old', title: 'Stale archive')],
        page: 1,
        pageCount: 1,
        total: 1,
      ),
    );
    await tester.pump();
    expect(find.text('Stale archive'), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('校园野餐'), findsOneWidget);
    expect(find.text('Stale archive'), findsNothing);
    expect(repository.historyKeywords, ['', '', 'old', '校园']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout discards a pending history page request', (tester) async {
    await pump(tester);
    final button = find.byKey(const Key('ip-account-history-all'));
    await tester.scrollUntilVisible(
      button,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('ip-account-home-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final pending = repository.pendingHistory = Completer<AccountArchivePage>();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IpAccountHistoryPage), findsOneWidget);
    await container.read(userProvider.notifier).clearUser();
    await tester.pump();
    pending.complete(
      const AccountArchivePage(
        items: [IpAccountCreation(id: 'private', title: 'Private history')],
        page: 1,
        pageCount: 1,
        total: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IpAccountHistoryPage), findsNothing);
    expect(find.text('Private history'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history failure retries without blocking account editing', (
    tester,
  ) async {
    repository.failHistory = true;
    await pump(tester);
    expect(
      find.byKey(const Key('ip-account-edit-preferences')),
      findsOneWidget,
    );
    repository.failHistory = false;
    repository.creations = [];
    await tap(tester, 'ip-account-history-retry');
    expect(find.text('暂无历史'), findsOneWidget);
    expect(find.byKey(const Key('ip-account-history-retry')), findsNothing);
    expect(repository.historyAccountIds, ['42', '42']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logging out discards pending history results', (tester) async {
    final pending = repository.pendingHistory = Completer<AccountArchivePage>();
    await pump(tester, settle: false);
    await tester.pump();
    await container.read(userProvider.notifier).clearUser();
    await tester.pump();
    pending.complete(
      const AccountArchivePage(
        items: [
          IpAccountCreation(id: 'private', title: 'Private conversation'),
        ],
        page: 1,
        pageCount: 1,
        total: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private conversation'), findsNothing);
    expect(find.byKey(const Key('ip-account-history-section')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching users leaves the history page', (tester) async {
    repository.creations = [
      const IpAccountCreation(id: '1', title: 'Private history'),
    ];
    await pump(tester);
    await tap(tester, 'ip-account-history-all');
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'another', name: 'Another', email: ''));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ip-account-history-list')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated history fits small screens with large text', (
    tester,
  ) async {
    repository.creations = [
      const IpAccountCreation(
        id: 'long',
        title:
            'A long conversation title that must stay within the history row',
        summary: 'A long archive summary that must stay within the history row',
      ),
    ];
    await pump(
      tester,
      size: const Size(320, 640),
      language: 'en',
      dark: true,
      textScale: 1.5,
    );
    await tap(tester, 'ip-account-history-all');
    expect(find.byKey(const Key('ip-account-history-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history remains accessible on a compact English screen with enlarged text',
    (tester) async {
      await pump(
        tester,
        size: const Size(320, 568),
        language: 'en',
        dark: true,
        textScale: 1.3,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('ip-account-history-section')),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('ip-account-home-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final entry = tester.getRect(
        find.byKey(const Key('ip-account-history-section')),
      );
      expect(entry.left, greaterThanOrEqualTo(20));
      expect(entry.right, lessThanOrEqualTo(300));
      await tap(tester, 'ip-account-history-all');
      expect(find.byType(IpAccountHistoryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('logging out dismisses the archives page', (tester) async {
    await pump(tester);
    await openArchives(tester);
    expect(find.byType(AccountArchivesPage), findsOneWidget);
    await container.read(userProvider.notifier).clearUser();
    await tester.pumpAndSettle();
    expect(find.byType(AccountArchivesPage), findsNothing);
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

  testWidgets('switching users dismisses the archives page', (tester) async {
    await pump(tester);
    await openArchives(tester);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'another', name: 'Another', email: ''));
    await tester.pumpAndSettle();
    expect(find.byType(AccountArchivesPage), findsNothing);
    expect(find.text('校园野餐'), findsNothing);
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

  testWidgets('overview does not depend on asset and role loading', (
    tester,
  ) async {
    repository.failResources = true;
    await pump(tester);
    expect(
      find.byKey(const Key('ip-account-edit-preferences')),
      findsOneWidget,
    );
    expect(find.text('项目资产和角色加载失败'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tap(tester, 'ip-account-history-all');
    expect(find.byType(IpAccountHistoryPage), findsOneWidget);
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

  testWidgets('new account retries keep the creation request ID', (
    tester,
  ) async {
    await pump(tester, list: true);
    unawaited(
      AppSheet.show<String>(
        context: tester.element(find.byType(IpAccountsLivePage)),
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => const AccountPreferencesSheet(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('account-form-title')), '新账号');
    repository.failSave = true;
    await tester.ensureVisible(find.byKey(const Key('ip-account-edit-save')));
    await tester.tap(find.byKey(const Key('ip-account-edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('网络请求失败，请稍后重试'), findsOneWidget);
    repository.failSave = false;
    await tester.ensureVisible(find.byKey(const Key('ip-account-edit-save')));
    await tester.tap(find.byKey(const Key('ip-account-edit-save')));
    await tester.pumpAndSettle();
    expect(repository.createRequestIds, hasLength(2));
    expect(repository.createRequestIds.toSet(), hasLength(1));
    expect(find.byType(AccountPreferencesSheet), findsNothing);
  });

  testWidgets('archived accounts stay read-only without a status action', (
    tester,
  ) async {
    repository.status = 'archived';
    await pump(tester);
    expect(repository.status, 'archived');
    expect(find.byKey(const Key('ip-account-edit-preferences')), findsNothing);
    expect(find.byKey(const Key('account-status-action')), findsNothing);
  });

  testWidgets(
    'account list requests only active accounts without status tabs',
    (tester) async {
      await pump(tester, list: true);
      expect(repository.statuses, ['active']);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.text('已归档'), findsNothing);
      expect(find.text('全部'), findsNothing);
      expect(find.text('后来才懂'), findsOneWidget);
      expect(find.byKey(const Key('account-create')), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    },
  );

  testWidgets('account creation limits nicknames to 15 characters', (
    tester,
  ) async {
    await pump(tester, list: true);
    unawaited(
      AppSheet.show<String>(
        context: tester.element(find.byType(IpAccountsLivePage)),
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => const AccountPreferencesSheet(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('account-form-title')),
      List.filled(16, '中').join(),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('account-form-title')))
          .controller!
          .text
          .characters
          .length,
      15,
    );
    await tester.ensureVisible(find.byKey(const Key('ip-account-edit-save')));
    await tester.tap(find.byKey(const Key('ip-account-edit-save')));
    await tester.pumpAndSettle();
    expect(repository.title, List.filled(15, '中').join());
    expect(repository.createRequestIds, hasLength(1));
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
        final actions = find.byKey(const Key('account-form-actions'));
        final save = find.byKey(const Key('ip-account-edit-save'));
        final scroll = find.byKey(const Key('account-form-scroll'));
        final actionBounds = tester.getRect(actions);
        expect(save.hitTestable(), findsOneWidget);
        expect(
          find.text(language == 'en' ? 'Cancel' : '取消').hitTestable(),
          findsOneWidget,
        );
        await tester.drag(scroll, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.getRect(actions), actionBounds);
        expect(save.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(scroll).bottom,
          lessThanOrEqualTo(actionBounds.top),
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final keyboardActions = tester.getRect(actions);
        expect(keyboardActions.bottom, lessThanOrEqualTo(568 - 200));
        expect(save.hitTestable(), findsOneWidget);
        await tester.drag(scroll, const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(tester.getRect(actions), keyboardActions);
        expect(
          tester.getRect(scroll).bottom,
          lessThanOrEqualTo(keyboardActions.top),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
