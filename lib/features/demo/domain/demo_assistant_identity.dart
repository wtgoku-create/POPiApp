import 'demo_models.dart';

/// Resolves a Bot's user-given name without confusing it with the POPi category.
abstract final class DemoAssistantIdentity {
  static const _genericNames = {
    '',
    'popi',
    '新会话',
    '新建会话',
    'new conversation',
    'new chat',
    'session',
  };

  static String primaryMemberId(DemoSession session) {
    if (session.members.contains(session.activeMemberId)) {
      return session.activeMemberId;
    }
    return session.members.firstOrNull ?? 'popi';
  }

  static String? givenName(
    DemoSession session,
    String memberId, {
    String? snapshotName,
  }) {
    final configured = _custom(session.memberNames[memberId]);
    if (configured != null) return configured;
    if (session.members.length == 1 && session.members.single == memberId) {
      final legacyTitle = _custom(session.title);
      if (legacyTitle != null) return legacyTitle;
    }
    final explicitSnapshot = _snapshotName(snapshotName, memberId);
    if (explicitSnapshot != null) return explicitSnapshot;
    return session.messages.reversed
        .where((message) => message.memberId == memberId)
        .map((message) => _snapshotName(message.memberName, memberId))
        .whereType<String>()
        .firstOrNull;
  }

  static String? singleName(DemoSession session) {
    if (session.members.length != 1) return null;
    final memberId = session.members.single;
    return givenName(session, memberId);
  }

  static String? _custom(String? value) {
    final trimmed = value?.trim() ?? '';
    return _genericNames.contains(trimmed.toLowerCase()) ? null : trimmed;
  }

  static String? _snapshotName(String? value, String memberId) {
    final custom = _custom(value);
    return custom == memberId ? null : custom;
  }
}
