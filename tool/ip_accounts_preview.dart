import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_examples.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_repository.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account_home.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:dio/dio.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/ip_account_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

/// Isolated visual preview; account and sidebar data remain local examples.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      ipAccountRepositoryProvider.overrideWithValue(
        _PreviewAccountRepository(),
      ),
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
  final router = container.read(routerProvider(false))..go('/ip-accounts');
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

class _PreviewAccountRepository extends IpAccountRepository {
  _PreviewAccountRepository() : super(NetworkApi(Dio()));
  final _profiles = <String, Map<String, Object?>>{};
  final _titles = <String, String>{};

  @override
  Future<List<IpAccount>> list({CancelToken? cancelToken}) async => [
    for (final account in ipAccountExamples)
      IpAccount(
        id: account.id,
        title: _titles[account.id] ?? account.title,
        description: account.description,
        isPaused: account.isPaused,
      ),
  ];

  @override
  Future<IpAccountHome> detail(String id, {CancelToken? cancelToken}) async {
    final account = ipAccountExamples.firstWhere((account) => account.id == id);
    return IpAccountHome(
      id: id,
      title: _titles[id] ?? account.title,
      revision: 1,
      status: account.isPaused ? 'archived' : 'active',
      profile:
          _profiles[id] ??
          {
            'contentDirection': '校园情感',
            'audienceFeeling': '真实 / 泪目',
            'presentation': 'AI真人',
            'contentFormat': '剧情短片',
            'targetAudience': '学生群体 x 职场人群',
            'positioning':
                '这是一个聚焦校园与情感的账号，以AI真人剧情短片为载体，讲述青春里的心动、友情、陪伴与成长。\n从教室里的悄悄关注，到放学路上的并肩同行，将那些平凡却难忘的瞬间，化作温暖治愈的故事。',
          },
    );
  }

  @override
  Future<IpAccountResources> resources(
    IpAccountHome account, {
    CancelToken? cancelToken,
  }) async => const IpAccountResources();

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
