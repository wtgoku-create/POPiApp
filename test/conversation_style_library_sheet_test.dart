import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/domain/conversation_generation.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_style_library_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_network_image.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';
import 'package:popi_ai_app/shared/widgets/app_skeleton.dart';
import 'package:toastification/toastification.dart';

import 'support/session_fixtures.dart';

class _Images extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    const directory = String.fromEnvironment('STYLE_CAPTURE_ASSET_DIR');
    final index =
        int.tryParse(Uri.parse(url).pathSegments.last.split('.').first) ?? 0;
    final path = directory.isNotEmpty && index < 7
        ? '$directory/figma-style-$index.png'
        : 'assets/images/home_welcome_character.png';
    yield FileInfo(
      const LocalFileSystem().file(path),
      FileSource.Cache,
      DateTime(2099),
      url,
    );
  }
}

class _Styles extends FixtureSessionRepository {
  _Styles({int count = 7})
    : items = [
        for (var i = 0; i < count; i++)
          ConversationRoleTemplate(
            id: 'style-$i',
            title: i < 7
                ? [
                    '美漫风格',
                    'JOJO漫画风',
                    '3D动漫风格',
                    '2.5D游戏',
                    '赛璐璐风格',
                    '日漫风格',
                    '韩漫风格',
                  ][i]
                : 'Style $i',
            coverUrl: 'https://example.com/styles/$i.png',
            mediaId: 'media-$i',
          ),
      ];

  final List<ConversationRoleTemplate> items;
  Completer<List<ConversationRoleTemplate>>? pending;
  bool fail = false;
  CancelToken? token;
  final pages = <(int, int)>[];

