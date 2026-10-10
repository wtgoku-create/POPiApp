import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/h5/presentation/h5_page.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../domain/app_notification.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_scaffold.dart';

/// Full delivery content, including an optional media preview and destination.
class NotificationDetailPage extends ConsumerWidget {
  const NotificationDetailPage({
    required this.notification,
    required this.userId,
    super.key,
  });

  final AppNotification notification;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final title = notification.title.isEmpty
        ? l10n.notificationUntitled
        : notification.title;
    final target = notification.target;
    final authorized =
        ref.watch(userProvider.select((user) => user?.id)) == userId;
    return NotificationScaffold(
      title: l10n.notificationDetail,
      child: authorized
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                SelectableText(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notification.sentAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    notification.sentAt!
                        .toLocal()
                        .toIso8601String()
                        .substring(0, 16)
                        .replaceFirst('T', ' '),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (notification.content.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SelectableText(
                    notification.content,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ],
                if (notification.imageUrl case final String url) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    label: l10n.notificationViewImage,
                    child: GestureDetector(
                      onTap: () {
                        if (Uri.parse(
                          url,
                        ).path.toLowerCase().endsWith('.svg')) {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  H5Page(title: title, url: Uri.parse(url)),
                            ),
                          );
                        } else {
                          AppImagePreview.show(
                            context: context,
                            image: NetworkImage(url),
                            heroTag: 'notification-image-${notification.id}',
                            label: title,
                          );
                        }
                      },
                      child: NotificationImage(url: url),
                    ),
                  ),
                ],
                if (target != null) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('notification-detail-action'),
                      onPressed: () {
                        if (target.location case final String location) {
                          context.push(location);
                        } else if (target.url case final Uri url) {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => H5Page(title: title, url: url),
                            ),
                          );
                        }
                      },
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(l10n.notificationLearnMore),
                    ),
                  ),
                ],
              ],
            )
          : Center(child: Text(l10n.notificationLoginRequired)),
    );
  }
}
