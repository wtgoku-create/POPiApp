import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../core/network/network_api.dart';
import '../../assets/domain/library_role.dart';
import '../domain/home_creation.dart';

/// Mirrors Web home commands and keeps uncertain writes safe to retry.
class HomeCreationRepository {
  HomeCreationRepository(this._api, this._agent);
  final NetworkApi _api;
  final NetworkAgentApi _agent;
  final _pending = <String, String>{};

  Future<T> _command<T>(
    String operation,
    Map<String, Object?> input,
    Future<T> Function(Map<String, Object?>) execute,
  ) async {
    final key = '$operation:${jsonEncode(input)}';
    final id = _pending.putIfAbsent(key, () => const Uuid().v4());
    try {
      final result = await execute({'clientRequestId': id, ...input});
      _pending.remove(key);
      return result;
    } catch (error) {
      if (isConflict(error)) _pending.remove(key);
      rethrow;
    }
  }

  static bool isConflict(Object error) =>
      error is ApiException && error.statusCode == 409 ||
      error is DioException && error.response?.statusCode == 409;

  Future<HomeCreation> create(
    List<LibraryRole> roles, {
    CancelToken? cancelToken,
  }) {
    return _enter({'roleIds': _roleIds(roles)}, cancelToken);
  }

  List<int> _roleIds(List<LibraryRole> roles) {
    final ids = roles.map((role) => int.tryParse(role.id)).toList();
    if (ids.isEmpty ||
        ids.length > 5 ||
        ids.toSet().length != ids.length ||
        ids.any((id) => id == null || id <= 0) ||
        roles.any((role) => !role.readyForHomeCreation)) {
      throw const ApiException(message: 'Role is not ready for video creation');
    }
    return ids.cast<int>();
  }

  Future<HomeCreation> open(
    String accountId, {
    String? sessionId,
    CancelToken? cancelToken,
  }) => _enter({
    'accountId': accountId,
    if (sessionId != null) 'sessionId': sessionId,
  }, cancelToken);

  Future<HomeCreation> continueCreation(
    HomeCreation home, {
    CancelToken? cancelToken,
  }) => _enter({
    'accountId': home.accountId,
    'sessionId': home.sessionId,
    'sourceCreationId': home.id,
    'expectedRevision': home.version,
  }, cancelToken);

  Future<HomeCreation> _enter(Map<String, Object?> input, CancelToken? token) =>
      _command(
        'enter',
        input,
        (body) async => HomeCreation.fromJson(
          await _agent.enterHome(body, cancelToken: token),
        ),
      );

  Future<HomeCreation> refresh(HomeCreation home, {CancelToken? cancelToken}) =>
      open(home.accountId, sessionId: home.sessionId, cancelToken: cancelToken);

  Future<HomeCreation> recommend(
    HomeCreation home, {
    CancelToken? cancelToken,
  }) => _command(
    'topics',
    {
      'creationId': home.id,
      'expectedRevision': home.version,
      'mode': 'recommend',
    },
    (body) async {
      await _agent.recommendHomeTopics(
        home.sessionId,
        body,
        cancelToken: cancelToken,
      );
      return refresh(home, cancelToken: cancelToken);
    },
  );

  Future<HomeCreation> selectTopic(
    HomeCreation home,
    HomeTopic topic, {
    CancelToken? cancelToken,
  }) => _command(
    'topic:${home.id}',
    {'expectedRevision': home.version, 'topicId': topic.id},
    (body) async {
      await _api.selectHomeTopic(home.id, body, cancelToken: cancelToken);
      return refresh(home, cancelToken: cancelToken);
    },
  );

