import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../core/network/network_api.dart';
import '../../assets/domain/library_role.dart';
import '../domain/home_creation.dart';
import 'media_preferences_repository.dart';

/// Mirrors Web home commands and keeps uncertain writes safe to retry.
class HomeCreationRepository extends MediaPreferencesRepository {
  HomeCreationRepository(this._api, this._agent) : super(_api);
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

  List<int> _roleIds(List<LibraryRole> roles, {bool allowEmpty = false}) {
    final ids = roles.map((role) => int.tryParse(role.id)).toList();
    if ((!allowEmpty && ids.isEmpty) ||
        ids.length > 5 ||
        ids.toSet().length != ids.length ||
        ids.any((id) => id == null || id <= 0) ||
        roles.any((role) => !role.readyForHomeCreation)) {
      throw const ApiException(message: 'Role is not ready for video creation');
    }
    return ids.cast<int>();
  }

  Future<HomeCreation> open(String accountId, {CancelToken? cancelToken}) =>
      _enter({'accountId': accountId}, cancelToken);

  Future<HomeCreation> continueCreation(
    HomeCreation home, {
    CancelToken? cancelToken,
  }) => _enter({'accountId': home.accountId, 'newCreation': true}, cancelToken);

  Future<HomeCreation> _enter(Map<String, Object?> input, CancelToken? token) =>
      _command(
        'enter',
        input,
        (body) async => HomeCreation.fromJson(
          await _agent.enterHome(body, cancelToken: token),
        ),
      );

  Future<HomeCreation> refresh(HomeCreation home, {CancelToken? cancelToken}) =>
      open(home.accountId, cancelToken: cancelToken);

  Future<HomeCreation> recommend(
    HomeCreation home, {
    CancelToken? cancelToken,
  }) => _command(
    'topics:${home.sessionId}:${home.id}',
    {'mode': 'recommend'},
    (body) async => HomeCreation.fromJson(
      homeObject(
        (await _agent.recommendHomeTopics(
          home.sessionId,
          body,
          cancelToken: cancelToken,
        ))['snapshot'],
      ),
    ),
  );

  Future<HomeCreation> selectTopic(
    HomeCreation home,
    HomeTopic topic, {
    CancelToken? cancelToken,
  }) => _command(
    'topic:${home.id}',
    {'topicId': topic.id},
    (body) async => HomeCreation.fromJson(
      homeObject(
        (await _agent.selectHomeTopic(
          home.sessionId,
          body,
          cancelToken: cancelToken,
        ))['snapshot'],
      ),
    ),
  );

  Future<HomeCreation> replaceCast(
    HomeCreation home,
    List<LibraryRole> roles, {
    CancelToken? cancelToken,
  }) async {
    final roleIds = _roleIds(roles, allowEmpty: true);
    return _command(
      'cast:${home.sessionId}',
      {'roleIds': roleIds, 'reply': false},
      (body) async {
        await _agent.updateSessionCast(
          home.sessionId,
          body,
          cancelToken: cancelToken,
        );
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

  Future<HomeCreation> generate(
    HomeCreation home,
    HomeConfig config, {
    CancelToken? cancelToken,
  }) => _command(
    'generate:${home.sessionId}:${home.id}',
    {'config': config.toJson()},
    (body) async => HomeCreation.fromJson(
      homeObject(
        (await _agent.generateHome(
          home.sessionId,
          body,
          cancelToken: cancelToken,
        ))['snapshot'],
      ),
    ),
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
      'control:${task.id}:$action',
      {if (action != 'confirm-video') 'action': action},
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
