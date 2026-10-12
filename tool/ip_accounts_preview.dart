import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_examples.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_repository.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account_home.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/account_preferences.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/ip_guide/data/ip_guide_repository.dart';
import 'package:popi_ai_app/features/ip_guide/domain/ip_guide_draft.dart';
import 'package:dio/dio.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/ip_account_provider.dart';
import 'package:popi_ai_app/shared/providers/ip_guide_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

/// Isolated visual preview; account and sidebar data remain local examples.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final accounts = _PreviewAccountRepository();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      ipAccountRepositoryProvider.overrideWithValue(accounts),
      ipGuideRepositoryProvider.overrideWith((ref) {
        final repository = _PreviewGuideRepository(
          ref.watch(preferencesStorageProvider),
          accounts,
        );
        ref.onDispose(repository.dispose);
        return repository;
      }),
      projectsProvider.overrideWith(
        (_) async => [
          for (final account in ipAccountExamples)
            Project(id: account.id, title: account.title),
        ],
      ),
      projectSessionsProvider.overrideWith((_, _) async => []),
    ],
  );
  await container
      .read(userProvider.notifier)
      .setUser(const User(id: 'preview', name: 'POPi', email: ''));
  final router = container.read(routerProvider(false))
    ..go(
      Uri.base.fragment.startsWith('/ip-guide') ? '/ip-guide' : '/ip-accounts',
    );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: Uri.base.queryParameters['theme'] == 'dark'
            ? AppTheme.dark
            : AppTheme.light,
        locale: Locale(Uri.base.queryParameters['lang'] ?? 'zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
}

class _PreviewGuideRepository extends IpGuideRepository {
  _PreviewGuideRepository(PreferencesStorage storage, this.accounts)
    : super(storage, NetworkApi(Dio()), userId: 'preview');

  final IpAccountRepository accounts;

  @override
  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  }) => accounts.preferenceOptions(cancelToken: cancelToken);

  @override
  Future<String> create(
    IpGuideDraft draft,
    Map<String, Object?> profile,
  ) async {
    draft.creationRequestId ??= const Uuid().v4();
    draft.accountId = await accounts.create(
      requestId: draft.creationRequestId!,
      title: draft.nickname.trim(),
      preferences: profile,
    );
    await clear();
    return draft.accountId!;
  }
}

class _PreviewAccountRepository extends IpAccountRepository {
  _PreviewAccountRepository() : super(NetworkApi(Dio()));
  final _profiles = <String, Map<String, Object?>>{};
  final _titles = <String, String>{};
  final _statuses = <String, String>{};
  final _prompts = <String, String>{};
  final _created = <String, String>{};

  @override
  Future<List<IpAccount>> list({
    String status = 'active',
    CancelToken? cancelToken,
  }) async => [
    for (final account in [
      ...ipAccountExamples,
      for (final id in _created.values)
        IpAccount(id: id, title: _titles[id]!, description: ''),
    ])
      if (status == 'all' ||
          status ==
              (_statuses[account.id] ??
                  (account.isPaused ? 'archived' : 'active')))
        IpAccount(
          id: account.id,
          title: _titles[account.id] ?? account.title,
          description: account.description,
          isPaused:
              (_statuses[account.id] ??
                  (account.isPaused ? 'archived' : 'active')) ==
              'archived',
        ),
  ];

  @override
  Future<IpAccountHome> detail(String id, {CancelToken? cancelToken}) async {
    final account = ipAccountExamples.firstWhere(
      (account) => account.id == id,
      orElse: () => IpAccount(id: id, title: _titles[id]!, description: ''),
    );
    return IpAccountHome(
      id: id,
      title: _titles[id] ?? account.title,
      revision: 1,
      status: _statuses[id] ?? (account.isPaused ? 'archived' : 'active'),
      userPrompt: _prompts[id] ?? '保持温暖的表达',
      memoryMarkdown: '## 创作记忆\n\n围绕日常生活中的陪伴与成长展开。',
      preferences:
          _profiles[id] ??
          {
            'contentDirections': ['校园', '情感'],
            'audienceFeelings': ['真实', '治愈'],
            'presentationFormats': ['AI 真人'],
            'targetAudience': ['学生', '年轻人'],
          },
    );
  }

