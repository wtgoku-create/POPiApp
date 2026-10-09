import 'package:dio/dio.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';

/// Backend-shaped fixtures kept outside production widgets and localization.
class FixtureProjectRepository extends ProjectRepository {
  FixtureProjectRepository() : super(NetworkApi(Dio()));

  @override
  Future<List<Project>> listProjects({CancelToken? cancelToken}) async => [
    for (final entry in [
      ('0', '爱丽丝'),
      ('1', '水獭兜兜儿'),
      ('2', '小可爱美美'),
      ('3', '羞答答'),
      ('4', '艾尔拉薇娅'),
    ])
      Project(id: entry.$1, title: entry.$2),
  ];

  @override
  Future<List<ProjectSession>> listSessions(
    String projectId, {
    CancelToken? cancelToken,
  }) async => [
    for (final (index, title) in (switch (projectId) {
      '0' => ['也许他还记得那些曾今说过的话...', '校园野餐vlog', '开心的国庆假期出游'],
      '1' => ['艾露尼斯他木心', '请停止这一切', '没什么大不了', '采蘑菇的小女孩'],
      _ => <String>[],
    }).indexed)
      ProjectSession(id: '$index', title: title),
  ];
}