  Future<HomeCreation> replaceCast(
    HomeCreation home,
    List<LibraryRole> roles, {
    CancelToken? cancelToken,
  }) async {
    _roleIds(roles);
    final cast = <Map<String, Object?>>[];
    for (final role in roles) {
      final existing = homeObjects(
        home.revision['cast'],
      ).where((item) => item['id'].toString() == role.id);
      final detail = existing.isNotEmpty
          ? existing.first
          : await _api.libraryRoleDetail(role.id, cancelToken: cancelToken);
      cast.add({
        'roleId': int.parse(role.id),
        'profileVersionId': homeId(homeObject(detail['profileVersion'])['id']),
        if (detail['creationRoleVersionId'] != null)
          'creationRoleVersionId': detail['creationRoleVersionId'],
      });
    }
    return _command(
      'cast:${home.id}',
      {
        'expectedRevision': home.version,
        'brief': home.revision['brief'],
        'outputMode': home.revision['outputMode'],
        'accountProfileVersionId': home.revision['accountProfileVersionId'],
        'inputContentVersionIds': <String>[],
        'topicId': null,
        'cast': cast,
        'specs': home.revision['specs'],
      },
      (body) async {
        await _api.saveHomeCast(home.id, body, cancelToken: cancelToken);
        return refresh(home, cancelToken: cancelToken);
      },
    );
  }

  Future<HomeCreation> saveRoleProfile(
    HomeCreation home,
    String roleId,
    Map<String, Object?> profile, {
    CancelToken? cancelToken,
  }) {
    final id = int.tryParse(roleId);
    if (!home.editable ||
        id == null ||
        !home.cast.any((role) => role.id == roleId)) {
      throw const ApiException(
        message: 'Role is not editable in this creation',
      );
    }
    return _command(
      'role-profile:${home.id}',
      {'roleId': id, 'profile': profile},
      (body) async {
        await _api.saveHomeRoleProfile(home.id, body, cancelToken: cancelToken);
        return refresh(home, cancelToken: cancelToken);
      },
    );
  }

  Future<List<HomeModel>> models({CancelToken? cancelToken}) async =>
      homeObjects(
            (await _api.homeVideoModels(cancelToken: cancelToken))['list'],
          )
          .map(HomeModel.fromJson)
          .where((model) => model.available && model.supportsHomeDuration)
          .toList();

  Future<num> estimate(HomeConfig config, {CancelToken? cancelToken}) async {
    final points = (await _api.estimateHomeGeneration(
      config.toJson(),
      cancelToken: cancelToken,
    ))['estimatedPoints'];
    if (points is! num || !points.isFinite || points < 0) {
      throw const ApiException();
    }
    return points;
  }

  Future<HomeTask> generate(
    HomeCreation home,
    HomeConfig config, {
    CancelToken? cancelToken,
  }) => _command(
    'generate',
    {
      'creationId': home.id,
      'expectedRevision': home.version,
      'config': config.toJson(),
    },
    (body) async =>
        _task(await _agent.generateHome(body, cancelToken: cancelToken)),
  );

  Future<HomeTask> task(String id, {CancelToken? cancelToken}) async =>
      _task(await _agent.homeTask(id, cancelToken: cancelToken));

  Future<HomeTask> control(
    HomeTask task,
    String action, {
    CancelToken? cancelToken,
  }) {
    if (!task.allowedActions.contains(action) &&
        !(action == 'confirm-video' && task.canConfirmVideo)) {
      throw const ApiException(message: 'Action unavailable');
    }
    return _command(
      'control:${task.id}',
      {
        'revision': task.revision,
        if (action != 'confirm-video') 'action': action,
      },
      (body) async => _task(
        await _agent.controlHomeTask(
          task.id,
          body,
          confirmVideo: action == 'confirm-video',
          cancelToken: cancelToken,
        ),
      ),
    );
  }

  HomeTask _task(Map<String, Object?> response) =>
      HomeTask.fromJson(homeObject(response['task'] ?? response));

  Future<Uri> media(String id, {CancelToken? cancelToken}) async {
    final result = await _api.studioMedia(id, cancelToken: cancelToken);
    return Uri.parse(_api.mediaBaseUrl).resolve(homeId(result['url']));
  }
}
