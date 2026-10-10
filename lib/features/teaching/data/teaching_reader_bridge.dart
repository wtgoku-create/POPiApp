import 'dart:convert';

import '../domain/teaching.dart';

class TeachingHeading {
  const TeachingHeading({
    required this.id,
    required this.title,
    required this.level,
  });

  final String id;
  final String title;
  final int level;
}

class TeachingReaderEvent {
  const TeachingReaderEvent({
    required this.type,
    this.requestId,
    this.id,
    this.url,
    this.label = '',
    this.catalog = const [],
  });

  final String type;
  final String? requestId;
  final String? id;
  final Uri? url;
  final String label;
  final List<TeachingHeading> catalog;
}

/// Versioned messages are bound to one reader load and one document render.
class TeachingReaderBridge {
  TeachingReaderBridge({required Uri url, required this.session})
    : url = url.replace(
        queryParameters: {...url.queryParameters, 'bridgeSession': session},
        fragment: '',
      );

  static const version = 1;
  final Uri url;
  final String session;

  bool acceptsNavigation(Uri candidate) =>
      isWebUrl(candidate) && candidate.replace(fragment: '') == url;

  static bool isWebUrl(Uri uri) =>
      ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;

  TeachingReaderEvent? parseEvent(String message) {
    try {
      final value = jsonDecode(message);
      if (value is! Map ||
          value['version'] != version ||
          value['session'] != session) {
        return null;
      }
      final type = value['type'];
      if (type is! String ||
          !const {
            'ready',
            'rendered',
            'activeHeading',
            'previewImage',
            'openLink',
            'upgrade',
            'error',
          }.contains(type)) {
        return null;
      }
      final requestId = value['requestId'];
      final rawUrl = value['url'];
      final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
      if ((type == 'previewImage' || type == 'openLink') &&
          (uri == null || !isWebUrl(uri))) {
        return null;
      }
      final rawCatalog = value['catalog'];
      return TeachingReaderEvent(
        type: type,
        requestId: requestId is String ? requestId : null,
        id: value['id'] is String ? value['id'] as String : null,
        url: uri,
        label: value['label'] is String ? value['label'] as String : '',
        catalog: [
          if (rawCatalog is List)
            for (final item in rawCatalog.whereType<Map>())
              if (item['id'] is String &&
                  item['title'] is String &&
                  (item['level'] == 1 || item['level'] == 2))
                TeachingHeading(
                  id: item['id'] as String,
                  title: item['title'] as String,
                  level: (item['level'] as num).toInt(),
                ),
        ],
      );
    } on FormatException {
      return null;
    }
  }

  String renderScript({
    required String requestId,
    required TeachingDocument document,
    required TeachingCourse course,
    required String mediaBaseUrl,
    required String requiredMemberLevelName,
    required bool dark,
    required String locale,
    required double textScale,
  }) => _script({
    'type': 'render',
    'requestId': requestId,
    'payload': {
      'course': {
        'id': course.id,
        'name': course.name,
        'description': course.description,
      },
      'document': document.toReaderData(),
      'mediaBaseUrl': mediaBaseUrl,
      'requiredMemberLevelName': requiredMemberLevelName,
      'theme': dark ? 'dark' : 'light',
      'locale': locale.startsWith('en') ? 'en-US' : 'zh-CN',
      'textScale': textScale,
    },
  });

  String scrollToScript(String id) => _script({'type': 'scrollTo', 'id': id});

  String _script(Map<String, Object?> command) {
    final message = jsonEncode({
      ...command,
      'version': version,
      'session': session,
    });
    // Encode again as a JS string literal; document text cannot become executable code.
    return 'window.PopiTeachingReader.receive(JSON.parse(${jsonEncode(message)}));';
  }
}
