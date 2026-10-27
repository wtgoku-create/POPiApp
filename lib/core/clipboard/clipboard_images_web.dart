import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'clipboard_image_validation.dart';
import 'clipboard_images_contract.dart';

ClipboardImageService createClipboardImageService() =>
    const _WebClipboardImageService();

ClipboardImagePasteBinding createClipboardImagePasteBinding({
  required bool Function() isFocused,
  required ClipboardImageCallback onImages,
  void Function(ClipboardImageException error)? onError,
}) => _WebClipboardImagePasteBinding(
  isFocused: isFocused,
  onImages: onImages,
  onError: onError,
);

final class _WebClipboardImageService implements ClipboardImageService {
  const _WebClipboardImageService();

  @override
  Future<List<ClipboardImagePayload>> readImagesFromUserPaste() =>
      throw const ClipboardImageException('unavailable');
}

final class _WebClipboardImagePasteBinding
    implements ClipboardImagePasteBinding {
  _WebClipboardImagePasteBinding({
    required this.isFocused,
    required this.onImages,
    required this.onError,
  }) {
    _listener = ((JSAny eventValue) {
      _onPaste(eventValue as _ClipboardEvent);
    }).toJS;
  }

  static JSObject? _lastHandledEvent;

  final bool Function() isFocused;
  final ClipboardImageCallback onImages;
  final void Function(ClipboardImageException error)? onError;
  late JSFunction _listener;
  bool _active = false;
  bool _disposed = false;

  @override
  void setActive(bool active) {
    if (_disposed || active == _active) return;
    _active = active;
    if (active) {
      _document.addEventListener('paste', _listener);
    } else {
      _document.removeEventListener('paste', _listener);
    }
  }

  void _onPaste(_ClipboardEvent event) {
    if (!_active || !isFocused()) return;
    final previous = _lastHandledEvent;
    if (previous != null && event.strictEquals(previous).toDart) return;
    final files = event.clipboardData?.files;
    if (files == null || files.length == 0) return;
    final selected = <_ClipboardFile>[];
    for (var index = 0; index < files.length; index++) {
      final file = files.item(index);
      if (file != null && _isImageCandidate(file)) selected.add(file);
    }
    if (selected.isEmpty) return;
    _lastHandledEvent = event;
    scheduleMicrotask(() {
      final current = _lastHandledEvent;
      if (current != null && current.strictEquals(event).toDart) {
        _lastHandledEvent = null;
      }
    });
    event.preventDefault();
    unawaited(_readFiles(selected));
  }

  Future<void> _readFiles(List<_ClipboardFile> files) async {
    try {
      if (files.length > clipboardImageCountLimit) {
        throw const ClipboardImageException('too_many_images');
      }
      var total = 0;
      for (final file in files) {
        if (!_hasSupportedImageMetadata(file)) {
          throw const ClipboardImageException('unsupported_type');
        }
        if (file.size <= 0) throw const ClipboardImageException('empty');
        if (file.size > clipboardImageLimitBytes) {
          throw const ClipboardImageException('image_too_large');
        }
        total += file.size;
        if (total > clipboardImageTotalLimitBytes) {
          throw const ClipboardImageException('total_too_large');
        }
      }
      final raw = <ClipboardImagePayload>[];
      for (final file in files) {
        final buffer = (await file.arrayBuffer().toDart).toDart;
        raw.add(
          ClipboardImagePayload(
            name: file.name,
            mimeType: file.type,
            bytes: Uint8List.view(buffer),
          ),
        );
      }
      final images = validateClipboardImagePayloads(raw);
      if (!_disposed && images.isNotEmpty) await onImages(images);
    } on ClipboardImageException catch (error) {
      if (!_disposed) onError?.call(error);
    } catch (_) {
      if (!_disposed) {
        onError?.call(const ClipboardImageException('invalid_content'));
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    setActive(false);
    _disposed = true;
  }
}

bool _hasSupportedImageMetadata(_ClipboardFile file) {
  final type = file.type.toLowerCase();
  if (type == 'image/png' ||
      type == 'image/jpeg' ||
      type == 'image/jpg' ||
      type == 'image/webp') {
    return true;
  }
  if (type.isNotEmpty) return false;
  final name = file.name.toLowerCase();
  return name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.webp');
}

bool _isImageCandidate(_ClipboardFile file) {
  final type = file.type.toLowerCase();
  if (type.startsWith('image/')) return true;
  if (type.isNotEmpty) return false;
  final name = file.name.toLowerCase();
  return name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.webp');
}

@JS('document')
external _ClipboardEventTarget get _document;

extension type _ClipboardEventTarget(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _ClipboardEvent(JSObject _) implements JSObject {
  external _ClipboardData? get clipboardData;
  external void preventDefault();
}

extension type _ClipboardData(JSObject _) implements JSObject {
  external _ClipboardFileList get files;
}

extension type _ClipboardFileList(JSObject _) implements JSObject {
  external int get length;
  external _ClipboardFile? item(int index);
}

extension type _ClipboardFile(JSObject _) implements JSObject {
  external String get name;
  external String get type;
  external int get size;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}