  @override
  Future<ListPage<ConversationRoleTemplate>> roleTemplates({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    token = cancelToken;
    pages.add((page, pageSize));
    if (fail) throw StateError('offline');
    return fixturePage(
      await (pending?.future ?? Future.value(items)),
      page: page,
      pageSize: pageSize,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Styles repository, {
  List<ConversationRoleTemplate?>? results,
  GlobalKey? capture,
  double scale = 1,
  bool dark = false,
  String selectedId = 'style-0',
  ConversationRoleTemplate? selectedTemplate,
}) async {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    MaterialApp(
      theme: const String.fromEnvironment('CONVERSATION_CAPTURE_FONT').isEmpty
          ? theme
          : theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'StyleCapture'),
            ),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: capture, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final selection = await AppSheet.show<ConversationRoleTemplate>(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
                shape: ConversationStyleLibrarySheet.shape,
                builder: (_) => ConversationStyleLibrarySheet(
                  repository: repository,
                  selectedId: selectedId,
                  selectedTemplate: selectedTemplate,
                ),
              );
              results?.add(selection);
            },
            child: const Text('Open styles'),
          ),
        ),
      ),
    ),
  );
  final context = tester.element(find.text('Open styles'));
  await tester.runAsync(() async {
    await Future.wait([
      for (final template in repository.items.take(8))
        precacheImage(AppImageCache.provider(template.coverUrl), context),
      precacheImage(
        const AssetImage('assets/images/style_unrestricted.png'),
        context,
      ),
    ]);
  });
  await tester.tap(find.text('Open styles'));
  if (repository.pending != null) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return;
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const path = String.fromEnvironment('CONVERSATION_CAPTURE_FONT');
    if (path.isNotEmpty) {
      await (FontLoader(
        'StyleCapture',
      )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() => AppImageCache.debugCacheManager = _Images());
  tearDown(() {
    AppImageCache.debugCacheManager = null;
    toastification.dismissAll(delayForAnimation: false);
    PaintingBinding.instance.imageCache.clear();
  });

  for (final size in [
    const Size(440, 956),
    const Size(390, 844),
    const Size(320, 568),
    const Size(1280, 900),
  ]) {
    testWidgets('style library follows Figma at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await _pump(
        tester,
        _Styles(),
        capture: capture,
        scale: size.width == 320 ? 1.5 : 1,
        dark: size.width == 320,
      );
      final grid = tester.widget<GridView>(
        find.byKey(const Key('conversation-style-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, size.width == 320 ? 2 : 4);
      final confirm = find.byKey(const Key('conversation-style-confirm'));
      expect(
        tester.getBottomRight(confirm).dy,
        lessThanOrEqualTo(size.height - 20),
      );
      expect(find.text('风格库'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
        await tester.runAsync(() async {
          final pixels =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/conversation-style-library-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
    });
  }

  testWidgets(
    'style changes require confirmation and dismissal preserves the original choice',
    (tester) async {
      final results = <ConversationRoleTemplate?>[];
      final repository = _Styles();
      await _pump(tester, repository, results: results);
      await tester.tap(find.byKey(const ValueKey('role-template:style-1')));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(find.byType(ConversationStyleLibrarySheet), findsOneWidget);
      Navigator.of(
        tester.element(find.byType(ConversationStyleLibrarySheet)),
      ).pop();
      await tester.pumpAndSettle();
      expect(results, [null]);
      await tester.tap(find.text('Open styles'));
      await tester.pumpAndSettle();
      final original = tester.widget<TextButton>(
        find.byKey(const ValueKey('role-template:style-0')),
      );
      expect(
        original.style!.backgroundColor!.resolve({}),
        AppColors.brand.withValues(alpha: .05),
      );
      await tester.tap(find.byKey(const ValueKey('role-template:style-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-style-confirm')));
      await tester.pumpAndSettle();
      expect(results.last!.id, 'style-1');
      expect(results.last!.mediaId, 'media-1');
      await tester.tap(find.text('Open styles'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('role-template:')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-style-confirm')));
      await tester.pumpAndSettle();
      expect(results.last!.id, isEmpty);
      expect(results.last!.mediaId, isNull);
    },
  );

  testWidgets(
    'long style libraries build on demand and keep the heading and confirmation fixed',
    (tester) async {
      final repository = _Styles(count: 100);
      await _pump(tester, repository);
      expect(repository.pages, [(1, 20)]);
      expect(
        find.byKey(const ValueKey('role-template:style-99')),
        findsNothing,
      );
      final heading = tester.getTopLeft(find.text('风格库'));
      final confirm = find.byKey(const Key('conversation-style-confirm'));
      final confirmPosition = tester.getTopLeft(confirm);
      await tester.drag(
        find.byKey(const Key('conversation-style-grid')),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('风格库')), heading);
      expect(tester.getTopLeft(confirm), confirmPosition);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('role-template:style-99')),
        400,
        scrollable: find.descendant(
          of: find.byKey(const Key('conversation-style-grid')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.pages, [(1, 20), (2, 20), (3, 20), (4, 20), (5, 20)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a selected style on a later page can be confirmed without prefetching',
    (tester) async {
      final repository = _Styles(count: 100);
      final results = <ConversationRoleTemplate?>[];
      final selected = repository.items.last;
      await _pump(
        tester,
        repository,
        results: results,
        selectedId: selected.id,
        selectedTemplate: selected,
      );
      await tester.tap(find.byKey(const Key('conversation-style-confirm')));
      await tester.pumpAndSettle();
      expect(repository.pages, [(1, 20)]);
      expect(results.single, same(selected));
    },
  );

  testWidgets(
    'loading uses grid skeletons and dismissal cancels the request without a toast',
    (tester) async {
      final repository = _Styles()..pending = Completer();
      await _pump(tester, repository);
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('conversation-style-confirm')),
            )
            .onPressed,
        isNull,
      );
      Navigator.of(
        tester.element(find.byType(ConversationStyleLibrarySheet)),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(repository.token!.isCancelled, isTrue);
      repository.pending!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'load failure shows one toast and keeps the existing confirmation UX',
    (tester) async {
      final repository = _Styles()..fail = true;
      await _pump(tester, repository);
      expect(find.byType(AppSkeleton), findsNothing);
      expect(find.text('风格库'), findsOneWidget);
      expect(find.text('不限制风格'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
    },
  );
}
