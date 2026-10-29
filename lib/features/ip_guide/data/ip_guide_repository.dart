import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/network_api.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../ip_accounts/data/ip_account_repository.dart';
import '../../ip_accounts/domain/account_preferences.dart';
import '../../session/domain/conversation_session.dart';
import '../domain/ip_guide_draft.dart';

/// Shared draft persistence for account creation and first-use session setup.
abstract class IpGuideDraftRepository {
  IpGuideDraftRepository(
    PreferencesStorage storage, {
    required String? userId,
    String namespace = 'ip_guide_draft_v1',
  }) : _storage = storage,
       _key = '$namespace:${userId ?? 'guest'}';

  final PreferencesStorage _storage;
  final String _key;
  Future<void>? _writes;

  void dispose() {}

  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  });

  Future<String> create(IpGuideDraft draft, Map<String, Object?> profile);

  IpGuideDraft? load() {
    final raw = _storage.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) return null;
      final draft = IpGuideDraft();
      _restore(draft.directions, IpContentDirection.values, json['directions']);
      _restore(draft.feelings, IpAudienceFeeling.values, json['feelings']);
      _restore(draft.audience, IpTargetAudience.values, json['audience']);
      draft.presentation = _enum(IpPresentation.values, json['presentation']);
      draft.format =
          _enum(IpContentFormat.values, json['format']) ??
          IpContentFormat.shortFilm;
      draft.customFormat = json['customFormat'] as String? ?? '';
      draft.nickname = json['nickname'] as String? ?? '';
      final preferences = json['preferences'] as Map<String, dynamic>?;
      if (preferences != null) {
        for (final entry in preferences.entries) {
          final value = entry.value as Map<String, dynamic>;
          final selection = IpGuideSelection<String>();
          final names = (value['values'] as List).cast<String>();
          for (final name in names) {
            selection.toggle(name, maxSelections: names.length);
          }
          selection.customText = value['customText'] as String? ?? '';
          draft.preferences[entry.key] = selection;
        }
      }
      draft.step = (json['step'] as int? ?? 1).clamp(1, 5);
      draft.creationRequestId = json['creationRequestId'] as String?;
      draft.profileRequestId = json['profileRequestId'] as String?;
      draft.sessionRequestId = json['sessionRequestId'] as String?;
      draft.accountId = json['accountId'] as String?;
      draft.sessionId = json['sessionId'] as String?;
      draft.accountRevision = json['accountRevision'] as int?;
      draft.submittedProfile =
          (json['submittedProfile'] as Map<String, dynamic>?)
              ?.cast<String, Object?>();
      if (draft.submitted) draft.step = 5;
      return draft;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(IpGuideDraft draft) {
    final snapshot = jsonEncode({
      'version': 1,
      'step': draft.step,
      'directions': _selection(draft.directions),
      'feelings': _selection(draft.feelings),
      'audience': _selection(draft.audience),
      'presentation': draft.presentation?.name,
      'format': draft.format.name,
      'customFormat': draft.customFormat,
      'nickname': draft.nickname,
      'preferences': {
        for (final entry in draft.preferences.entries)
          entry.key: {
            'values': entry.value.values,
            'customText': entry.value.customText,
          },
      },
      'creationRequestId': draft.creationRequestId,
      'profileRequestId': draft.profileRequestId,
      'sessionRequestId': draft.sessionRequestId,
      'accountId': draft.accountId,
      'sessionId': draft.sessionId,
      'accountRevision': draft.accountRevision,
      'submittedProfile': draft.submittedProfile,
    });
    return _enqueue(() => _storage.setString(_key, snapshot));
  }

  Future<void> clear() => _enqueue(() => _storage.remove(_key));

  Future<void> _enqueue(Future<void> Function() write) {
    final result = _writes?.then((_) => write()) ?? write();
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Map<String, Object?> _selection<T extends Enum>(IpGuideSelection<T> value) =>
      {
        'values': value.values.map((item) => item.name).toList(),
        'customText': value.customText,
      };

  void _restore<T extends Enum>(
    IpGuideSelection<T> selection,
    List<T> options,
    Object? value,
  ) {
    if (value is! Map<String, dynamic>) return;
    for (final name in (value['values'] as List? ?? const [])) {
      final item = _enum(options, name);
      if (item != null && !selection.values.contains(item)) {
        selection.toggle(item);
      }
    }
    selection.customText = value['customText'] as String? ?? '';
  }

  T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// Creates the production account and binds its main session.
class IpGuideRepository extends IpGuideDraftRepository {
  IpGuideRepository(
    super.storage,
    this._api,
    this._agent, {
    required super.userId,
  });

  final NetworkApi _api;
  final NetworkAgentApi _agent;
  final _creationToken = CancelToken();

  @override
  void dispose() => _creationToken.cancel();

  @override
  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  }) => IpAccountRepository(_api).preferenceOptions(cancelToken: cancelToken);

  void _checkActive() {
    if (_creationToken.isCancelled) throw _creationToken.cancelError!;
  }

  /// Account creation completes only after its main session is bound.
  @override
  Future<String> create(
    IpGuideDraft draft,
    Map<String, Object?> profile,
  ) async {
    _checkActive();
    draft.creationRequestId ??= const Uuid().v4();
    draft.profileRequestId ??= const Uuid().v4();
    draft.sessionRequestId ??= const Uuid().v4();
    draft.submittedProfile ??= profile;
    await save(draft);
    _checkActive();
    if (draft.accountId == null) {
      final account = await _api.createIpAccount(
        title: draft.nickname.trim(),
        clientRequestId: draft.creationRequestId!,
        cancelToken: _creationToken,
      );
      draft.accountId = account.$1;
      draft.accountRevision = account.$2;
      await save(draft);
    }
    _checkActive();
    await _api.saveIpAccountProfile(
      draft.accountId!,
      revision: draft.accountRevision!,
      clientRequestId: draft.profileRequestId!,
      profile: _preferences(draft.submittedProfile!),
      cancelToken: _creationToken,
    );
    _checkActive();
    if (draft.sessionId == null) {
      final session = ConversationSession.fromJson(
        await _agent.createProjectSession(
          draft.accountId!,
          draft.nickname.trim(),
          clientRequestId: draft.sessionRequestId!,
          cancelToken: _creationToken,
        ),
      );
      _checkActive();
      if (session.bindingStatus != 'ready') {
        throw const FormatException('Account session is not bound');
      }
      draft.sessionId = session.id;
      await save(draft);
    }
    _checkActive();
    await clear();
    return draft.accountId!;
  }

  // Drafts persisted before the account API migration contain singular fields.
  Map<String, Object?> _preferences(Map<String, Object?> profile) {
    const aliases = {
      'contentDirection': 'contentDirections',
      'audienceFeeling': 'audienceFeelings',
      'presentation': 'presentationFormats',
      'contentFormat': 'creativeConstraints',
    };
    return {
      for (final entry in profile.entries)
        aliases[entry.key] ?? entry.key: entry.value is String
            ? [(entry.value as String)]
            : entry.value,
    };
  }
}
