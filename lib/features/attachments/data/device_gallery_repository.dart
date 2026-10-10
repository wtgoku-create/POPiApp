import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../domain/gallery_repository.dart';

class DeviceGalleryRepository implements GalleryRepository {
  static const _permission = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  @override
  bool get supportsLibrary =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<void> get changes {
    late final StreamController<void> controller;
    void changed(MethodCall _) => controller.add(null);
    controller = StreamController<void>(
      onListen: () {
        PhotoManager.addChangeCallback(changed);
        PhotoManager.startChangeNotify().catchError((Object error) {
          if (!controller.isClosed) controller.addError(error);
        });
      },
      onCancel: () {
        PhotoManager.removeChangeCallback(changed);
      },
    );
    return controller.stream;
  }

  @override
  Future<GalleryAccess> permission({bool request = false}) async {
    var state = await PhotoManager.getPermissionState(
      requestOption: _permission,
    );
    if (request && !state.hasAccess && state != PermissionState.restricted) {
      state = await PhotoManager.requestPermissionExtend(
        requestOption: _permission,
      );
    }
    return switch (state) {
      PermissionState.authorized => GalleryAccess.full,
      PermissionState.limited => GalleryAccess.limited,
      PermissionState.restricted => GalleryAccess.restricted,
      _ => GalleryAccess.denied,
    };
  }

  @override
  Future<List<GalleryPhoto>> loadPage({
    required int page,
    required int size,
  }) async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) return [];
    final assets = await albums.first.getAssetListPaged(page: page, size: size);
    return assets
        .map(
          (asset) => GalleryPhoto(id: asset.id, name: asset.title ?? asset.id),
        )
        .toList();
  }

  @override
  Future<bool> isAvailable(GalleryPhoto photo) async =>
      await AssetEntity.fromId(photo.id) != null;

  @override
  Future<Uint8List?> thumbnail(GalleryPhoto photo) async =>
      (await AssetEntity.fromId(
        photo.id,
      ))?.thumbnailDataWithSize(const ThumbnailSize.square(384));

  @override
  Future<XFile?> readPhoto(GalleryPhoto photo) async {
    final asset = await AssetEntity.fromId(photo.id);
    final file = await asset?.file;
    return file == null ? null : XFile(file.path, name: photo.name);
  }

  @override
  Future<void> manageLimitedAccess() =>
      PhotoManager.presentLimited(type: RequestType.image);

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<List<XFile>> pickImages(int limit) => ImagePicker().pickMultiImage(
    imageQuality: 85,
    maxWidth: 1920,
    limit: limit < 2 ? null : limit,
  );

  @override
  Future<List<XFile>> pickImageFiles(int limit) async {
    if (limit <= 0) return [];
    const images = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
      mimeTypes: [
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/gif',
        'image/bmp',
      ],
      uniformTypeIdentifiers: ['public.image'],
    );
    if (limit == 1) {
      final file = await openFile(acceptedTypeGroups: [images]);
      return [if (file != null) file];
    }
    return openFiles(acceptedTypeGroups: [images]);
  }

  @override
  Future<XFile?> takePhoto() => ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 85,
    maxWidth: 1920,
  );
}
