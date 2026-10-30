import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/clipboard/clipboard_image_validation.dart';
import 'package:popi_ai_app/core/clipboard/clipboard_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(clipboardImageChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'native service requests images only after its explicit method call',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return [
          {'name': 'screen.png', 'mimeType': 'image/png', 'bytes': _png()},
          {'name': 'photo.jpg', 'mimeType': 'image/jpeg', 'bytes': _jpeg()},
        ];
      });

      final service = createClipboardImageService();
      expect(calls, isEmpty);
      final images = await service.readImagesFromUserPaste();

      expect(calls.single.method, 'readImages');
      expect(calls.single.arguments, isNull);
      expect(images.map((image) => image.name), ['screen.png', 'photo.jpg']);
      expect(images.map((image) => image.mimeType), [
        'image/png',
        'image/jpeg',
      ]);
    },
  );

  test(
    'ordinary text clipboard response stays an empty successful paste',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => <Object?>[]);
      expect(
        await createClipboardImageService().readImagesFromUserPaste(),
        isEmpty,
      );
    },
  );

  test('platform failures use the bounded public error vocabulary', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'permission_denied'),
    );
    await expectLater(
      createClipboardImageService().readImagesFromUserPaste(),
      throwsA(
        isA<ClipboardImageException>().having(
          (error) => error.code,
          'code',
          'permission_denied',
        ),
      ),
    );

    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'native_secret'),
    );
    await expectLater(
      createClipboardImageService().readImagesFromUserPaste(),
      throwsA(
        isA<ClipboardImageException>().having(
          (error) => error.code,
          'code',
          'unavailable',
        ),
      ),
    );
  });

  test(
    'missing native registration is reported without reading anything else',
    () async {
      messenger.setMockMethodCallHandler(channel, null);
      await expectLater(
        createClipboardImageService().readImagesFromUserPaste(),
        throwsA(
          isA<ClipboardImageException>().having(
            (error) => error.code,
            'code',
            'unavailable',
          ),
        ),
      );
    },
  );

  test('payload validation owns bytes and rejects mismatched signatures', () {
    final source = _png();
    final validated = validateClipboardImagePayloads([
      ClipboardImagePayload(
        name: '../screen.png',
        mimeType: 'image/png',
        bytes: source,
      ),
    ]).single;
    source[0] = 0;
    expect(validated.name, 'screen.png');
    expect(validated.bytes[0], 0x89);

    expect(
      () => validateClipboardImagePayloads([
        ClipboardImagePayload(
          name: 'fake.png',
          mimeType: 'image/png',
          bytes: _jpeg(),
        ),
      ]),
      throwsA(_clipboardError('invalid_content')),
    );
  });

  test('image count and combined image bytes are independently bounded', () {
    expect(
      () => validateClipboardImagePayloads([
        for (var index = 0; index <= clipboardImageCountLimit; index++)
          ClipboardImagePayload(
            name: '$index.png',
            mimeType: 'image/png',
            bytes: _png(),
          ),
      ]),
      throwsA(_clipboardError('too_many_images')),
    );

    final first = _largePng(11 * 1024 * 1024);
    final second = _largePng(10 * 1024 * 1024);
    expect(
      () => validateClipboardImagePayloads([
        ClipboardImagePayload(
          name: 'one.png',
          mimeType: 'image/png',
          bytes: first,
        ),
        ClipboardImagePayload(
          name: 'two.png',
          mimeType: 'image/png',
          bytes: second,
        ),
      ]),
      throwsA(_clipboardError('total_too_large')),
    );
  });

  test('native paste binding is an inert focus lifecycle adapter', () {
    final binding = createClipboardImagePasteBinding(
      isFocused: () => true,
      onImages: (_) {},
    );
    binding
      ..setActive(true)
      ..setActive(false)
      ..dispose();
  });
}

Matcher _clipboardError(String code) =>
    isA<ClipboardImageException>().having((error) => error.code, 'code', code);

Uint8List _png() => Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0,
]);

Uint8List _jpeg() => Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0]);

Uint8List _largePng(int size) {
  final bytes = Uint8List(size);
  bytes.setRange(0, 8, _png());
  return bytes;
}
