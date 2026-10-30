import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/network/network_api.dart';
import '../domain/demo_upload_file.dart';

enum BusinessUploadPhase { pending, uploading, verifying, ready }

typedef BusinessUploadProgress =
    void Function(BusinessUploadPhase phase, double progress);

/// 服务端幂等键恢复上传状态；重试不会将已完成的文件重新发送。
class BusinessAssetUploader {
  BusinessAssetUploader(this.api);
  final NetworkApi api;
  final Map<String, Future<String>> _inflight = {};
  final Map<String, CancelToken> _tokens = {};

  Future<String> upload(
    DemoUploadFile file, {
    BusinessUploadProgress? onProgress,
  }) => _inflight.putIfAbsent(
    file.clientRequestId,
    () => _upload(file, onProgress).whenComplete(() {
      _inflight.remove(file.clientRequestId);
    }),
  );

  void cancel(String id) => _tokens[id]?.cancel();
  void dispose() {
    for (final token in _tokens.values) {
      token.cancel();
    }
  }

  Future<String> _upload(
    DemoUploadFile file,
    BusinessUploadProgress? progress,
  ) async {
    final token = CancelToken();
    _tokens[file.clientRequestId] = token;
    try {
      progress?.call(BusinessUploadPhase.pending, 0);
      final bytes = await file.readBytes();
      if (token.isCancelled) throw token.cancelError!;
      final input = <String, Object?>{
        'requestKey': file.clientRequestId,
        'name': file.name,
        'mime': file.mimeType,
        'size': bytes.length,
        'hash': sha256.convert(bytes).toString(),
      };
      Map<String, Object?> result = {};
      for (var attempt = 0; attempt < 16; attempt++) {
        result = await api.libraryUpload('create', {
          'direct': input,
        }, cancelToken: token);
        final lease = Map<String, Object?>.from(result['upload'] as Map);
        if (!const {
          'expired',
          'cancelled',
          'failed',
        }.contains(lease['state'])) {
          break;
        }
        input['requestKey'] = '${file.clientRequestId}:${lease['id']}';
      }
      var lease = Map<String, Object?>.from(result['upload'] as Map);
      if (lease['state'] == 'pending') {
        progress?.call(BusinessUploadPhase.uploading, 0);
        await api.uploadLibraryBytes(
          result['uploadUrl'] as String,
          Map<String, Object?>.from(result['uploadHeaders'] as Map),
          bytes,
          cancelToken: token,
          onSendProgress: (sent, total) => progress?.call(
            BusinessUploadPhase.uploading,
            total > 0 ? sent / total : 0,
          ),
        );
      }
      // Complete 可以返回 verifying；轮询有界，关闭页面或换号会立即取消。
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      while (lease['state'] != 'ready') {
        if (token.isCancelled) throw token.cancelError!;
        if (!const {'pending', 'verifying'}.contains(lease['state']) ||
            DateTime.now().isAfter(deadline)) {
          throw const DemoUploadException('UPLOAD_NOT_READY');
        }
        progress?.call(BusinessUploadPhase.verifying, 1);
        result = await api.libraryUpload('complete', {
          'uploadId': lease['id'],
        }, cancelToken: token);
        lease = Map<String, Object?>.from(result['upload'] as Map);
        if (lease['state'] != 'ready') {
          await Future.any([
            Future<void>.delayed(const Duration(seconds: 2)),
            token.whenCancel,
          ]);
        }
      }
      if (token.isCancelled) throw token.cancelError!;
      final assetId = lease['assetId'];
      if (assetId is! String || assetId.isEmpty) {
        throw const DemoUploadException('UPLOAD_NOT_READY');
      }
      progress?.call(BusinessUploadPhase.ready, 1);
      return assetId;
    } finally {
      _tokens.remove(file.clientRequestId);
    }
  }
}
