import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/demo_upload_file.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_assets_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double textScale = 1,
    ThemeData? theme,
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(
      left: viewPadding.left,
      top: viewPadding.top,
      right: viewPadding.right,
      bottom: viewPadding.bottom,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: theme ?? AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asset library follows the reference proportions at 390px', (
    tester,
  ) async {
    final repository = DemoRepository(storage)..restore();
    addTearDown(repository.dispose);
    await pump(tester, DemoHomePage(repository: repository));

    expect(find.byKey(const Key('demo-tab-0')), findsOneWidget);
    expect(find.byKey(const Key('demo-tab-1')), findsOneWidget);
    expect(find.byKey(const Key('demo-tab-2')), findsNothing);
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();

    final profile = find.byTooltip('个人资料');
    final upload = find.byKey(const Key('demo-create'));
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('资产'),
    );
    expect(tester.getSize(profile), const Size.square(40));
    expect(tester.getSize(upload), const Size.square(40));
    expect(tester.getCenter(profile).dx, closeTo(36, 0.1));
    expect(tester.getCenter(upload).dx, closeTo(354, 0.1));
    expect(tester.getCenter(title).dx, closeTo(195, 0.1));
    expect(
      tester.widget<Text>(title).style,
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );

    final search = find.byType(DemoSearch);
    final segments = find.byType(DemoSegments);
    final searchRect = tester.getRect(search);
    final segmentRect = tester.getRect(segments);
    expect(searchRect.left, closeTo(18, 0.1));
    expect(searchRect.right, closeTo(372, 0.1));
    expect(searchRect.height, closeTo(44, 0.1));
    expect(segmentRect.height, closeTo(36, 0.1));
    expect(segmentRect.top - searchRect.bottom, closeTo(18, 0.1));

    final cards = find.byType(DemoAssetCard);
    expect(cards, findsWidgets);
    final first = tester.getRect(cards.at(0));
    final second = tester.getRect(cards.at(1));
    expect(first.left, closeTo(18, 0.1));
    expect(first.width, closeTo(172.5, 0.1));
    expect(second.left - first.right, closeTo(9, 0.1));
    expect(first.height - first.width, closeTo(64, 0.1));
    final firstMedia = find.descendant(
      of: cards.at(0),
      matching: find.byType(AspectRatio),
    );
    expect(tester.getSize(firstMedia), const Size.square(164.5));
    final firstTitle = tester.widget<Text>(
      find.descendant(of: cards.at(0), matching: find.text('奶茶店的午后')),
    );
    expect(firstTitle.style?.fontSize, 16);
    expect(firstTitle.style?.fontWeight, FontWeight.w600);
    expect(
      tester.getSize(find.byKey(const Key('demo-bottom-tabs'))).height,
      56,
    );
    final navigation = tester.getRect(
      find.byKey(const Key('demo-bottom-tabs')),
    );
    expect(navigation.left, closeTo(18, .1));
    expect(navigation.width, closeTo(354, .1));
    for (final index in [0, 1]) {
      expect(
        tester.getSize(find.byKey(Key('demo-tab-$index'))).height,
        greaterThanOrEqualTo(44),
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('demo-tab-0')),
        matching: find.text('对话'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('demo-tab-1')),
        matching: find.text('资产'),
      ),
      findsOneWidget,
    );
    final addIcon = tester.widget<DemoIcon>(
      find.descendant(of: upload, matching: find.byType(DemoIcon)),
    );
    expect(addIcon.name, 'plus');

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(DemoAssetsView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final lastCard = tester.getRect(
      find.byKey(ValueKey(repository.assets.last.id)),
    );
    expect(lastCard.bottom, lessThanOrEqualTo(navigation.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filter, list mode, and bottom-tab navigation preserve library state',
    (tester) async {
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);
      await pump(
        tester,
        DemoHomePage(repository: repository),
        size: const Size(320, 700),
        textScale: 1.5,
      );
      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '午后轻音乐');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(DemoAssetCard),
          matching: find.text('午后轻音乐'),
        ),
        findsOneWidget,
      );
      expect(find.text('奶茶店的午后'), findsNothing);

      await tester.tap(find.byKey(const Key('demo-assets-layout-toggle')));
      await tester.pump();
      expect(find.byType(ListTile), findsOneWidget);

      await tester.tap(find.byKey(const Key('demo-tab-0')));
      await tester.pump();
      expect(
        tester
            .widget<DemoIcon>(
              find.descendant(
                of: find.byKey(const Key('demo-tab-0')),
                matching: find.byType(DemoIcon),
              ),
            )
            .color,
        AppColors.brand,
      );
      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pump();
      expect(find.byType(ListTile), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('午后轻音乐'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '午后轻音乐',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('upload sheet uses real image previews and stable file rows', (
    tester,
  ) async {
    await DemoRepository.prepareHarnessStorage(storage);
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final repository = DemoRepository.harness(storage, _NoNetworkApi(dio))
      ..restore();
    addTearDown(repository.dispose);
    final imageData = await rootBundle.load('assets/images/demo_milk_tea.png');
    final imageBytes = imageData.buffer.asUint8List(
      imageData.offsetInBytes,
      imageData.lengthInBytes,
    );
    var previewReads = 0;
    final image = DemoUploadFile(
      clientRequestId: 'preview',
      name: '奶茶店的午后.png',
      mimeType: 'image/png',
      sizeBytes: imageBytes.length,
      kind: DemoAssetKind.image,
      readBytes: () async {
        previewReads++;
        return imageBytes;
      },
    );
    final failedPreview = DemoUploadFile(
      clientRequestId: 'fallback',
      name: '损坏预览.png',
      mimeType: 'image/png',
      sizeBytes: 8,
      kind: DemoAssetKind.image,
      readBytes: () async => throw StateError('unreadable'),
    );
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDemoImport(
              context,
              repository,
              pickFiles: () async => [image, failedPreview],
            ),
            child: const Text('Import'),
          ),
        ),
      ),
      viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
    );
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(tester.getTopLeft(sheet).dy, closeTo(107, 1));
    final titleRect = tester.getRect(find.text('上传素材'));
    expect(titleRect.top - tester.getTopLeft(sheet).dy, closeTo(24, 1));
    final picker = find.byKey(const Key('demo-import-picker'));
    expect(tester.getSize(picker).height, closeTo(133, 1));
    expect(tester.getTopLeft(picker).dy - titleRect.bottom, closeTo(22, 1));

    await tester.tap(picker);
    final previewRow = find.byKey(const ValueKey('demo-upload-file-preview'));
    await _pumpUntil(
      tester,
      () => find
          .descendant(of: previewRow, matching: find.byType(Image))
          .evaluate()
          .isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(previewReads, 1);
    expect(find.text('已选择 2 个文件'), findsOneWidget);
    final fallbackRow = find.byKey(const ValueKey('demo-upload-file-fallback'));
    expect(tester.getSize(previewRow).height, greaterThanOrEqualTo(66));
    expect(tester.getSize(fallbackRow).height, greaterThanOrEqualTo(66));
    expect(
      find.descendant(of: previewRow, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fallbackRow, matching: find.byType(Image)),
      findsNothing,
    );
    expect(find.textContaining('图片 · PNG ·'), findsNWidgets(2));
    expect(find.textContaining('00:'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('demo-upload-remove-fallback')));
    await tester.pump();
    expect(find.text('已选择 1 个文件'), findsOneWidget);
    expect(find.text('损坏预览.png'), findsNothing);
    expect(previewReads, 1);
    expect(repository.assets, isEmpty);

    final footer = find.byType(FilledButton);
    expect(tester.getSize(footer).height, 44);
    expect(tester.getRect(footer).left, closeTo(18, 0.1));
    expect(tester.getRect(footer).right, closeTo(372, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview queue downsizes non-square images once and skips stale work',
    (tester) async {
      await DemoRepository.prepareHarnessStorage(storage);
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final repository = DemoRepository.harness(storage, _NoNetworkApi(dio))
        ..restore();
      addTearDown(repository.dispose);
      final imageData = await rootBundle.load(
        'assets/images/demo_milk_tea.png',
      );
      final imageBytes = imageData.buffer.asUint8List(
        imageData.offsetInBytes,
        imageData.lengthInBytes,
      );
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      var activeReads = 0;
      var maxActiveReads = 0;
      var firstReads = 0;
      var secondReads = 0;
      var removedReads = 0;
      var videoReads = 0;

      Future<Uint8List> gatedRead(
        Completer<void> gate,
        void Function() count,
      ) async {
        count();
        activeReads++;
        if (activeReads > maxActiveReads) maxActiveReads = activeReads;
        try {
          await gate.future;
          return imageBytes;
        } finally {
          activeReads--;
        }
      }

      DemoUploadFile image(
        String id,
        String name,
        Completer<void> gate,
        void Function() count,
      ) => DemoUploadFile(
        clientRequestId: id,
        name: name,
        mimeType: 'image/png',
        sizeBytes: imageBytes.length,
        kind: DemoAssetKind.image,
        readBytes: () => gatedRead(gate, count),
      );

      final first = image(
        'first-preview',
        '第一张.png',
        firstGate,
        () => firstReads++,
      );
      final second = image(
        'second-preview',
        '第二张.png',
        secondGate,
        () => secondReads++,
      );
      final removed = DemoUploadFile(
        clientRequestId: 'removed-preview',
        name: '排队后移除.png',
        mimeType: 'image/png',
        sizeBytes: imageBytes.length,
        kind: DemoAssetKind.image,
        readBytes: () async {
          removedReads++;
          return imageBytes;
        },
      );
      final video = DemoUploadFile(
        clientRequestId: 'video-no-preview',
        name: '视频.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 12,
        kind: DemoAssetKind.video,
        readBytes: () async {
          videoReads++;
          throw StateError('video previews must not read upload bytes');
        },
      );
      var pickerCalls = 0;
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDemoImport(
                context,
                repository,
                pickFiles: () async {
                  pickerCalls++;
                  return pickerCalls == 1
                      ? [first, second, removed, video]
                      : [first, second, video];
                },
              ),
              child: const Text('Import'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      final picker = find.byKey(const Key('demo-import-picker'));
      await tester.tap(picker);
      await _pumpUntil(tester, () => firstReads == 1);
      expect(secondReads, 0);
      expect(removedReads, 0);
      expect(videoReads, 0);

      final removeQueued = find.byKey(
        const ValueKey('demo-upload-remove-removed-preview'),
      );
      await tester.ensureVisible(removeQueued);
      await tester.pump();
      await tester.tap(removeQueued);
      await tester.pump();
      expect(find.text('排队后移除.png'), findsNothing);

      firstGate.complete();
      await _pumpUntil(tester, () => secondReads == 1);
      expect(activeReads, 1);
      expect(maxActiveReads, 1);
      expect(removedReads, 0);
      expect(videoReads, 0);
      secondGate.complete();
      await _pumpUntil(
        tester,
        () => find
            .descendant(
              of: find.byKey(const ValueKey('demo-upload-file-second-preview')),
              matching: find.byType(Image),
            )
            .evaluate()
            .isNotEmpty,
      );
      expect(activeReads, 0);
      expect(firstReads, 1);
      expect(secondReads, 1);
      expect(removedReads, 0);
      expect(videoReads, 0);

      final sourceDimensions = await tester.runAsync(
        () => _decodedDimensions(imageBytes),
      );
      expect(sourceDimensions, isNotNull);
      final source = sourceDimensions!;
      for (final id in const ['first-preview', 'second-preview']) {
        final preview = tester.widget<Image>(
          find.descendant(
            of: find.byKey(ValueKey('demo-upload-file-$id')),
            matching: find.byType(Image),
          ),
        );
        final memory = preview.image as MemoryImage;
        final dimensions = await tester.runAsync(
          () => _decodedDimensions(memory.bytes),
        );
        expect(dimensions, isNotNull);
        final decoded = dimensions!;
        expect(decoded.$1, lessThanOrEqualTo(132));
        expect(decoded.$2, lessThanOrEqualTo(132));
        expect(decoded.$1, greaterThan(decoded.$2));
        expect(decoded.$1 / decoded.$2, closeTo(source.$1 / source.$2, .02));
      }

      await tester.tap(picker);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      expect(pickerCalls, 2);
      expect(firstReads, 1);
      expect(secondReads, 1);
      expect(removedReads, 0);
      expect(videoReads, 0);
      expect(find.text('已选择 3 个文件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('upload layout remains usable at 320px with large text', (
    tester,
  ) async {
    await DemoRepository.prepareHarnessStorage(storage);
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final repository = DemoRepository.harness(storage, _NoNetworkApi(dio))
      ..restore();
    addTearDown(repository.dispose);
    final scriptBytes = Uint8List.fromList('script'.codeUnits);
    final files = List.generate(
      6,
      (index) => DemoUploadFile(
        clientRequestId: 'script-$index',
        name: '脚本-${index + 1}.md',
        mimeType: 'text/markdown',
        sizeBytes: scriptBytes.length,
        kind: DemoAssetKind.script,
        readBytes: () async => scriptBytes,
      ),
    );
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDemoImport(
              context,
              repository,
              pickFiles: () async => files,
            ),
            child: const Text('Import'),
          ),
        ),
      ),
      size: const Size(320, 700),
      textScale: 1.5,
      theme: AppTheme.dark,
    );
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-import-picker')));
    await tester.pumpAndSettle();

    expect(find.text('已选择 6 个文件'), findsOneWidget);
    expect(find.text('脚本-1.md'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('demo-upload-files')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    expect(find.text('脚本-6.md'), findsOneWidget);
    expect(find.text('上传到官方资产库'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NoNetworkApi extends NetworkAgentApi {
  _NoNetworkApi(super.dio);

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': <Object?>[],
    'pageInfo': {'page': page, 'pageSize': pageSize, 'pageCount': 1},
  };

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};
}

Future<(int, int)> _decodedDimensions(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return (descriptor.width, descriptor.height);
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    if (condition()) return;
  }
  fail('Condition was not reached after 80 frames');
}
