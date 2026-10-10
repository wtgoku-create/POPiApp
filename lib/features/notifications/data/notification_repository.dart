import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../../../shared/type/notification_type.dart';
import '../domain/app_notification.dart';

/// Adapts the web inbox contracts and resolves media and navigation targets.
class NotificationRepository {
  const NotificationRepository(this.api);

  final NetworkApi api;

  Future<NotificationListPage> fetchNotifications(
    NotificationType type, {
    required int page,
    int pageSize = 20,
  }) async {
    final data = await api.notifications(
      messageType: type.name,
      page: page,
      pageSize: pageSize,
    );
    final raw = data['list'];
    if (raw is! List) throw const ApiException();
    final items = <AppNotification>[];
    final now = DateTime.now();
    for (final record in raw.whereType<Map>()) {
      final item = Map<String, Object?>.from(record);
      final id = _integer(item['id']);
      final expiresAt = DateTime.tryParse(_text(item['expireTime']));
      if (id <= 0 ||
          item['deleted'] == true ||
          item['userDeleted'] == true ||
          (expiresAt != null && !expiresAt.isAfter(now))) {
        continue;
      }
      final content = _text(item['content']);
      final image = _image(item, content);
      items.add(
        AppNotification(
          id: id,
          title: _text(item['title']),
          content: content
              .replaceAllMapped(
                _contentUrls,
                (match) => _isImage(match[0]!) ? '' : match[0]!,
              )
              .trim(),
          isUnread: _integer(item['readStatus']) == 0,
          sentAt:
              DateTime.tryParse(_text(item['sendTime'])) ??
              DateTime.tryParse(_text(item['createTime'])),
          imageUrl: image,
          target: _target(_text(item['linkType']), _text(item['linkValue'])),
        ),
      );
    }
    final info = data['pageInfo'];
    final count = info is Map ? _integer(info['pageCount']) : 0;
    final total = info is Map ? _integer(info['total']) : 0;
    return NotificationListPage(
      items: items,
      hasMore:
          raw.isNotEmpty &&
          (count > 0
              ? page < count
              : total > 0
              ? page * pageSize < total
              : raw.length >= pageSize),
    );
  }

  Future<void> markRead(int id) {
    if (id <= 0) throw ArgumentError.value(id, 'id');
    return api.readNotification(id);
  }

  NotificationTarget? _target(String type, String value) {
    if (value.isEmpty) return null;
    switch (type.toLowerCase()) {
      case 'page':
        final path = value.startsWith('#/') ? value.substring(1) : value;
        if (Uri.tryParse(path)?.hasScheme != false) return null;
        final uri = Uri.tryParse(path.startsWith('/') ? path : '/$path');
        if (uri == null || uri.hasAuthority) return null;
        final location = switch (uri.path) {
          '/subscribe' => '/profile/membership',
          '/create' => '/session',
          '/profile' ||
          '/profile/membership' ||
          '/profile/points' ||
          '/profile/redemption' ||
          '/teaching' ||
          '/assets' ||
          '/session' => uri.path,
          _ => null,
        };
        if (location != null) {
          return NotificationTarget.page(
            uri.replace(path: location).toString(),
          );
        }
        // Web-only destinations remain available in the existing H5 browser.
        final url = _webUrl(path, relative: true);
        return url == null ? null : NotificationTarget.web(url);
      case 'url':
        final url = _webUrl(value);
        return url == null ? null : NotificationTarget.web(url);
      default:
        return null;
    }
  }

  String? _image(Map<String, Object?> item, String content) {
    final images = item['imageUrls'];
    final candidates = [
      if (images is List) ...images.map(_text),
      _text(item['linkValue']),
      ..._contentUrls.allMatches(content).map((match) => match[0]!),
    ];
    for (final candidate in candidates) {
      if (!_isImage(candidate)) continue;
      final url = _webUrl(candidate, relative: true);
      if (url != null) return url.toString();
    }
    return null;
  }

  Uri? _webUrl(String value, {bool relative = false}) {
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final Uri resolved;
    if (uri.hasScheme) {
      resolved = uri;
    } else if (relative || value.startsWith('/')) {
      resolved = Uri.parse(api.mediaBaseUrl).resolveUri(uri);
    } else {
      resolved = Uri.parse('https://$value');
    }
    return (resolved.scheme == 'https' || resolved.scheme == 'http') &&
            resolved.host.isNotEmpty
        ? resolved
        : null;
  }
}

final _contentUrls = RegExp(r'''https?://[^\s<>"']+''');
final _imageExtension = RegExp(
  r'\.(avif|bmp|gif|jpe?g|png|svg|webp)$',
  caseSensitive: false,
);

bool _isImage(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && _imageExtension.hasMatch(uri.path);
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

String _text(Object? value) => value?.toString().trim() ?? '';
