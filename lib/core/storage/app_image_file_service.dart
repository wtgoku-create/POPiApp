import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'app_image_file_service_stub.dart'
    if (dart.library.io) 'app_image_file_service_io.dart'
    as platform;

FileService createAppImageFileService({
  required void Function(String url, Map<String, String> headers)
  onUnauthorized,
}) => platform.createAppImageFileService(onUnauthorized: onUnauthorized);
