import '../../../l10n/generated/app_localizations.dart';
import '../domain/demo_models.dart';
import 'demo_assistant_display.dart';

/// The same server-backed preview and clock labels for mobile and desktop lists.
class DemoSessionListPresentation {
  const DemoSessionListPresentation._({
    required this.summary,
    required this.timeLabel,
    required this.activeMessage,
    required this.activityMemberId,
    required this.activityMemberName,
  });

  final String summary;
  final String timeLabel;
  final DemoMessage? activeMessage;
  final String activityMemberId;
  final String activityMemberName;

  factory DemoSessionListPresentation.fromSession(
    DemoSession session,
    AppLocalizations l10n, {
    DateTime? now,
  }) {
    final preview = session.messages.reversed.where((message) {
      return message.status != 'skipped' &&
          (message.text.trim().isNotEmpty ||
              message.assetIds.isNotEmpty ||
              message.question != null);
    }).firstOrNull;
    final activity = _activeMessage(session);
    final latest = session.messages.reversed
        .where((message) => message.status != 'skipped')
        .firstOrNull;
    final activityMember = _memberId(session, activity, active: true);
    final previewText = preview == null
        ? ''
        : preview.text.trim().isNotEmpty
        ? preview.text.replaceAll(RegExp(r'\s+'), ' ').trim()
        : preview.question != null
        ? preview.question!.title.trim().isNotEmpty
              ? preview.question!.title.trim()
              : l10n.demoListQuestion
        : l10n.demoListAttachment;
    final sender = preview?.user == true
        ? l10n.demoListYou
        : _memberName(session, preview, l10n);
    return DemoSessionListPresentation._(
      summary: preview == null
          ? l10n.demoListNoMessages
          : l10n.demoListMessagePreview(sender, previewText),
      timeLabel: _timeLabel(
        latest?.createdAt ?? session.updatedAt,
        session.time,
        l10n,
        now ?? DateTime.now(),
      ),
      activeMessage: activity,
      activityMemberId: activityMember,
      activityMemberName: _memberName(session, activity, l10n, active: true),
    );
  }

  static DemoMessage? _activeMessage(DemoSession session) {
    for (final message in session.messages.reversed) {
      if (message.user ||
          const {
            'skipped',
            'failed',
            'stopped',
            'interrupted',
          }.contains(message.status)) {
        continue;
      }
      if (message.activity?.isActive == true) return message;
    }
    // Media workers can continue after the assistant's text reply completes.
    final job = session.mediaJobs.where((job) {
      return job.isPending &&
          !const {
            'failed',
            'error',
            'unknown',
            'canceled',
            'cancelled',
            'stopped',
          }.contains(job.state);
    }).firstOrNull;
    if (job == null) return null;
    final source = session.messages.reversed.where((message) {
      return !message.user &&
          message.runId == job.runId &&
          (job.memberId.isEmpty || message.memberId == job.memberId);
    }).firstOrNull;
    final operation = job.operation.toLowerCase();
    final kind = operation.contains('image')
        ? 'image'
        : operation.contains('video')
        ? 'video'
        : const ['audio', 'tts', 'music', 'speech'].any(operation.contains)
        ? 'audio'
        : 'tool';
    return DemoMessage(
      id: 'list-media-${job.jobId}',
      text: '',
      memberId: job.memberId.isNotEmpty ? job.memberId : source?.memberId ?? '',
      memberName: source?.memberName ?? '',
      runId: job.runId,
      activity: DemoActivity(kind: kind, status: 'running'),
    );
  }

  static String _memberId(
    DemoSession session,
    DemoMessage? message, {
    bool active = false,
  }) {
    final id = message?.memberId.trim() ?? '';
    if (id.isNotEmpty) return id;
    if (session.members.length == 1) return session.members.single;
    if (!active) return 'popi';
    return session.members.contains(session.activeMemberId)
        ? session.activeMemberId
        : session.members.firstOrNull ?? 'popi';
  }

  static String _memberName(
    DemoSession session,
    DemoMessage? message,
    AppLocalizations l10n, {
    bool active = false,
  }) {
    final id = _memberId(session, message, active: active);
    return demoSessionMemberName(
      l10n,
      session,
      id,
      snapshotName: message?.memberName,
    );
  }

  static String _timeLabel(
    DateTime? timestamp,
    String legacyLabel,
    AppLocalizations l10n,
    DateTime now,
  ) {
    if (timestamp == null) return legacyLabel;
    final local = timestamp.toLocal();
    final today = now.toLocal();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (sameDay(local, today)) return l10n.demoListTime(local);
    if (sameDay(local, DateTime(today.year, today.month, today.day - 1))) {
      return l10n.yesterday;
    }
    return local.year == today.year
        ? l10n.demoListDate(local)
        : l10n.demoListFullDate(local);
  }
}