  @override
  Future<IpAccountResources> resources(
    IpAccountHome account, {
    CancelToken? cancelToken,
  }) async => const IpAccountResources();

  @override
  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  }) async => [
    for (final entry in {
      'contentDirections': ['校园', '家庭', '职场', '情感', '生活', '科普'],
      'audienceFeelings': ['真实', '泪目', '治愈', '欢乐', '热血', '惊喜'],
      'presentationFormats': [
        '3D 动漫',
        '国风水墨',
        'AI 真人',
        '2D 动画',
        '绘本插画',
        '定格动画',
      ],
      'targetAudience': ['学生', '打工牛马', '亲子家庭', '年轻人', '银发人群', '大众观众'],
    }.entries)
      AccountPreferenceStep(
        key: entry.key,
        title: entry.key,
        maxNameBytes: entry.key == 'targetAudience' ? 2000 : 300,
        options: [
          for (final name in entry.value) AccountPreferenceOption(name: name),
        ],
      ),
  ];

  @override
  Future<void> update(
    String id, {
    String? title,
    Map<String, Object?>? preferences,
    String? userPrompt,
    CancelToken? cancelToken,
  }) async {
    if (title != null) _titles[id] = title;
    if (preferences != null) {
      _profiles[id] = {...(await detail(id)).preferences, ...preferences};
    }
    if (userPrompt != null) _prompts[id] = userPrompt;
  }

  @override
  Future<String> create({
    required String requestId,
    String? title,
    Map<String, Object?>? preferences,
    String? userPrompt,
    CancelToken? cancelToken,
  }) async {
    final id = _created.putIfAbsent(
      requestId,
      () => 'preview-${_created.length + 1}',
    );
    _titles[id] = title ?? '未命名账号';
    _profiles[id] = preferences ?? {};
    _prompts[id] = userPrompt ?? '';
    return id;
  }

  @override
  Future<void> archive(String id, {CancelToken? cancelToken}) async {
    _statuses[id] = 'archived';
  }

  @override
  Future<void> restore(String id, {CancelToken? cancelToken}) async {
    _statuses[id] = 'active';
  }

  @override
  Future<AccountArchivePage> archives(
    String id, {
    String keyword = '',
    int page = 1,
    CancelToken? cancelToken,
  }) async => AccountArchivePage(
    items: [
      if ('放学后的约定'.contains(keyword))
        const IpAccountCreation(
          id: '20',
          title: '放学后的约定',
          versionId: '30',
          summary: '同学之间互相帮助的故事',
        ),
    ],
    page: 1,
    pageCount: 1,
    total: keyword.isEmpty ? 1 : 0,
  );
  @override
  Future<AccountCreationArchive> archiveDetail(
    String id,
    String creationId, {
    String? versionId,
    CancelToken? cancelToken,
  }) async => AccountCreationArchive(
    title: '放学后的约定',
    versionId: versionId ?? '30',
    versions: const {'30': 1, '31': 2},
    sections: {
      'summary': '同学之间互相帮助的故事',
      'brief': '温暖的校园短片',
      'topic': '同学互助',
      'script': versionId == '31'
          ? '放学后，两位同学并肩走过操场，分享今天的收获。'
          : '放学后，两位同学一起完成未完成的作业。',
      'storyboard': '1. 教室全景\n2. 两人讨论题目',
    },
  );

  @override
  Future<void> rename(
    String id,
    String title, {
    required int revision,
    required String requestId,
    CancelToken? cancelToken,
  }) async {
    _titles[id] = title;
  }

  @override
  Future<void> saveProfile(
    IpAccountHome account,
    Map<String, Object?> changes, {
    required String requestId,
    CancelToken? cancelToken,
  }) async {
    _profiles[account.id] = {...account.profile, ...changes};
  }
}
