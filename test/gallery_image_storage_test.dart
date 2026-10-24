import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/gallery_image_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web save downloads decoded PNG bytes without calling Gal', (
    tester,
  ) async {
    Uint8List? downloaded;
    String? downloadedName;
    final galCalls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const galChannel = MethodChannel('gal');
    messenger.setMockMethodCallHandler(galChannel, (call) async {
      galCalls.add(call.method);
      return true;
    });
    GalleryImageStorage.debugWebSave = (bytes, name) async {
      downloaded = bytes;
      downloadedName = name;
    };
    addTearDown(() {
      GalleryImageStorage.debugWebSave = null;
      messenger.setMockMethodCallHandler(galChannel, null);
    });

    await tester.runAsync(
      () => GalleryImageStorage.save(
        const AssetImage('assets/images/assets_works_gallery_01.png'),
        const ImageConfiguration(),
      ),
    );

    expect(downloadedName, matches(RegExp(r'^POPi_\d+\.png$')));
    expect(downloaded, isNotNull);
    expect(downloaded!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(galCalls, isEmpty);
  });
}
