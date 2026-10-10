import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/type/notification_type.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/app_notification.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.type,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final NotificationType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final personal = type == NotificationType.personal;
    final title = notification.title.isEmpty
        ? l10n.notificationUntitled
        : notification.title;
    final time = notificationTime(notification, type, l10n);
    final radius = BorderRadius.circular(AppRadii.card);
    return Material(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white.withValues(alpha: .5)
          : scheme.surfaceContainerLow,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 133),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actionBelow =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.2;
                final showAction = notification.isUnread;
                Widget action() => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (personal && notification.target != null)
                      Text(
                        l10n.notificationLearnMore,
                        style: TextStyle(fontSize: 14, color: scheme.primary),
                      ),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: AppSvgIcon.asset(
                          'ip_account_chevron',
                          size: 12,
                          color: personal && notification.target != null
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (notification.isUnread) ...[
                                const SizedBox(width: 5),
                                Semantics(
                                  label: l10n.notificationUnread,
                                  child: ExcludeSemantics(
                                    child: Container(
                                      key: ValueKey(
                                        'notification-new-${notification.id}',
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 55,
                                        minHeight: 20,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(
                                          alpha: .05,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                      ),
                                      child: Text(
                                        l10n.notificationNew,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.3,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showAction && !actionBelow) ...[
                          const SizedBox(width: 8),
                          action(),
                        ],
                      ],
                    ),
                    if (notification.content.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        notification.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.45),
                      ),
                    ],
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (notification.imageUrl != null) ...[
                      const SizedBox(height: 12),
                      NotificationImage(url: notification.imageUrl!),
                    ],
                    if (showAction && actionBelow) ...[
                      const SizedBox(height: 5),
                      Align(alignment: Alignment.centerRight, child: action()),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps inbox thumbnails stable while the remote image loads.
class NotificationImage extends StatelessWidget {
  const NotificationImage({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Uri.parse(url).path.toLowerCase().endsWith('.svg')
        ? AppSvgIcon.network(url)
        : Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
            errorBuilder: (context, _, __) => Center(
              child: Text(
                AppLocalizations.of(context)!.notificationImageFailed,
              ),
            ),
          ),
  );
}

String notificationTime(
  AppNotification item,
  NotificationType type,
  AppLocalizations l10n,
) {
  final sentAt = item.sentAt?.toLocal();
  if (sentAt == null) return '';
  final days = DateTime.now().difference(sentAt).inDays;
  if (type == NotificationType.system &&
      !item.isUnread &&
      days > 0 &&
      days <= 30) {
    return l10n.notificationDaysAgo(days);
  }
  return sentAt.toIso8601String().substring(0, 10);
}
