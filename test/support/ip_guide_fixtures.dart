import 'package:dio/dio.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';

class MemoryGuideStorage extends PreferencesStorage {
  MemoryGuideStorage(super.preferences);
  final values = <String, String>{};
  bool failWrites = false;
  int readCount = 0;

  @override
  String? getString(String key) {
    readCount++;
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('Storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class FixtureIpGuideApi extends NetworkApi {
  FixtureIpGuideApi() : super(Dio());
  final accountRequests = <String>[];
  final profileRequests = <String>[];
  Map<String, Object?>? savedProfile;
  bool failAccount = false;
  bool failProfile = false;

  @override
  Future<(String, int)> createIpAccount({
    required String title,
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    accountRequests.add(clientRequestId);
    if (failAccount) throw StateError('Network unavailable');
    return ('created-account', 1);
  }

  @override
  Future<void> saveIpAccountProfile(
    String id, {
    required int revision,
    required String clientRequestId,
    required Map<String, Object?> profile,
    CancelToken? cancelToken,
  }) async {
    profileRequests.add(clientRequestId);
    if (failProfile) throw StateError('Profile unavailable');
    savedProfile = profile;
  }
}
