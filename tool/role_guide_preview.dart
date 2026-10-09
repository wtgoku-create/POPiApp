import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/role_guide/data/role_guide_examples.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final roles = roleGuideExamples(lookupAppLocalizations(const Locale('zh')));
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          Map<String, Object?> roleJson(LibraryRole role) => {
            'id': role.id,
            'title': role.title,
            'description': role.description,
            'avatar': role.avatar,
            'profile': role.profile,
            'canUseText': true,
            'profileComplete': true,
          };
          final Object data;
          if (request.path.endsWith('/roles')) {
            data = {
              'list':
                  (request.queryParameters['category'] == 'official'
                          ? roles
                          : roles.take(2))
                      .map(roleJson)
                      .toList(),
              'pageInfo': {'page': 1, 'pageCount': 1},
            };
          } else {
            data = roleJson(
              roles.firstWhere((role) => request.path.endsWith('/${role.id}')),
            );
          }
          handler.resolve(
            Response(
              requestOptions: request,
              data: {'status': '0000', 'data': data},
            ),
          );
        },
      ),
    );
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      dioProvider.overrideWithValue(dio),
      projectRepositoryProvider.overrideWithValue(_PreviewProjects()),
    ],
  );
  await container
      .read(userProvider.notifier)
      .setUser(
        const User(id: 'preview', name: '逍遥的小柯子', email: '', allCoins: 200),
      );
  container
      .read(safeAreaInsetsProvider.notifier)
      .update(const EdgeInsets.only(top: 52, bottom: 34));
  final router = container.read(routerProvider(false));
  router.go('/role-guide');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
}

class _PreviewProjects extends ProjectRepository {
  _PreviewProjects() : super(NetworkApi(Dio()), NetworkAgentApi(Dio()));

  @override
  Future<List<Project>> listProjects({CancelToken? cancelToken}) async => [
    for (final (index, title) in [
      '后来才懂',
      '拜托了爱丽丝',
      '益达',
      '叮叮睡醒了',
      '水獭兜兜儿',
    ].indexed)
      Project(id: 'preview-project-$index', title: title),
  ];

  @override
  Future<List<ProjectSession>> listSessions(
    String projectId, {
    CancelToken? cancelToken,
  }) async => [ProjectSession(id: 'preview-session-$projectId', title: '创作会话')];
}
