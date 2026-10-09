/// A completed image/video result nested inside a creation task.
class LibraryWork {
  const LibraryWork({
    required this.id,
    required this.previewUrl,
    required this.isVideo,
    required this.createdAt,
    this.videoUrl = '',
  });

  final String id;
  final String previewUrl;
  final bool isVideo;
  final String videoUrl;
  final DateTime? createdAt;
}

class LibraryWorkPage {
  const LibraryWorkPage({required this.items, required this.hasMore});

  final List<LibraryWork> items;
  final bool hasMore;

  factory LibraryWorkPage.fromJson(
    Map<String, Object?> json, {
    required int page,
    required int pageSize,
    required String mediaBaseUrl,
  }) {
    final tasks = json['list'];
    if (tasks is! List) throw const FormatException('Invalid work list');
    final items = <LibraryWork>[];
    for (final task in tasks) {
      if (task is! Map) throw const FormatException('Invalid work task');
      if (_integer(task['status']) != 2) continue;
      final type = _integer(task['type']);
      if (type != 1 && type != 2) continue;
      final results = task['resultList'];
      if (results is! List) continue;
      for (final result in results) {
        if (result is! Map) continue;
        final id = _text(result['id'] ?? result['assetId']);
        final video = _text(result['video']);
        final images = result['images'];
        final image = images is List && images.isNotEmpty
            ? _text(images.first)
            : '';
        if (id.isEmpty || (video.isEmpty && image.isEmpty)) continue;
        final cover = _text(result['cover'] ?? result['coverThumb']);
        items.add(
          LibraryWork(
            id: id,
            previewUrl: _mediaUrl(
              video.isNotEmpty && cover.isNotEmpty ? cover : image,
              mediaBaseUrl,
            ),
            isVideo: video.isNotEmpty,
            videoUrl: _mediaUrl(video, mediaBaseUrl),
            createdAt: _date(task['createTime']),
          ),
        );
      }
    }
    final info = json['pageInfo'];
    final pageCount = info is Map ? _integer(info['pageCount']) : null;
    return LibraryWorkPage(
      items: List.unmodifiable(items),
      // Page size counts tasks, including tasks without displayable results.
      hasMore:
          tasks.isNotEmpty &&
          (pageCount != null ? page < pageCount : tasks.length >= pageSize),
    );
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';
  static int? _integer(Object? value) => int.tryParse(_text(value));

  static DateTime? _date(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value < 1e11 ? value * 1000 : value).toInt(),
      );
    }
    return DateTime.tryParse(_text(value))?.toLocal();
  }

  static String _mediaUrl(String value, String baseUrl) {
    if (value.isEmpty) return '';
    final base = Uri.parse(baseUrl);
    final url = base.resolve(value);
    // Development responses can contain server-local media URLs.
    if (['localhost', '127.0.0.1', '0.0.0.0'].contains(url.host) &&
        (url.path.startsWith('/media/') || url.path.startsWith('/resource/'))) {
      return base.resolveUri(Uri(path: url.path, query: url.query)).toString();
    }
    return url.toString();
  }
}
