import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/network_agent_api.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../ip_accounts/domain/account_preferences.dart';
import '../../session/domain/conversation_session.dart';
import '../domain/ip_guide_draft.dart';

/// Creates one standalone session with a per-user resumable draft.
class IpGuideRepository {
  IpGuideRepository(this._storage, this._agent, {required String? userId})
    : _key = 'ip_guide_draft_v1:${userId ?? 'guest'}';

  final PreferencesStorage _storage;
  final String _key;
  Future<void>? _writes;

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
          final selection = IpGuideSelection<String>(combineCustom: true);
          final names = (value['values'] as List).cast<String>();
          for (final name in names) {
            selection.toggle(name, maxSelections: names.length);
          }
          selection.customText = value['customText'] as String? ?? '';
          draft.preferences[entry.key] = selection;
        }
      }
      draft.step = (json['step'] as int? ?? 1).clamp(1, 5);
      draft.submittedSession =
          (json['submittedSession'] as Map<String, dynamic>?)
              ?.cast<String, Object?>();
      // Legacy account creation used a different session payload and request ID.
      if (json['creationRequestId'] == null) {
        draft.sessionRequestId = json['sessionRequestId'] as String?;
        draft.sessionId = json['sessionId'] as String?;
      }
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
      'sessionRequestId': draft.sessionRequestId,
      'sessionId': draft.sessionId,
      'submittedSession': draft.submittedSession,
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

  final NetworkAgentApi _agent;
  final _creationToken = CancelToken();

  void dispose() => _creationToken.cancel();

  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  }) async {
    return AccountPreferenceStep.parseCatalog(
      await _agent.preferenceOptions(cancelToken: cancelToken),
    );
  }

  void _checkActive() {
    if (_creationToken.isCancelled) throw _creationToken.cancelError!;
  }

  /// Freeze the payload before sending so retries cannot conflict with the ID.
  Future<String> create(
    IpGuideDraft draft,
    Map<String, Object?> profile,
  ) async {
    _checkActive();
    draft.submittedSession ??= _sessionInput(draft.nickname, profile);
    draft.sessionRequestId ??= const Uuid().v4();
    await save(draft);
    _checkActive();
    if (draft.sessionId == null) {
      final input = draft.submittedSession!;
      final session = ConversationSession.fromJson(
        await _agent.createHarnessSession(
          clientRequestId: draft.sessionRequestId!,
          title: input['title'] as String,
          kind: input['kind'] as String,
          configuration: Map<String, Object?>.from(
            input['configuration'] as Map,
          ),
          cancelToken: _creationToken,
        ),
      );
      _checkActive();
      if (session.bindingStatus != 'ready') {
        throw const FormatException('Session is not ready');
      }
      draft.sessionId = session.id;
      await save(draft);
    }
    _checkActive();
    await clear();
    return draft.sessionId!;
  }

  Map<String, Object?> _sessionInput(
    String title,
    Map<String, Object?> profile,
  ) {
    final name = title.trim();
    if (name.isEmpty || name.length > 120) {
      throw const FormatException('Invalid session title');
    }
    String text(String key) {
      final values = (profile[key] as List? ?? const []).cast<String>();
      return AccountPreferenceStep.composeText(values);
    }

    return {
      'title': name,
      'kind': 'project',
      'configuration': {
        'members': ['popi'],
        'capabilities': [
          'character',
          'script',
          'image',
          'video',
          'audio',
          'vision',
        ],
        'direction': text('contentDirections'),
        'accountPreferences': {
          'feeling': text('audienceFeelings'),
          'format': text('presentationFormats'),
          'audience': text('targetAudience'),
        },
      },
    };
  }
}
