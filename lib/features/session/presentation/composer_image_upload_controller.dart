import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';

enum ComposerImageUploadState { selected, uploading, processing, ready, failed }

class PopiComposerImage {
  PopiComposerImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
  ComposerImageUploadState get state => _state;
  double get progress => _progress;
  String? get mediaId => _mediaId;

  ComposerImageUploadState _state = ComposerImageUploadState.selected;
  double _progress = 0;
  String? _mediaId;
}

/// Owns draft uploads and ignores responses after removal or account changes.
class ComposerImageUploadController extends ChangeNotifier {
  final _images = <PopiComposerImage>[];
  final _tokens = <PopiComposerImage, CancelToken>{};

  List<PopiComposerImage> get images => List.unmodifiable(_images);
  bool get ready => _images.every((image) => image.mediaId != null);

  void add(List<PopiComposerImage> images) {
    _images.addAll(images);
    notifyListeners();
  }

  Future<void> upload(
    PopiComposerImage image,
    SessionRepository repository,
    String userId,
  ) async {
    if (!_images.contains(image) ||
        _tokens.containsKey(image) ||
        image.mediaId != null) {
      return;
    }
    final token = CancelToken();
    _tokens[image] = token;
    bool current() => identical(_tokens[image], token);
    image._state = ComposerImageUploadState.uploading;
    image._progress = 0;
    notifyListeners();
    try {
      final mediaId = await repository.upload(
        userId,
        image.name,
        image.bytes,
        cancelToken: token,
        onSendProgress: (sent, total) {
          if (!current() || total <= 0) return;
          image._progress = (sent / total).clamp(0.0, 1.0);
          image._state = sent >= total
              ? ComposerImageUploadState.processing
              : ComposerImageUploadState.uploading;
          notifyListeners();
        },
      );
      if (!current()) return;
      image._mediaId = mediaId;
      image._progress = 1;
      image._state = ComposerImageUploadState.ready;
    } catch (_) {
      if (!current()) return;
      image._state = ComposerImageUploadState.failed;
    }
    _tokens.remove(image);
    notifyListeners();
  }

  void remove(int index) {
    final image = _images.removeAt(index);
    _tokens.remove(image)?.cancel();
    notifyListeners();
  }

  void clear() {
    final tokens = _tokens.values.toList();
    _tokens.clear();
    _images.clear();
    for (final token in tokens) {
      token.cancel();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // Remove the tokens before cancellation so late progress cannot notify.
    final tokens = _tokens.values.toList();
    _tokens.clear();
    for (final token in tokens) {
      token.cancel();
    }
    super.dispose();
  }
}
