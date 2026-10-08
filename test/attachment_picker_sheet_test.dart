import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/attachments/data/device_gallery_repository.dart';
import 'package:popi_ai_app/features/attachments/domain/gallery_repository.dart';
import 'package:popi_ai_app/features/attachments/presentation/attachment_picker_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/media_provider.dart';

final _png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'system grant is reused and only image permission is requested',
    () async {
      const channel = MethodChannel('com.fluttercandies/photo_manager');
      var state = PermissionState.notDetermined;
      var requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final arguments = call.arguments as Map;
            expect(arguments['androidPermission'], {
              'type': RequestType.image.value,
              'mediaLocation': false,
            });
            if (call.method == 'requestPermissionExtend') {
              requests++;
              state = PermissionState.limited;
            }
            return state.index;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final repository = DeviceGalleryRepository();
      expect(await repository.permission(request: true), GalleryAccess.limited);
      expect(await repository.permission(request: true), GalleryAccess.limited);
      expect(requests, 1);
      state = PermissionState.restricted;
      expect(
        await repository.permission(request: true),
        GalleryAccess.restricted,
      );
      expect(requests, 1);
    },
  );

  Future<void> open(
    WidgetTester tester,
    _Gallery repository, {
    int limit = 5,
    Size size = const Size(440, 956),
    ThemeData? theme,
    Locale locale = const Locale('zh'),
    void Function(AttachmentPickerResult?)? onResult,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(repository.events.close);
    final appTheme = theme ?? AppTheme.light;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [galleryRepositoryProvider.overrideWithValue(repository)],
        child: RepaintBoundary(
          key: const Key('attachment-screenshot'),
          child: MaterialApp(
            theme: const bool.fromEnvironment('ATTACHMENT_SCREENSHOTS')
                ? appTheme.copyWith(
                    textTheme: appTheme.textTheme.apply(fontFamily: 'VisualQA'),
                  )
                : appTheme,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: IconButton(
                    key: const Key('open-attachment'),
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final result = await AttachmentPickerSheet.show(
                        context: context,
                        limit: limit,
                      );
                      onResult?.call(result);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-attachment')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'confirms selected photos in selection order within remaining slots',
    (tester) async {
      final repository = _Gallery();
      AttachmentPickerResult? result;
      await open(
        tester,
        repository,
        limit: 2,
        onResult: (value) => result = value,
      );
      final confirm = find.byKey(const Key('attachment-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('gallery:1')));
      await tester.tap(find.byKey(const ValueKey('gallery:0')));
      await tester.tap(find.byKey(const ValueKey('gallery:2')));
      await tester.pump();
      expect(repository.reads, isEmpty);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result!.images.map((file) => file.name), [
        'photo-1.png',
        'photo-0.png',
      ]);
      expect(repository.reads, ['1', '0']);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'cancel discards selection and authorized photos remain on reopening',
    (tester) async {
      final repository = _Gallery()..access = GalleryAccess.limited;
      AttachmentPickerResult? result;
      await open(tester, repository, onResult: (value) => result = value);
      await tester.tap(find.byKey(const ValueKey('gallery:0')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(repository.reads, isEmpty);
      await tester.tap(find.byKey(const Key('open-attachment')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gallery:0')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('attachment-confirm')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('limited access management refreshes accessible photos', (
    tester,
  ) async {
    final repository = _Gallery()
      ..access = GalleryAccess.limited
      ..count = 1;
    await open(tester, repository);
    expect(find.byKey(const ValueKey('gallery:1')), findsNothing);
    await tester.tap(find.text('管理可访问照片'));
    await tester.pumpAndSettle();
    expect(repository.manageCount, 1);
    expect(find.byKey(const ValueKey('gallery:1')), findsOneWidget);
  });

  testWidgets('permission revocation clears gallery selection on resume', (
    tester,
  ) async {
    final repository = _Gallery()..access = GalleryAccess.limited;
    await open(tester, repository);
    await tester.tap(find.byKey(const ValueKey('gallery:0')));
    repository.access = GalleryAccess.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gallery:0')), findsNothing);
    expect(find.text('未开启相册访问权限'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('attachment-confirm')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('相册权限设置'));
    await tester.pumpAndSettle();
    expect(repository.settingsCount, 1);
  });

  testWidgets(
    'retry recovers loading errors and photo changes remove revoked selection',
    (tester) async {
      final repository = _Gallery()..failLoad = true;
      await open(tester, repository);
      expect(find.text('照片加载失败，请重试'), findsOneWidget);
      repository.failLoad = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gallery:0')));
      repository.unavailable.add('0');
      repository.events.add(null);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('attachment-confirm')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('camera adds a selected image that still requires confirmation', (
    tester,
  ) async {
    final repository = _Gallery()..access = GalleryAccess.denied;
    AttachmentPickerResult? result;
    await open(tester, repository, onResult: (value) => result = value);
    await tester.tap(find.text('拍摄'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.byKey(const Key('attachment-confirm')));
    await tester.pumpAndSettle();
    expect(result!.images.single.name, 'camera.png');
  });

  testWidgets(
    'missing selected photo reports failure without returning partial files',
    (tester) async {
      final repository = _Gallery();
      AttachmentPickerResult? result;
      await open(tester, repository, onResult: (value) => result = value);
      await tester.tap(find.byKey(const ValueKey('gallery:0')));
      repository.unavailable.add('0');
      await tester.pump();
      await tester.tap(find.byKey(const Key('attachment-confirm')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(AttachmentPickerSheet), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('attachment-confirm')))
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('pages beyond the initial library batch', (tester) async {
    final repository = _Gallery()..count = 65;
    await open(tester, repository);
    for (var i = 0; i < 12; i++) {
      await tester.drag(
        find.byKey(const Key('attachment-photo-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
    }
    expect(repository.pages, contains(1));
    expect(find.byKey(const ValueKey('gallery:64')), findsOneWidget);
  });

  for (final library in AttachmentLibrary.values) {
    testWidgets('${library.name} opens the existing library entry', (
      tester,
    ) async {
      AttachmentPickerResult? result;
      await open(tester, _Gallery(), onResult: (value) => result = value);
      await tester.tap(
        find.text(library == AttachmentLibrary.roles ? '角色' : '资产'),
      );
      await tester.pumpAndSettle();
      expect(result!.library, library);
      expect(result!.images, isEmpty);
    });
  }

  for (final variant in ['reference', 'compact', 'dark-english']) {
    testWidgets('layout remains usable: $variant', (tester) async {
      final repository = _Gallery();
      if (const bool.fromEnvironment('ATTACHMENT_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final loader = FontLoader('VisualQA')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    '/System/Library/Fonts/STHeiti Light.ttc',
                  ).readAsBytesSync(),
                ),
              ),
            );
          await loader.load();
        });
        repository.thumbnails = List.generate(
          9,
          (i) => File(
            'assets/images/assets_works_gallery_${(i + 1).toString().padLeft(2, '0')}.png',
          ).readAsBytesSync(),
        );
      }
      await open(
        tester,
        repository,
        size: variant == 'compact'
            ? const Size(320, 568)
            : const Size(440, 956),
        theme: variant == 'dark-english' ? AppTheme.dark : AppTheme.light,
        locale: Locale(variant == 'dark-english' ? 'en' : 'zh'),
      );
      if (const bool.fromEnvironment('ATTACHMENT_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final context = tester.element(find.byType(AttachmentPickerSheet));
          for (final bytes in repository.thumbnails!) {
            await precacheImage(
              ResizeImage(MemoryImage(bytes), width: 384),
              context,
            );
          }
        });
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final confirm = tester.getRect(
        find.byKey(const Key('attachment-confirm')),
      );
      expect(confirm.height, 50);
      expect(
        confirm.bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      final first = tester.getSize(find.byKey(const ValueKey('gallery:0')));
      expect(first.width, closeTo(first.height, .01));
      if (variant == 'reference') expect(first, const Size.square(128));
      if (const bool.fromEnvironment('ATTACHMENT_SCREENSHOTS')) {
        await tester.tap(find.byKey(const ValueKey('gallery:0')));
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('attachment-screenshot')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/popi-attachment-$variant.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}

class _Gallery implements GalleryRepository {
  final events = StreamController<void>.broadcast();
  final reads = <String>[];
  final pages = <int>[];
  final unavailable = <String>{};
  List<Uint8List>? thumbnails;
  GalleryAccess access = GalleryAccess.full;
  int count = 9;
  int manageCount = 0;
  int settingsCount = 0;
  bool failLoad = false;

  @override
  bool get supportsLibrary => true;
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<GalleryAccess> permission({bool request = false}) async => access;
  @override
  Future<List<GalleryPhoto>> loadPage({
    required int page,
    required int size,
  }) async {
    if (failLoad) throw StateError('load failed');
    pages.add(page);
    return List.generate(
          count,
          (i) => GalleryPhoto(id: '$i', name: 'photo-$i.png'),
        )
        .where((photo) => !unavailable.contains(photo.id))
        .skip(page * size)
        .take(size)
        .toList();
  }

  @override
  Future<bool> isAvailable(GalleryPhoto photo) async =>
      !unavailable.contains(photo.id);
  @override
  Future<Uint8List?> thumbnail(GalleryPhoto photo) async =>
      thumbnails?[int.parse(photo.id) % thumbnails!.length] ?? _png;
  @override
  Future<XFile?> readPhoto(GalleryPhoto photo) async {
    reads.add(photo.id);
    return unavailable.contains(photo.id)
        ? null
        : XFile.fromData(_png, path: photo.name, name: photo.name);
  }

  @override
  Future<void> manageLimitedAccess() async {
    manageCount++;
    count++;
  }

  @override
  Future<void> openSettings() async {
    settingsCount++;
  }

  @override
  Future<List<XFile>> pickImages(int limit) async => [];
  @override
  Future<XFile?> takePhoto() async =>
      XFile.fromData(_png, path: 'camera.png', name: 'camera.png');
}
