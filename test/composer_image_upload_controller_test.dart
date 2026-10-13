import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/presentation/composer_image_upload_controller.dart';

import 'support/session_fixtures.dart';

class _UploadRepository extends FixtureSessionRepository {
  final completions = <Completer<String>>[];
  final progress = <ProgressCallback>[];
  final tokens = <CancelToken>[];

  @override
  Future<String> upload(
    String userId,
    String name,
    Uint8List bytes, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) {
    final result = Completer<String>();
    completions.add(result);
    progress.add(onSendProgress!);
    tokens.add(cancelToken!);
    return result.future;
  }
}

void main() {
  late ComposerImageUploadController controller;
  late _UploadRepository repository;
  late PopiComposerImage image;

  setUp(() {
    controller = ComposerImageUploadController();
    repository = _UploadRepository();
    image = PopiComposerImage(name: 'photo.png', bytes: Uint8List(20));
  });

  test(
    'tracks byte progress and waits for completion before enabling send',
    () async {
      addTearDown(controller.dispose);
      expect(controller.images, isEmpty);
      expect(controller.ready, isTrue);
      controller.add([image]);
      expect(image.state, ComposerImageUploadState.selected);
      expect(controller.ready, isFalse);
      final upload = controller.upload(image, repository, 'user');
      expect(image.state, ComposerImageUploadState.uploading);
      repository.progress.single(5, 20);
      expect(image.progress, .25);
      repository.progress.single(20, 20);
      expect(image.state, ComposerImageUploadState.processing);
      expect(controller.ready, isFalse);
      repository.completions.single.complete('media-1');
      await upload;
      expect(image.state, ComposerImageUploadState.ready);
      expect(image.mediaId, 'media-1');
      expect(controller.ready, isTrue);
      await controller.upload(image, repository, 'user');
      expect(repository.completions, hasLength(1));
    },
  );

  test(
    'failure retains image and retry cannot start duplicate uploads',
    () async {
      addTearDown(controller.dispose);
      controller.add([image]);
      final failed = controller.upload(image, repository, 'user');
      repository.completions.single.completeError(StateError('offline'));
      await failed;
      expect(image.state, ComposerImageUploadState.failed);
      expect(controller.images.single, same(image));
      expect(controller.ready, isFalse);
      final retry = controller.upload(image, repository, 'user');
      await controller.upload(image, repository, 'user');
      expect(repository.completions, hasLength(2));
      repository.completions.last.complete('media-1');
      await retry;
      expect(controller.ready, isTrue);
    },
  );

  test(
    'removal cancels upload and discards late progress and completion',
    () async {
      addTearDown(controller.dispose);
      controller.add([image]);
      final upload = controller.upload(image, repository, 'user');
      controller.remove(0);
      expect(repository.tokens.single.isCancelled, isTrue);
      repository.progress.single(10, 20);
      repository.completions.single.complete('late');
      await upload;
      expect(controller.images, isEmpty);
      expect(image.mediaId, isNull);
      expect(image.progress, 0);
    },
  );

  test(
    'reset cancels every pending image and ignores obsolete failures',
    () async {
      addTearDown(controller.dispose);
      final second = PopiComposerImage(
        name: 'second.png',
        bytes: Uint8List(10),
      );
      controller.add([image, second]);
      final uploads = [
        controller.upload(image, repository, 'user'),
        controller.upload(second, repository, 'user'),
      ];
      controller.clear();
      expect(repository.tokens.every((token) => token.isCancelled), isTrue);
      for (final completion in repository.completions) {
        completion.completeError(StateError('cancelled'));
      }
      await Future.wait(uploads);
      expect(controller.images, isEmpty);
      expect(controller.ready, isTrue);
    },
  );

  test('dispose cancels uploads without notifying on late responses', () async {
    controller.add([image]);
    final upload = controller.upload(image, repository, 'user');
    controller.dispose();
    expect(repository.tokens.single.isCancelled, isTrue);
    repository.progress.single(20, 20);
    repository.completions.single.complete('late');
    await upload;
    expect(image.mediaId, isNull);
  });
}
