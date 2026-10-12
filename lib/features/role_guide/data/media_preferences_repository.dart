import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../domain/home_creation.dart';
import '../domain/session_media_preferences.dart';

/// Model catalogs and conversation preferences shared by home and chat.
class MediaPreferencesRepository {
  MediaPreferencesRepository(this._api);
  final NetworkApi _api;

  Future<List<HomeModel>> models({
    String mediaType = 'video',
    CancelToken? cancelToken,
  }) async =>
      homeObjects(
            (await _api.mediaModels(
              mediaType: mediaType,
              cancelToken: cancelToken,
            ))['list'],
          )
          .map(HomeModel.fromJson)
          .where((model) => model.available && model.mediaType == mediaType)
          .toList();

  Future<SessionMediaPreferences> mediaPreferences(
    String sessionId, {
    CancelToken? cancelToken,
  }) async => SessionMediaPreferences.fromJson(
    await _api.sessionMediaPreferences(sessionId, cancelToken: cancelToken),
  );

  Future<void> saveMediaPreference(
    String sessionId,
    String mediaType,
    HomeConfig config, {
    CancelToken? cancelToken,
  }) => _api.updateSessionMediaPreferences(
    sessionId: sessionId,
    mediaType: mediaType,
    config: config.toJson(),
    cancelToken: cancelToken,
  );

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
}
