import 'dart:async';

import 'package:dio/dio.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_repository.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account_home.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/account_preferences.dart';

class FixtureIpAccountRepository extends IpAccountRepository {
  FixtureIpAccountRepository() : super(NetworkApi(Dio()));
  bool failDetail = false;
  bool failSave = false;
  bool failResources = false;
  Completer<IpAccountHome>? pendingDetail;
  final saveRequestIds = <String>[];
  final renameRequestIds = <String>[];
  final renameRevisions = <int>[];
  final statuses = <String>[];
  final createRequestIds = <String>[];
  String status = 'active';
  String title = '后来才懂';
  Map<String, Object?> profile = {
    'contentDirection': '校园情感',
    'audienceFeeling': '真实 / 泪目',
    'presentation': 'AI真人',
    'contentFormat': '剧情短片',
    'targetAudience': '学生群体 x 职场人群',
    'positioning': '青春里的陪伴与成长',
    'preserved': {'enabled': true},
  };
  List<String> residents = [];
  List<IpAccountCreation> creations = const [
    IpAccountCreation(id: 'work', title: '校园野餐', sessionId: 'work-session'),
  ];

  @override
  Future<List<IpAccount>> list({
    String status = 'active',
    CancelToken? cancelToken,
  }) async {
    statuses.add(status);
    return [
      if (status == 'all' || status == this.status)
        IpAccount(
          id: '42',
          title: title,
          description: '校园情感 x AI真人',
          isPaused: this.status == 'archived',
        ),
    ];
  }

  @override
  Future<String> create({
    required String requestId,
    String? title,
    Map<String, Object?>? preferences,
    String? userPrompt,
    CancelToken? cancelToken,
  }) async {
    createRequestIds.add(requestId);
    if (failSave) throw StateError('Failed');
    if (title != null) this.title = title;
    this.preferences = preferences ?? {};
    return '42';
  }

  @override
  Future<void> archive(String id, {CancelToken? cancelToken}) async {
    if (failSave) throw StateError('Failed');
    status = 'archived';
  }

  @override
  Future<void> restore(String id, {CancelToken? cancelToken}) async {
    if (failSave) throw StateError('Failed');
    status = 'active';
  }

  @override
  Future<IpAccountHome> detail(String id, {CancelToken? cancelToken}) async {
    if (failDetail) throw StateError('Failed');
    if (pendingDetail != null) return pendingDetail!.future;
    return IpAccountHome(
      id: id,
      title: title,
      revision: 7,
      status: status,
      profile: profile,
      preferences: {
        'contentDirections': [profile['contentDirection']!],
        'audienceFeelings': [profile['audienceFeeling']!],
        'presentationFormats': [profile['presentation']!],
        'targetAudience': [profile['targetAudience']!],
        ...preferences,
      },
      userPrompt: profile['positioning'] as String,
      residentRoles: [
        for (final id in residents) {'roleId': int.parse(id)},
      ],
    );
  }

  Map<String, Object?> preferences = {};
  @override
  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  }) async => const [
    AccountPreferenceStep(
      key: 'contentDirections',
      title: '内容方向',
      options: [AccountPreferenceOption(name: '校园')],
    ),
    AccountPreferenceStep(key: 'audienceFeelings', title: '观众感受'),
    AccountPreferenceStep(key: 'presentationFormats', title: '表达形式'),
    AccountPreferenceStep(
      key: 'targetAudience',
      title: '目标受众',
      maxNameBytes: 2000,
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
    saveRequestIds.add('patch');
    if (failSave) throw StateError('Failed');
    if (title != null) this.title = title;
    this.preferences = {...this.preferences, ...?preferences};
    if (userPrompt != null) profile['positioning'] = userPrompt;
  }

  @override
  Future<AccountArchivePage> archives(
    String id, {
    String keyword = '',
    int page = 1,
    CancelToken? cancelToken,
  }) async => AccountArchivePage(
    items: creations.where((c) => c.title.contains(keyword)).toList(),
    page: page,
    pageCount: 1,
    total: creations.length,
  );

  @override
  Future<IpAccountResources> resources(
    IpAccountHome account, {
    CancelToken? cancelToken,
  }) async {
    if (failResources) throw StateError('Failed');
    return IpAccountResources(
      creations: creations,
      roles: [
        for (final id in residents)
          LibraryRole(id: id, title: '角色$id', description: '', canCreate: true),
      ],
    );
  }

  @override
  Future<void> saveProfile(
    IpAccountHome account,
    Map<String, Object?> changes, {
    required String requestId,
    CancelToken? cancelToken,
  }) async {
    saveRequestIds.add(requestId);
    if (failSave) throw StateError('Failed');
    profile = {...account.profile, ...changes};
  }

  @override
  Future<void> rename(
    String id,
    String title, {
    required int revision,
    required String requestId,
    CancelToken? cancelToken,
  }) async {
    renameRequestIds.add(requestId);
    renameRevisions.add(revision);
    if (failSave) throw StateError('Failed');
    this.title = title;
  }

  @override
  Future<List<LibraryRole>> availableRoles(
    String category, {
    CancelToken? cancelToken,
  }) async => const [
    LibraryRole(id: '20', title: '角色20', description: '角色简介', canCreate: true),
  ];

  @override
  Future<void> saveRoles(
    IpAccountHome account,
    List<String> roleIds, {
    required String requestId,
    CancelToken? cancelToken,
  }) async {
    if (failSave) throw StateError('Failed');
    residents = roleIds;
  }
}
