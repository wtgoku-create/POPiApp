import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum GalleryAccess { full, limited, denied, restricted }

class GalleryPhoto {
  const GalleryPhoto({required this.id, required this.name});

  final String id;
  final String name;
}

/// Device photos are queried through the current system authorization scope.
abstract class GalleryRepository {
  bool get supportsLibrary;
  Stream<void> get changes;
  Future<GalleryAccess> permission({bool request = false});
  Future<List<GalleryPhoto>> loadPage({required int page, required int size});
  Future<bool> isAvailable(GalleryPhoto photo);
  Future<Uint8List?> thumbnail(GalleryPhoto photo);
  Future<XFile?> readPhoto(GalleryPhoto photo);
  Future<void> manageLimitedAccess();
  Future<void> openSettings();
  Future<List<XFile>> pickImages(int limit);
  Future<List<XFile>> pickImageFiles(int limit);
  Future<XFile?> takePhoto();
}
