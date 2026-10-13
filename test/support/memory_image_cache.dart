import 'dart:io' show HttpException;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Keeps widget tests independent of filesystem plugins and live image servers.
class MemoryImageCache implements BaseCacheManager {
  final _fileSystem = MemoryFileSystem();
  final _files = <String, FileInfo>{};

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    if (_files[key ?? url] case final cached?) {
      yield cached;
      return;
    }
    final client = debugNetworkImageHttpClientProvider?.call();
    if (client == null) {
      throw HttpException('No image fixture for $url', uri: Uri.parse(url));
    }
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final bytes = await response.expand((chunk) => chunk).toList();
    final file = await putFile(url, bytes);
    yield FileInfo(
      file,
      FileSource.Online,
      DateTime.now().add(const Duration(days: 1)),
      url,
    );
  }

  @override
  Future<File> putFile(
    String url,
    List<int> fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    final file = _fileSystem.file('/image-${_files.length}');
    await file.writeAsBytes(fileBytes);
    _files[key ?? url] = FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(maxAge),
      url,
    );
    return file;
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => _files[key];

  @override
  Future<void> removeFile(String key) async {
    _files.remove(key);
  }

  @override
  Future<void> emptyCache() async => _files.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
