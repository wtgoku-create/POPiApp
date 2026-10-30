import '../../../core/utils/app_url.dart';

/// A completed image/video result nested inside a creation task.
class LibraryWork {
  const LibraryWork({
    required this.id,
    required this.previewUrl,
    required this.isVideo,
    required this.createdAt,
    this.videoUrl = '',
    this.imageUrls = const [],
    this.previewHeaders = const {},
    this.mediaType = '',
  });

  final String id;
  final String previewUrl;
  final bool isVideo;
  final String videoUrl;
  final List<String> imageUrls;
  final Map<String, String> previewHeaders;
  final String mediaType;
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
        final rawImages = result['images'];
        final images = <String>[
          if (rawImages is List)
            for (final value in rawImages)
              if (_text(value).isNotEmpty)
                AppUrl.resolve(_text(value), baseUrl: mediaBaseUrl),
        ];
        final image = images.isNotEmpty ? images.first : '';
        if (id.isEmpty || (video.isEmpty && image.isEmpty)) continue;
        final cover = _text(result['cover'] ?? result['coverThumb']);
        items.add(
          LibraryWork(
            id: id,
            previewUrl: AppUrl.resolve(
              video.isNotEmpty && cover.isNotEmpty ? cover : image,
              baseUrl: mediaBaseUrl,
            ),
            isVideo: video.isNotEmpty,
            videoUrl: AppUrl.resolve(video, baseUrl: mediaBaseUrl),
            imageUrls: List.unmodifiable(images),
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
}
