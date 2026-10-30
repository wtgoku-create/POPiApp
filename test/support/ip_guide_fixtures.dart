import 'package:dio/dio.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';

class MemoryGuideStorage extends PreferencesStorage {
  MemoryGuideStorage(super.preferences);
  final values = <String, String>{};
  bool failWrites = false;
  bool failRemoves = false;
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
  Future<void> remove(String key) async {
    if (failRemoves) throw StateError('Storage unavailable');
    values.remove(key);
  }
}

class FixtureIpGuideAgentApi extends NetworkAgentApi {
  FixtureIpGuideAgentApi() : super(Dio());
  bool failPreferences = false;
  int preferenceRequests = 0;
  Future<void>? preferenceWait;
  Map<String, dynamic> preferenceCatalog = {
    'schemaVersion': 1,
    'steps': [
      for (final entry in {
        'contentDirections': [
          '校园',
          '情感',
          '成长',
          '职场',
          '家庭',
          '搞笑',
          '悬疑',
          '萌宠',
          '知识',
        ],
        'audienceFeelings': ['真实', '泪目', '治愈', '上头', '宿命感', '反转'],
        'presentationFormats': [
          'AI真人',
          '2D动漫',
          '3D动漫',
          '萌宠',
          '黏土定格',
          '国风水墨',
          '真人实拍',
        ],
        'targetAudience': ['学生群体', '职场人群', '亲子家庭', '二次元爱好者', '宠物爱好者', '银发人群'],
      }.entries)
        {
          'key': entry.key,
          'title': entry.key,
          'selectionMode': 'multiple',
          'allowCustom': true,
          'required': true,
          'maxSelections': 2,
          'maxNameBytes': entry.key == 'targetAudience' ? 2000 : 300,
          'options': [
            for (final name in entry.value)
              {'name': name, 'description': '来自接口的选项描述', 'imageUrl': null},
          ],
        },
    ],
  };

  @override
  Future<Map<String, dynamic>> preferenceOptions({
    CancelToken? cancelToken,
  }) async {
    preferenceRequests++;
    await preferenceWait;
    if (failPreferences) throw StateError('Preferences unavailable');
    return preferenceCatalog;
  }

  final requests = <Map<String, Object?>>[];
  bool fail = false;
  String bindingStatus = 'ready';
  Future<void>? wait;

  @override
  Future<Map<String, dynamic>> createHarnessSession({
    required String clientRequestId,
    required String title,
    required String kind,
    Map<String, Object?>? configuration,
    CancelToken? cancelToken,
  }) async {
    requests.add({
      'clientRequestId': clientRequestId,
      'title': title,
      'kind': kind,
      if (configuration != null) 'configuration': configuration,
    });
    await wait;
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    if (fail) throw StateError('Session binding unavailable');
    return {
      'id': 'created-session',
      'title': title,
      'revision': 1,
      'updatedAt': '2026-10-16T00:00:00Z',
      'bindingStatus': bindingStatus,
    };
  }
}
