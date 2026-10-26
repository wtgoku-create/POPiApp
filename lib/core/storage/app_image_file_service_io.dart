import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'sensitive_media_headers.dart';

FileService createAppImageFileService({
  required void Function(String url, Map<String, String> headers)
  onUnauthorized,
  Duration timeout = const Duration(seconds: 15),
}) => _NoRedirectImageFileService(onUnauthorized, timeout);

class _NoRedirectImageFileService extends FileService {
  _NoRedirectImageFileService(this.onUnauthorized, this.timeout);

  final void Function(String url, Map<String, String> headers) onUnauthorized;
  final Duration timeout;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final requestHeaders = Map<String, String>.of(headers ?? const {});
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(url));
      final protected = hasSensitiveMediaHeaders(requestHeaders);
      request
        ..followRedirects = !protected
        ..maxRedirects = protected ? 0 : 5;
      requestHeaders.forEach(request.headers.set);
      final response = await request.close().timeout(timeout);
      if (response.statusCode == HttpStatus.unauthorized) {
        onUnauthorized(url, requestHeaders);
      }
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.accepted) {
        final closed = _ClosedFileServiceResponse(response);
        try {
          await response.drain<void>().timeout(timeout);
        } on TimeoutException {
          // The status code is already known. Do not let a hanging error body
          // keep a thumbnail in its loading state indefinitely.
        }
        client.close(force: true);
        return closed;
      }
      return _IoFileServiceResponse(response, client, timeout);
    } on Object {
      client.close(force: true);
      rethrow;
    }
  }
}

class _ClosedFileServiceResponse implements FileServiceResponse {
  _ClosedFileServiceResponse(HttpClientResponse response)
    : statusCode = response.statusCode,
      contentLength = response.contentLength < 0
          ? null
          : response.contentLength,
      eTag = response.headers.value(HttpHeaders.etagHeader),
      fileExtension = _fileExtension(response.headers.contentType),
      validTill = _validTill(response.headers);

  @override
  final int statusCode;
  @override
  final int? contentLength;
  @override
  final String? eTag;
  @override
  final String fileExtension;
  @override
  final DateTime validTill;
  @override
  Stream<List<int>> get content => const Stream.empty();
}

class _IoFileServiceResponse implements FileServiceResponse {
  _IoFileServiceResponse(this.response, this.client, this.timeout);

  final HttpClientResponse response;
  final HttpClient client;
  final Duration timeout;

  @override
  Stream<List<int>> get content => response
      .timeout(
        timeout,
        onTimeout: (sink) {
          sink.addError(TimeoutException('Image response timed out', timeout));
          sink.close();
          client.close(force: true);
        },
      )
      .transform<List<int>>(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) => sink.add(data),
          handleDone: (sink) {
            client.close(force: true);
            sink.close();
          },
          handleError: (error, stack, sink) {
            client.close(force: true);
            sink.addError(error, stack);
            sink.close();
          },
        ),
      );

  @override
  int? get contentLength =>
      response.contentLength < 0 ? null : response.contentLength;

  @override
  String? get eTag => response.headers.value(HttpHeaders.etagHeader);

  @override
  String get fileExtension => _fileExtension(response.headers.contentType);

  @override
  int get statusCode => response.statusCode;

  @override
  DateTime get validTill => _validTill(response.headers);
}

String _fileExtension(ContentType? contentType) =>
    switch (contentType?.mimeType) {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '',
    };

DateTime _validTill(HttpHeaders headers) {
  final cacheControl = headers.value(HttpHeaders.cacheControlHeader);
  final maxAge = cacheControl
      ?.split(',')
      .map((part) => part.trim().toLowerCase())
      .where((part) => part.startsWith('max-age='))
      .map((part) => int.tryParse(part.substring('max-age='.length)))
      .whereType<int>()
      .firstOrNull;
  return DateTime.now().add(Duration(seconds: maxAge ?? 7 * 24 * 60 * 60));
}
