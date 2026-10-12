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
  bool failPreferences = false;
  int preferenceRequests = 0;
  Future<void>? preferenceWait;
  Map<String, dynamic> preferenceCatalog = {
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
          'maxNameBytes': 300,
          'options': [
            for (final name in entry.value)
              {'name': name, 'description': '来自接口的选项描述', 'imageUrl': null},
          ],
        },
    ],
  };

  @override
  Future<Map<String, dynamic>> ipAccountPreferenceOptions({
    CancelToken? cancelToken,
  }) async {
    preferenceRequests++;
    await preferenceWait;
    if (failPreferences) throw StateError('Preferences unavailable');
    return preferenceCatalog;
  }

  @override
  Future<(String, int)> createIpAccount({
    String? title,
    Map<String, Object?>? preferences,
    String? userPrompt,
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
