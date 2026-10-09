import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/network_api.dart';
import '../../../core/storage/preferences_storage.dart';
import '../domain/ip_guide_draft.dart';

/// Serializes writes so an older autosave cannot resurrect a cleared draft.
class IpGuideRepository {
  IpGuideRepository(this._storage, this._api, {required String? userId})
    : _key = 'ip_guide_draft_v1:${userId ?? 'guest'}';

  final PreferencesStorage _storage;
  final NetworkApi _api;
  final String _key;
  Future<void>? _writes;
  final _creationToken = CancelToken();

  void dispose() => _creationToken.cancel();

  void _checkActive() {
    if (_creationToken.isCancelled) throw _creationToken.cancelError!;
  }

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
      draft.step = (json['step'] as int? ?? 1).clamp(1, 5);
      draft.creationRequestId = json['creationRequestId'] as String?;
      draft.profileRequestId = json['profileRequestId'] as String?;
      draft.accountId = json['accountId'] as String?;
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
      'creationRequestId': draft.creationRequestId,
      'profileRequestId': draft.profileRequestId,
      'accountId': draft.accountId,
      'accountRevision': draft.accountRevision,
      'submittedProfile': draft.submittedProfile,
    });
    return _enqueue(() => _storage.setString(_key, snapshot));
  }

  Future<void> clear() => _enqueue(() => _storage.remove(_key));

  /// Persist retry identifiers before sending either creation command.
  Future<String> create(
    IpGuideDraft draft,
    Map<String, Object?> profile,
  ) async {
    _checkActive();
    draft.creationRequestId ??= const Uuid().v4();
    draft.profileRequestId ??= const Uuid().v4();
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
      profile: draft.submittedProfile!,
      cancelToken: _creationToken,
    );
    _checkActive();
    await clear();
    return draft.accountId!;
  }

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
