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
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:popi_ai_app/features/assets/presentation/asset_selection_sheet.dart';
import 'package:popi_ai_app/features/assets/presentation/role_selection_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

import 'support/role_library_fixtures.dart';
import 'support/work_library_fixtures.dart';

final _png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'file picker restricts image types and handles single selection and cancel',
    () async {
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      final calls = <Map<Object?, Object?>>[];
      List<String>? paths = ['/tmp/image.png'];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'openFile');
            calls.add(Map<Object?, Object?>.from(call.arguments as Map));
            return paths;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final repository = DeviceGalleryRepository();
      expect(
        (await repository.pickImageFiles(1)).single.path,
        '/tmp/image.png',
      );
      expect(calls.single['multiple'], isFalse);
      final types = (calls.single['acceptedTypeGroups'] as List).single as Map;
      expect(types['extensions'], containsAll(['png', 'jpg', 'webp']));
      expect(types['extensions'], isNot(contains('pdf')));
      expect(types['uniformTypeIdentifiers'], ['public.image']);
      paths = null;
      expect(await repository.pickImageFiles(1), isEmpty);
      expect(await repository.pickImageFiles(5), isEmpty);
      expect(calls.last['multiple'], isTrue);
      expect(await repository.pickImageFiles(0), isEmpty);
      expect(calls.length, 3);
    },
  );

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
    double textScale = 1,
    List<LibraryRole> selectedRoles = const [],
    List<LibraryWork> selectedAssets = const [],
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
        overrides: [
          userProvider.overrideWith(LibraryTestUserController.new),
          dioProvider.overrideWithValue(
            withWorkLibrary(
              roleLibraryDio(
                loadPage:
                    ({
                      required category,
                      required page,
                      required pageSize,
                    }) async => LibraryRolePage(
                      items: List.generate(
                        6,
                        (index) => LibraryRole(
                          id: '${index + (category == 'official' ? 1 : 21)}',
                          title: [
                            '爱丽丝',
                            '尔尔',
                            '花西冷少',
                            '水濑兜兜儿',
                            '奇奇蒂蒂',
                            '人鱼小姐',
                          ][index],
                          description: '叮叮当同桌、室友和毒舌闺蜜...',
                          avatar:
                              'assets/images/role_guide_avatar_${index + 1}.png',
                        ),
                      ),
                      page: 1,
                      pageCount: 1,
                    ),
              ),
            ),
          ),
        ],
        child: RepaintBoundary(
          key: const Key('attachment-screenshot'),
          child: MaterialApp(
            theme: const bool.fromEnvironment('ATTACHMENT_SCREENSHOTS')
                ? appTheme.copyWith(
                    textTheme: appTheme.textTheme.apply(fontFamily: 'VisualQA'),
                  )
                : appTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
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
                        repository: repository,
                        selectedRoles: selectedRoles,
                        selectedAssets: selectedAssets,
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

  testWidgets('limited access shows album entry without access management', (
    tester,
  ) async {
    final repository = _Gallery()
      ..access = GalleryAccess.limited
      ..count = 1;
    await open(tester, repository);
    expect(find.text('相册'), findsOneWidget);
    expect(find.text('拍摄'), findsNothing);
    expect(find.text('管理可访问照片'), findsNothing);
    expect(find.text('相册权限设置'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('attachment-source-gallery')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is AppSvgIcon && widget.assetName == 'attachment_camera',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('gallery:0')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery:1')), findsNothing);
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

  testWidgets('album adds selected images that still require confirmation', (
    tester,
  ) async {
    final repository = _Gallery()
      ..access = GalleryAccess.denied
      ..pickedImages = [
        XFile.fromData(_png, path: 'album.png', name: 'album.png'),
      ];
    AttachmentPickerResult? result;
    await open(tester, repository, onResult: (value) => result = value);
    await tester.tap(find.text('相册'));
    await tester.pumpAndSettle();
    expect(repository.pickLimits, [5]);
    expect(repository.cameraCount, 0);
    expect(result, isNull);
    await tester.tap(find.byKey(const Key('attachment-confirm')));
    await tester.pumpAndSettle();
    expect(result!.images.single.name, 'album.png');
  });

  testWidgets(
    'album respects remaining slots and cancellation keeps selection',
    (tester) async {
      final repository = _Gallery();
      AttachmentPickerResult? result;
      await open(
        tester,
        repository,
        limit: 2,
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('gallery:0')));
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
      expect(repository.pickLimits, [1]);
      expect(find.byType(AttachmentPickerSheet), findsOneWidget);
      repository.pickedImages = [
        XFile.fromData(_png, path: 'album.png', name: 'album.png'),
        XFile.fromData(_png, path: 'extra.png', name: 'extra.png'),
      ];
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attachment-confirm')));
      await tester.pumpAndSettle();
      expect(result!.images.map((file) => file.name), [
        'photo-0.png',
        'album.png',
      ]);
      expect(repository.pickLimits, [1, 1]);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'image files preserve selection on cancel and respect remaining slots',
    (tester) async {
      final repository = _Gallery();
      AttachmentPickerResult? result;
      await open(
        tester,
        repository,
        limit: 2,
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('gallery:0')));
      await tester.tap(find.byKey(const Key('attachment-source-files')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(repository.fileLimits, [1]);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppSvgIcon && widget.assetName == 'attachment_selected',
        ),
        findsOneWidget,
      );
      repository.pickedFiles = [
        XFile.fromData(_png, path: 'file.png', name: 'file.png'),
        XFile.fromData(_png, path: 'extra.png', name: 'extra.png'),
      ];
      await tester.tap(find.byKey(const Key('attachment-source-files')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.byKey(const Key('attachment-confirm')));
      await tester.pumpAndSettle();
      expect(result!.images.map((file) => file.name), [
        'photo-0.png',
        'file.png',
      ]);
      expect(repository.fileLimits, [1, 1]);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('file picker failure leaves current photo selection available', (
    tester,
  ) async {
    final repository = _Gallery()..failFilePick = true;
    AttachmentPickerResult? result;
    await open(tester, repository, onResult: (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('gallery:0')));
    await tester.tap(find.byKey(const Key('attachment-source-files')));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentPickerSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('attachment-confirm')));
    await tester.pumpAndSettle();
    expect(result!.images.single.name, 'photo-0.png');
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
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

  testWidgets('assets preserve photos and ordered selections across filters', (
    tester,
  ) async {
    AttachmentPickerResult? result;
    await open(tester, _Gallery(), onResult: (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('gallery:0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('attachment-source-assets')));
    await tester.pumpAndSettle();
    expect(find.text('资产库'), findsOneWidget);
    expect(find.byKey(const Key('role-guide-create-role')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('asset-library-select-1')));
    await tester.tap(find.byKey(const Key('role-segment-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('asset-library-select-6')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('asset-selection-confirm')));
    await tester.pumpAndSettle();
    expect(result!.assets!.map((work) => work.id), ['1', '6']);
    expect(result!.assets!.last.isVideo, isTrue);
    expect(result!.images.map((file) => file.name), ['photo-0.png']);
    expect(result!.roles, isNull);
    expect(find.byType(AssetSelectionSheet), findsNothing);
    expect(find.byType(AttachmentPickerSheet), findsNothing);
  });

  testWidgets(
    'canceling asset edits keeps the original selection and media limit',
    (tester) async {
      const initial = LibraryWork(
        id: '1',
        previewUrl: '',
        isVideo: false,
        createdAt: null,
      );
      AttachmentPickerResult? result;
      await open(
        tester,
        _Gallery(),
        limit: 0,
        selectedAssets: [initial],
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const Key('attachment-source-assets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('asset-library-select-2')));
      await tester.pumpAndSettle();
      expect(find.text('最多选择1个素材'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('asset-library-select-1')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attachment-source-assets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('asset-selection-confirm')));
      await tester.pumpAndSettle();
      expect(result!.assets!.map((work) => work.id), ['1']);
      expect(result!.images, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
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

  testWidgets(
    'role confirmation preserves selected images and role order across categories',
    (tester) async {
      AttachmentPickerResult? result;
      await open(tester, _Gallery(), onResult: (value) => result = value);
      await tester.tap(find.byKey(const ValueKey('gallery:0')));
      await tester.tap(find.byKey(const Key('attachment-source-roles')));
      await tester.pumpAndSettle();
      expect(find.text('创建角色'), findsNothing);
      expect(find.text('创建项目'), findsNothing);
      expect(find.text('确认选择'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.descendant(
                of: find.byKey(const Key('role-selection-confirm')),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.getSize(find.byType(RoleSelectionSheet)).height,
        lessThanOrEqualTo(956 * .8),
      );
      await tester.tap(find.byKey(const Key('role-library-select-2')));
      await tester.tap(find.byKey(const Key('role-segment-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-library-select-21')));
      await tester.tap(find.byKey(const Key('role-selection-confirm')));
      await tester.pumpAndSettle();
      expect(result!.roles!.map((role) => role.id), ['2', '21']);
      expect(result!.images.map((image) => image.name), ['photo-0.png']);
      expect(find.byType(RoleSelectionSheet), findsNothing);
      expect(find.byType(AttachmentPickerSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceling role changes preserves the photo and initial role selection',
    (tester) async {
      AttachmentPickerResult? result;
      const role = LibraryRole(id: '1', title: 'Initial', description: '');
      await open(
        tester,
        _Gallery(),
        selectedRoles: [role],
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('gallery:0')));
      await tester.tap(find.byKey(const Key('attachment-source-roles')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-library-select-1')));
      await tester.tap(find.byKey(const Key('role-library-select-2')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.byKey(const Key('attachment-source-roles')));
      await tester.pumpAndSettle();
      final first = find.ancestor(
        of: find.byKey(const Key('role-library-select-1')),
        matching: find.byType(Semantics),
      );
      expect(tester.widget<Semantics>(first.first).properties.selected, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attachment-confirm')));
      await tester.pumpAndSettle();
      expect(result!.roles, isNull);
      expect(result!.images.map((image) => image.name), ['photo-0.png']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'role selection enforces five roles and remains usable without image slots',
    (tester) async {
      AttachmentPickerResult? result;
      await open(
        tester,
        _Gallery(),
        limit: 0,
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const Key('attachment-source-roles')));
      await tester.pumpAndSettle();
      for (var id = 1; id <= 6; id++) {
        final row = find.byKey(Key('role-library-select-$id'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('role-selection-confirm')));
      await tester.pumpAndSettle();
      expect(result!.roles!.map((role) => role.id), ['1', '2', '3', '4', '5']);
      expect(result!.images, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  for (final variant in [
    'reference',
    'compact',
    'dark-english',
    'large-text',
  ]) {
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
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
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
        size: variant == 'compact' || variant == 'large-text'
            ? const Size(320, 568)
            : const Size(440, 956),
        theme: variant == 'dark-english' || variant == 'large-text'
            ? AppTheme.dark
            : AppTheme.light,
        locale: Locale(
          variant == 'dark-english' || variant == 'large-text' ? 'en' : 'zh',
        ),
        textScale: variant == 'large-text' ? 1.8 : 1,
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
      for (final source in ['gallery', 'files', 'roles', 'assets']) {
        expect(
          tester.getSize(find.byKey(Key('attachment-source-$source'))).height,
          variant == 'large-text' ? greaterThan(94) : 94,
        );
      }
      expect(find.byKey(const Key('attachment-source-assets')), findsOneWidget);
      final confirm = tester.getRect(
        find.byKey(const Key('attachment-confirm')),
      );
      expect(confirm.height, variant == 'large-text' ? greaterThan(50) : 50);
      expect(
        confirm.bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      final first = tester.getSize(find.byKey(const ValueKey('gallery:0')));
      expect(first.width, closeTo(first.height, .01));
      if (variant == 'reference') {
        expect(first, const Size.square(128));
        expect(
          tester.getSize(find.byKey(const Key('attachment-source-gallery'))),
          const Size(94, 94),
        );
        final sourcesTop = tester.getTopLeft(
          find.byKey(const Key('attachment-sources')),
        );
        await tester.drag(
          find.byKey(const Key('attachment-photo-scroll')),
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const Key('attachment-sources'))),
          sourcesTop,
        );
        await tester.drag(
          find.byKey(const Key('attachment-photo-scroll')),
          const Offset(0, 100),
        );
        await tester.pumpAndSettle();
      }
      if (const bool.fromEnvironment('ATTACHMENT_SCREENSHOTS')) {
        await tester.ensureVisible(find.byKey(const ValueKey('gallery:0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('gallery:0')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('attachment-confirm')))
              .onPressed,
          isNotNull,
        );
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
        tester
            .widget<CustomScrollView>(
              find.byKey(const Key('attachment-photo-scroll')),
            )
            .controller!
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('attachment-source-roles')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('role-library-select-1')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final roleBoundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('attachment-screenshot')),
        );
        await tester.runAsync(() async {
          final image = await roleBoundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/popi-role-selection-$variant.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('attachment-source-assets')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(AssetSelectionSheet));
          for (var i = 1; i <= 9; i++) {
            await precacheImage(
              AssetImage(
                'assets/images/assets_works_gallery_${i.toString().padLeft(2, '0')}.png',
              ),
              context,
            );
          }
        });
        await tester.tap(find.byKey(const ValueKey('asset-library-select-1')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await roleBoundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/popi-asset-selection-$variant.png',
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
  final pickLimits = <int>[];
  final fileLimits = <int>[];
  List<XFile> pickedImages = [];
  List<XFile> pickedFiles = [];
  List<Uint8List>? thumbnails;
  GalleryAccess access = GalleryAccess.full;
  int count = 9;
  int manageCount = 0;
  int settingsCount = 0;
  int cameraCount = 0;
  bool failLoad = false;
  bool failFilePick = false;

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
  Future<List<XFile>> pickImages(int limit) async {
    pickLimits.add(limit);
    return pickedImages;
  }

  @override
  Future<List<XFile>> pickImageFiles(int limit) async {
    fileLimits.add(limit);
    if (failFilePick) throw StateError('File picker failed');
    return pickedFiles;
  }

  @override
  Future<XFile?> takePhoto() async {
    cameraCount++;
    return XFile.fromData(_png, path: 'camera.png', name: 'camera.png');
  }
}
