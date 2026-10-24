import 'package:flutter_cache_manager/flutter_cache_manager.dart';

FileService createAppImageFileService({
  required void Function(String url, Map<String, String> headers)
  onUnauthorized,
}) => HttpFileService();
