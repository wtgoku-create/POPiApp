import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/demo/data/demo_file_picker.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/demo_upload_file.dart';

void main() {
  test('picker results keep stable identity and defer reading bytes', () async {
    final bytes = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    final files = await demoUploadFilesFromXFiles([
      XFile.fromData(
        bytes,
        path: '南极.png',
        name: '南极.png',
        mimeType: 'image/png',
      ),
    ]);

    expect(files, hasLength(1));
    expect(files.single.name, '南极.png');
    expect(files.single.mimeType, 'image/png');
    expect(files.single.kind, DemoAssetKind.image);
    expect(files.single.clientRequestId, isNotEmpty);
    expect(files.single.expectedSha256, isNotEmpty);
    expect(await files.single.readBytes(), same(bytes));

    final selectedAgain = await demoUploadFilesFromXFiles([
      XFile.fromData(
        bytes,
        path: '南极.png',
        name: '南极.png',
        mimeType: 'image/png',
      ),
    ]);
    expect(selectedAgain.single.clientRequestId, files.single.clientRequestId);
  });

  test('mixed selection returns valid files on its typed error', () async {
    final bytes = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    DemoUploadException? failure;
    try {
      await demoUploadFilesFromXFiles([
        XFile.fromData(bytes, path: 'valid.png', name: 'valid.png'),
        XFile.fromData(Uint8List(1), path: 'invalid.zip', name: 'invalid.zip'),
      ]);
    } on DemoUploadException catch (error) {
      failure = error;
    }

    expect(failure?.code, 'UNSUPPORTED_TYPE');
    expect(failure?.acceptedFiles, hasLength(1));
    expect(failure?.acceptedFiles.single.name, 'valid.png');
  });

  test('unsupported extension is rejected before body validation', () async {
    await expectLater(
      demoUploadFilesFromXFiles([
        XFile.fromData(Uint8List(4), path: 'archive.zip', name: 'archive.zip'),
      ]),
      throwsA(
        isA<DemoUploadException>().having(
          (error) => error.code,
          'code',
          'UNSUPPORTED_TYPE',
        ),
      ),
    );
  });

  test('metadata and actual body limits are both enforced', () async {
    expect(
      () => DemoUploadFile(
        name: 'empty.md',
        mimeType: 'text/markdown',
        sizeBytes: 0,
        kind: DemoAssetKind.script,
        readBytes: () async => Uint8List(0),
      ),
      throwsA(
        isA<DemoUploadException>().having(
          (error) => error.code,
          'code',
          'EMPTY_FILE',
        ),
      ),
    );

    expect(
      () => DemoUploadFile(
        name: 'large.mp4',
        mimeType: 'video/mp4',
        sizeBytes: DemoUploadFile.videoLimitBytes + 1,
        kind: DemoAssetKind.video,
        readBytes: () async => Uint8List(0),
      ),
      throwsA(
        isA<DemoUploadException>().having(
          (error) => error.code,
          'code',
          'FILE_TOO_LARGE',
        ),
      ),
    );

    final changed = DemoUploadFile(
      clientRequestId: 'request-1',
      name: 'note.txt',
      mimeType: 'text/plain',
      sizeBytes: 4,
      kind: DemoAssetKind.script,
      readBytes: () async => Uint8List.fromList('five!'.codeUnits),
    );
    await expectLater(
      changed.readBytes(),
      throwsA(
        isA<DemoUploadException>().having(
          (error) => error.code,
          'code',
          'SIZE_MISMATCH',
        ),
      ),
    );
  });

  test('declared MIME must match the file signature', () async {
    final disguised = DemoUploadFile(
      name: 'fake.png',
      mimeType: 'image/png',
      sizeBytes: 4,
      kind: DemoAssetKind.image,
      readBytes: () async => Uint8List.fromList('text'.codeUnits),
    );

    await expectLater(
      disguised.readBytes(),
      throwsA(
        isA<DemoUploadException>().having(
          (error) => error.code,
          'code',
          'INVALID_CONTENT',
        ),
      ),
    );
  });

  test('upload read rejects content changed after selection', () async {
    final bytes = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    final changed = DemoUploadFile(
      clientRequestId: 'stable-id',
      name: 'changed.png',
      mimeType: 'image/png',
      sizeBytes: bytes.length,
      kind: DemoAssetKind.image,
      expectedSha256:
          '0000000000000000000000000000000000000000000000000000000000000000',
      readBytes: () async => bytes,
    );

    await expectLater(
      changed.readBytes(),
      throwsA(
        isA<DemoUploadException>().having(
          (error) => error.code,
          'code',
          'INVALID_CONTENT',
        ),
      ),
    );
  });
}
