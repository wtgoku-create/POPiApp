@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/clipboard/clipboard_images.dart';

void main() {
  test('focused image paste is handled once across active bindings', () async {
    final received = <List<ClipboardImagePayload>>[];
    final done = Completer<void>();
    void accept(List<ClipboardImagePayload> images) {
      received.add(images);
      if (!done.isCompleted) done.complete();
    }

    final first = createClipboardImagePasteBinding(
      isFocused: () => true,
      onImages: accept,
    );
    final second = createClipboardImagePasteBinding(
      isFocused: () => true,
      onImages: accept,
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    first.setActive(true);
    second.setActive(true);

    final transfer = _newDataTransfer();
    transfer.items.add(_newFile('paste.png', 'image/png', _png()));
    final event = _newPasteEvent(transfer);
    _document.dispatchEvent(event);
    await done.future.timeout(const Duration(seconds: 2));

    expect(event.defaultPrevented, isTrue);
    expect(received, hasLength(1));
    expect(received.single.single.name, 'paste.png');
    expect(received.single.single.mimeType, 'image/png');
  });

  test('plain text and unfocused bindings leave browser paste untouched', () {
    var calls = 0;
    final binding = createClipboardImagePasteBinding(
      isFocused: () => true,
      onImages: (_) => calls++,
    );
    addTearDown(binding.dispose);
    binding.setActive(true);

    final text = _newDataTransfer();
    text.items.add('hello'.toJS, 'text/plain');
    final textEvent = _newPasteEvent(text);
    _document.dispatchEvent(textEvent);
    expect(textEvent.defaultPrevented, isFalse);
    expect(calls, 0);

    binding.setActive(false);
    final image = _newDataTransfer();
    image.items.add(_newFile('paste.png', 'image/png', _png()));
    final inactiveEvent = _newPasteEvent(image);
    _document.dispatchEvent(inactiveEvent);
    expect(inactiveEvent.defaultPrevented, isFalse);
    expect(calls, 0);
  });

  test('unsupported image metadata fails before content delivery', () async {
    final error = Completer<ClipboardImageException>();
    final binding = createClipboardImagePasteBinding(
      isFocused: () => true,
      onImages: (_) => fail('unsupported image must not be delivered'),
      onError: error.complete,
    );
    addTearDown(binding.dispose);
    binding.setActive(true);
    final transfer = _newDataTransfer();
    transfer.items.add(_newFile('paste.gif', 'image/gif', Uint8List(4)));
    final event = _newPasteEvent(transfer);
    _document.dispatchEvent(event);

    expect(event.defaultPrevented, isTrue);
    expect(
      (await error.future.timeout(const Duration(seconds: 2))).code,
      'unsupported_type',
    );
  });

  test(
    'disposing after dispatch suppresses late image and error callbacks',
    () async {
      var images = 0;
      var errors = 0;
      final binding = createClipboardImagePasteBinding(
        isFocused: () => true,
        onImages: (_) => images++,
        onError: (_) => errors++,
      );
      binding.setActive(true);
      final transfer = _newDataTransfer();
      transfer.items.add(_newFile('paste.png', 'image/png', _png()));
      _document.dispatchEvent(_newPasteEvent(transfer));
      binding.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(images, 0);
      expect(errors, 0);
    },
  );
}

_DataTransfer _newDataTransfer() => globalContext
    .getProperty<JSFunction>('DataTransfer'.toJS)
    .callAsConstructor<_DataTransfer>();

_File _newFile(String name, String type, Uint8List bytes) => globalContext
    .getProperty<JSFunction>('File'.toJS)
    .callAsConstructor<_File>(
      <JSAny?>[bytes.toJS].toJS,
      name.toJS,
      <String, Object?>{'type': type}.jsify(),
    );

_ClipboardEvent _newPasteEvent(_DataTransfer transfer) => globalContext
    .getProperty<JSFunction>('ClipboardEvent'.toJS)
    .callAsConstructor<_ClipboardEvent>(
      'paste'.toJS,
      <String, Object?>{
        'clipboardData': transfer,
        'bubbles': true,
        'cancelable': true,
      }.jsify(),
    );

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

@JS('document')
external _Document get _document;

extension type _Document(JSObject _) implements JSObject {
  external bool dispatchEvent(_ClipboardEvent event);
}

extension type _DataTransfer(JSObject _) implements JSObject {
  external _DataTransferItems get items;
}

extension type _DataTransferItems(JSObject _) implements JSObject {
  external JSAny? add(JSAny data, [String? type]);
}

extension type _File(JSObject _) implements JSObject {}

extension type _ClipboardEvent(JSObject _) implements JSObject {
  external bool get defaultPrevented;
}
