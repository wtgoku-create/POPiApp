import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/demo_models.dart';
import '../demo_assistant_display.dart';
import '../demo_session_list_presentation.dart';
import 'demo_activity_indicator.dart';
import 'demo_widgets.dart';

/// A conversation row shared by the mobile inbox and expanded desktop sidebar.
class DemoConversationListItem extends StatelessWidget {
  const DemoConversationListItem({
    required this.session,
    required this.onTap,
    this.dense = false,
    this.selected = false,
    super.key,
  });

  final DemoSession session;
  final VoidCallback onTap;
  final bool dense;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final presentation = DemoSessionListPresentation.fromSession(session, l);
    final displayName = demoSessionDisplayName(l, session);
    final activeMessage = presentation.activeMessage;
    final avatarSize = dense ? 40.0 : 52.0;
    final titleSize = dense ? 14.0 : 17.0;
    final summarySize = dense ? 13.0 : 15.0;
    final timeSize = dense ? 11.0 : 12.0;
    final rowPadding = dense
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
        : const EdgeInsets.symmetric(horizontal: 4, vertical: 14);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      selected: selected,
      label: displayName,
      onTap: onTap,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(dense ? 12 : 20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: onTap,
          child: Padding(
            padding: rowPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DemoAvatar(
                  members: session.members,
                  size: avatarSize,
                  memberAvatars: session.memberAvatars,
                  memberColors: session.memberColors,
                ),
                SizedBox(width: dense ? 10 : 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: dense ? 1 : 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ExcludeSemantics(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            if (presentation.timeLabel.isNotEmpty) ...[
                              SizedBox(width: dense ? 6 : 12),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: dense ? 52 : 76,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    presentation.timeLabel,
                                    key: ValueKey(
                                      'demo-session-time-${session.id}',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: timeSize,
                                      height: 1.25,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: dense ? 3 : 6),
                        Text(
                          presentation.summary,
                          key: ValueKey('demo-session-summary-${session.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: summarySize,
                            height: 1.3,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (activeMessage?.activity case final activity?) ...[
                          SizedBox(height: dense ? 4 : 7),
                          DefaultTextStyle.merge(
                            style: TextStyle(fontSize: dense ? 12 : 14),
                            child: DemoActivityIndicator(
                              key: ValueKey(
                                'demo-session-activity-${session.id}',
                              ),
                              activity: activity,
                              memberName: presentation.activityMemberName,
                              avatar: TickerMode(
                                enabled: activity.status == 'running',
                                child: DemoAvatar(
                                  members: [presentation.activityMemberId],
                                  size: dense ? 18 : 22,
                                  memberAvatars: session.memberAvatars,
                                  memberColors: session.memberColors,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
