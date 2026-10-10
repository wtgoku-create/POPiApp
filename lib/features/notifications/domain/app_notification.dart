/// A notification target resolved to an app route or a public web page.
class NotificationTarget {
  const NotificationTarget.page(String route) : location = route, url = null;
  const NotificationTarget.web(Uri uri) : location = null, url = uri;

  final String? location;
  final Uri? url;
}

/// A delivery in the signed-in user's notification inbox.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.content,
    required this.isUnread,
    this.sentAt,
    this.imageUrl,
    this.target,
  });

  final int id;
  final String title;
  final String content;
  final bool isUnread;
  final DateTime? sentAt;
  final String? imageUrl;
  final NotificationTarget? target;

  AppNotification asRead() => AppNotification(
    id: id,
    title: title,
    content: content,
    isUnread: false,
    sentAt: sentAt,
    imageUrl: imageUrl,
    target: target,
  );
}

class NotificationListPage {
  const NotificationListPage({required this.items, required this.hasMore});

  final List<AppNotification> items;
  final bool hasMore;
}
