import 'package:dio/dio.dart';

Future<void> save(
  Uri url, {
  CancelToken? cancelToken,
  Map<String, String> headers = const {},
  void Function()? onUnauthorized,
}) => throw UnsupportedError('Native video saving is unavailable');

Future<T> withDownloadedVideo<T>(
  Uri url,
  Future<T> Function(String path) action, {
  CancelToken? cancelToken,
  Map<String, String> headers = const {},
  void Function()? onUnauthorized,
}) => throw UnsupportedError('Temporary video files are unavailable');

Future<String> downloadForPlayback(
  Uri url, {
  CancelToken? cancelToken,
  Map<String, String> headers = const {},
  void Function()? onUnauthorized,
  required int maxBytes,
  String? fileExtension,
}) => throw UnsupportedError('Temporary media files are unavailable');

Future<void> deleteDownloaded(String path) async {}
