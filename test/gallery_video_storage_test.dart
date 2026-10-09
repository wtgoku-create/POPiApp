import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/gallery_image_storage.dart';
import 'package:popi_ai_app/core/storage/gallery_video_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('gal');
  const bytes = [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50];
  late HttpServer server;
  late Uri url;
  late List<Uri> requests;
  late List<String> calls;
  String? savedPath;
  var hasAccess = true;
  var grantAccess = true;
  var status = HttpStatus.ok;
  var failSave = false;

  // Keep the integration download on our loopback server, bypassing Flutter's mock HTTP client.
  Future<void> save({CancelToken? cancelToken}) =>
      HttpOverrides.runWithHttpOverrides(
        () => GalleryVideoStorage.save(url, cancelToken: cancelToken),
        _LoopbackHttpOverrides(),
      );

  setUp(() async {
    requests = [];
    calls = [];
    savedPath = null;
    hasAccess = true;
    grantAccess = true;
    status = HttpStatus.ok;
    failSave = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = Uri.parse('http://127.0.0.1:${server.port}/video.mov?signature=test');
    server.listen((request) async {
      requests.add(request.uri);
      request.response.statusCode = status;
      request.response.add(bytes);
      await request.response.close();
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'hasAccess') return hasAccess;
          if (call.method == 'requestAccess') return grantAccess;
          if (call.method == 'putVideo') {
            savedPath = (call.arguments as Map)['path'] as String;
            expect(await File(savedPath!).readAsBytes(), bytes);
            if (failSave) throw PlatformException(code: 'UNEXPECTED');
          }
          return null;
        });
  });

  tearDown(() async {
    await server.close(force: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('saves original bytes and removes the temporary file', () async {
    hasAccess = false;
    await save();
    expect(calls, ['hasAccess', 'requestAccess', 'requestAccess', 'putVideo']);
    expect(requests.single.toString(), '/video.mov?signature=test');
    expect(savedPath, endsWith('.mov'));
    expect(await File(savedPath!).parent.exists(), isFalse);
  });

  test('denied permission does not download', () async {
    hasAccess = false;
    grantAccess = false;
    await expectLater(save(), throwsA(isA<GalleryAccessDenied>()));
    expect(requests, isEmpty);
    expect(calls, ['hasAccess', 'requestAccess']);
  });

  test(
    'HTTP failure does not save and a subsequent download can succeed',
    () async {
      status = HttpStatus.internalServerError;
      await expectLater(save(), throwsA(isA<DioException>()));
      expect(calls, ['hasAccess']);
      expect(savedPath, isNull);
      status = HttpStatus.ok;
      await save();
      expect(savedPath, isNotNull);
      expect(await File(savedPath!).parent.exists(), isFalse);
    },
  );

  test('gallery failure also removes the temporary file', () async {
    failSave = true;
    await expectLater(save(), throwsException);
    expect(savedPath, isNotNull);
    expect(await File(savedPath!).parent.exists(), isFalse);
  });

  test('cancelled download never fetches or saves the video', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      save(cancelToken: token),
      throwsA(
        isA<DioException>().having(CancelToken.isCancel, 'cancelled', isTrue),
      ),
    );
    expect(requests, isEmpty);
    expect(calls, ['hasAccess']);
  });
}

class _LoopbackHttpOverrides extends HttpOverrides {}
