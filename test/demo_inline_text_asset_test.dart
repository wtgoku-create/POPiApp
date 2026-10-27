import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_media_exporter.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_inline_text_asset.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  test('supports only inline-safe text assets', () {
    expect(
      DemoInlineTextAsset.supports(
        _asset(
          'markdown',
          title: '稿件.bin',
          mimeType: ' Text/Markdown ; charset=utf-8',
        ),
      ),
      isTrue,
    );
    expect(
      DemoInlineTextAsset.supports(
        _asset('plain', title: '稿件.data', mimeType: 'TEXT/PLAIN'),
      ),
      isTrue,
    );
    expect(
      DemoInlineTextAsset.supports(
        _asset('fake', title: '稿件.md', mimeType: 'application/pdf'),
      ),
      isFalse,
    );
    expect(
      DemoInlineTextAsset.supports(
        _asset('office', title: '稿件.txt', mimeType: 'application/msword'),
      ),
      isFalse,
    );
  });

  test(
    'groups verified TXT and Markdown twins without merging unsafe pairs',
    () {
      const digest =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final image = _asset(
        'image',
        title: '参考.png',
        mimeType: 'image/png',
        kind: DemoAssetKind.image,
      );
      final txt = _asset(
        'txt',
        title: '同一稿件.txt',
        mimeType: 'text/plain',
        sha256: digest,
        sizeBytes: 42,
      );
      final pdf = _asset('pdf', title: '说明.pdf', mimeType: 'application/pdf');
      final md = _asset(
        'md',
        title: '同一稿件.md',
        mimeType: 'text/markdown',
        sha256: digest.toUpperCase(),
        sizeBytes: 42,
      );
      final noHashTxt = _asset(
        'no-hash-txt',
        title: '无摘要.txt',
        mimeType: 'text/plain',
        sizeBytes: 20,
      );
      final noHashMd = _asset(
        'no-hash-md',
        title: '无摘要.md',
        mimeType: 'text/markdown',
        sizeBytes: 20,
      );

      expect(
        DemoInlineTextAsset.groupAttachments([
          image,
          txt,
          pdf,
          md,
          noHashTxt,
          noHashMd,
        ]),
        [
          [image],
          [txt, md],
          [pdf],
          [noHashTxt],
          [noHashMd],
        ],
      );
    },
  );

  testWidgets(
    'shows source literally, reads once, and copies every byte of text',
    (tester) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      const asset = DemoAsset(
        id: 'literal',
        title: '原稿.md',
        kind: DemoAssetKind.script,
        cover: '',
        contentUrl: 'https://agent.example/api_agent/v2/assets/literal/content',
        mimeType: 'text/markdown',
        sizeBytes: 80,
      );
      const raw = '```html\n<script>alert("no")</script>\n```\n尾声 😀\n';
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _pump(tester, repository: repository, assets: const [asset]);
      expect(repository.textReads, ['literal']);
      expect(
        find.byKey(const Key('demo-inline-text-loading-literal')),
        findsOneWidget,
      );

      repository.textLoads['literal']!.complete(raw);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(raw, findRichText: true), findsOneWidget);
      expect(
        find.textContaining('<script>', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('demo-inline-text-copy-literal')));
      await tester.pump();
      expect(clipboard, raw);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(repository.textReads, ['literal']);
    },
  );

  testWidgets('shows a bundled script body without starting a remote read', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    const asset = DemoAsset(
      id: 'bundled',
      title: '本地原稿',
      kind: DemoAssetKind.script,
      cover: '',
      body: '本地原文\n第二行',
    );

    await _pump(tester, repository: repository, assets: const [asset]);

    expect(find.text('本地原文\n第二行'), findsOneWidget);
    expect(repository.textReads, isEmpty);
    expect(
      find.byKey(const Key('demo-inline-text-loading-bundled')),
      findsNothing,
    );
  });

  testWidgets('deduplicated formats keep separate original downloads', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final shares = <ShareParams>[];
    DemoMediaExporter.debugShare = (params) async => shares.add(params);
    addTearDown(() => DemoMediaExporter.debugShare = null);
    final repository = await _repository();
    addTearDown(repository.dispose);
    const digest =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final txt = _asset(
      'download-txt',
      title: '成片.txt',
      mimeType: 'text/plain',
      sha256: digest,
      sizeBytes: 4,
    );
    final md = _asset(
      'download-md',
      title: '成片.md',
      mimeType: 'text/markdown',
      sha256: digest,
      sizeBytes: 4,
    );
    repository.bytes['download-txt'] = Uint8List.fromList([1, 2, 3, 4]);
    repository.bytes['download-md'] = Uint8List.fromList([1, 2, 3, 4]);

    await _pump(tester, repository: repository, assets: [txt, md]);
    repository.textLoads['download-txt']!.complete('原文');
    await tester.pump();
    await tester.pump();

    for (final asset in [txt, md]) {
      await tester.tap(
        find.byKey(const Key('demo-inline-text-downloads-download-txt')),
      );
      await tester.pump();
      expect(find.text('TXT · 成片.txt'), findsOneWidget);
      expect(find.text('Markdown · 成片.md'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('demo-inline-text-download-${asset.id}')),
      );
      await tester.pump();
    }

    expect(shares, hasLength(2));
    expect(shares[0].fileNameOverrides, ['成片.txt']);
    expect(shares[0].files!.single.mimeType, 'text/plain');
    expect(await shares[0].files!.single.readAsBytes(), [1, 2, 3, 4]);
    expect(shares[1].fileNameOverrides, ['成片.md']);
    expect(shares[1].files!.single.mimeType, 'text/markdown');
    expect(await shares[1].files!.single.readAsBytes(), [1, 2, 3, 4]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('ignores a late response after the asset identity changes', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    final first = _asset('first', title: '第一稿.txt', mimeType: 'text/plain');
    final second = _asset('second', title: '第二稿.txt', mimeType: 'text/plain');

    await _pump(tester, repository: repository, assets: [first]);
    await _pump(tester, repository: repository, assets: [second]);
    repository.textLoads['second']!.complete('第二稿正文');
    await tester.pump();
    expect(find.text('第二稿正文'), findsOneWidget);

    repository.textLoads['first']!.complete('迟到的第一稿正文');
    await tester.pump();
    expect(find.text('第二稿正文'), findsOneWidget);
    expect(find.text('迟到的第一稿正文'), findsNothing);
  });

  testWidgets(
    'reloads from a replacement repository and ignores its predecessor',
    (tester) async {
      final firstRepository = await _repository();
      final secondRepository = await _repository();
      addTearDown(firstRepository.dispose);
      addTearDown(secondRepository.dispose);
      final asset = _asset(
        'same-source',
        title: '相同资产.txt',
        mimeType: 'text/plain',
      );

      await _pump(tester, repository: firstRepository, assets: [asset]);
      await _pump(tester, repository: secondRepository, assets: [asset]);
      expect(firstRepository.textReads, ['same-source']);
      expect(secondRepository.textReads, ['same-source']);

      secondRepository.textLoads['same-source']!.complete('新会话正文');
      await tester.pump();
      await tester.pump();
      expect(find.text('新会话正文'), findsOneWidget);

      firstRepository.textLoads['same-source']!.complete('旧会话迟到正文');
      await tester.pump();
      expect(find.text('新会话正文'), findsOneWidget);
      expect(find.text('旧会话迟到正文'), findsNothing);
    },
  );

  testWidgets(
    'long source expands, collapses, and lazily builds bounded chunks',
    (tester) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      final asset = _asset('long', title: '长文.txt', mimeType: 'text/plain');
      final source = '${List.filled(1800, '😀长行').join()}\n隐藏结尾';
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _pump(tester, repository: repository, assets: [asset]);
      repository.textLoads['long']!.complete(source);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('隐藏结尾'), findsNothing);
      expect(
        find.byKey(const Key('demo-inline-text-expand-long')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('demo-inline-text-expand-long')));
      await tester.pump();
      final chunks = find.byKey(
        const Key('demo-inline-text-content-long'),
        skipOffstage: false,
      );
      expect(chunks, findsOneWidget);
      final scroll = find.byKey(const Key('demo-inline-text-scroll-long'));
      final footer = find.byKey(const Key('demo-inline-text-footer-long'));
      expect(find.text('滚动查看全文'), findsOneWidget);
      expect(
        tester.getRect(scroll).bottom,
        lessThanOrEqualTo(tester.getRect(footer).top),
      );
      final builtChunkTexts = tester
          .widgetList<Text>(
            find.descendant(of: chunks, matching: find.byType(Text)),
          )
          .map((widget) => widget.data)
          .whereType<String>()
          .where((text) => text.contains('😀') || text.contains('隐藏结尾'))
          .toList();
      expect(builtChunkTexts, isNotEmpty);
      expect(builtChunkTexts.every((text) => text.length <= 2048), isTrue);

      final innerPosition = tester
          .widget<ListView>(scroll)
          .controller!
          .position;
      expect(innerPosition.maxScrollExtent, greaterThan(0));
      final lastChunkIndex = (source.runes.length / 1024).ceil() - 1;
      final lastChunk = find.byKey(
        ValueKey('demo-inline-text-chunk-long-$lastChunkIndex'),
      );
      for (
        var attempt = 0;
        attempt < 20 && lastChunk.evaluate().isEmpty;
        attempt++
      ) {
        innerPosition.jumpTo(innerPosition.maxScrollExtent);
        await tester.pump();
      }
      expect(lastChunk, findsOneWidget);
      expect(tester.widget<Text>(lastChunk).data, endsWith('隐藏结尾'));
      final lastChunkRect = tester.getRect(lastChunk);
      final scrollViewportRect = tester.getRect(scroll);
      expect(
        lastChunkRect.bottom,
        lessThanOrEqualTo(scrollViewportRect.bottom + 1),
      );
      expect(lastChunkRect.bottom, greaterThan(scrollViewportRect.top));
      expect(
        find.byKey(const Key('demo-inline-text-expand-long')).hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('demo-inline-text-copy-long')));
      await tester.pump();
      expect(clipboard, source);

      await tester.tap(find.byKey(const Key('demo-inline-text-expand-long')));
      await tester.pump();
      expect(find.textContaining('隐藏结尾'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a long single line offers expansion', (tester) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    final asset = _asset(
      'single-line',
      title: '单行.txt',
      mimeType: 'text/plain',
    );

    await _pump(tester, repository: repository, assets: [asset]);
    repository.textLoads['single-line']!.complete(
      List.filled(4000, '一').join(),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('demo-inline-text-expand-single-line')),
      findsOneWidget,
    );
  });

  for (final (size, scale) in [
    (const Size(320, 700), 1.5),
    (const Size(390, 800), 1.5),
    (const Size(1180, 800), 1.5),
  ]) {
    testWidgets(
      'lays out without overflow at ${size.width} and ${scale}x text',
      (tester) async {
        final repository = await _repository();
        addTearDown(repository.dispose);
        final asset = _asset(
          'layout',
          title: '特别长的中文文件名称原稿.md',
          mimeType: 'text/markdown',
        );
        await _pump(
          tester,
          repository: repository,
          assets: [asset],
          size: size,
          textScale: scale,
        );
        repository.textLoads['layout']!.complete('正文内容');
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a failed read toasts once and preserves the original download', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    final asset = _asset('failed', title: '保留原稿.txt', mimeType: 'text/plain');
    await _pump(tester, repository: repository, assets: [asset]);

    repository.textLoads['failed']!.completeError(StateError('offline'));
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 1),
    );
    expect(find.text('文件加载失败，请稍后重新打开'), findsOneWidget);
    expect(
      find.byKey(const Key('demo-inline-text-download-failed')),
      findsOneWidget,
    );
    expect(find.textContaining('重试'), findsNothing);

    await tester.pump();
    expect(find.text('文件加载失败，请稍后重新打开'), findsOneWidget);
    expect(repository.textReads, ['failed']);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('load-error callback replaces the widget fallback toast', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    final asset = _asset(
      'callback-failure',
      title: '回调失败.txt',
      mimeType: 'text/plain',
    );
    var callbacks = 0;
    await _pump(
      tester,
      repository: repository,
      assets: [asset],
      onLoadError: () => callbacks += 1,
    );

    repository.textLoads['callback-failure']!.completeError(
      StateError('offline'),
    );
    await tester.pump();
    await tester.pump();

    expect(callbacks, 1);
    expect(find.text('文件加载失败，请稍后重新打开'), findsNothing);
    expect(
      find.byKey(const Key('demo-inline-text-download-callback-failure')),
      findsOneWidget,
    );
  });
}

Future<_TextRepository> _repository() async {
  SharedPreferences.setMockInitialValues({});
  return _TextRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required _TextRepository repository,
  required List<DemoAsset> assets,
  Size size = const Size(390, 800),
  double textScale = 1,
  VoidCallback? onLoadError,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: _InlineHarness(
              assets: assets,
              repository: repository,
              onLoadError: onLoadError,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _InlineHarness extends StatefulWidget {
  const _InlineHarness({
    required this.assets,
    required this.repository,
    this.onLoadError,
  });

  final List<DemoAsset> assets;
  final DemoRepository repository;
  final VoidCallback? onLoadError;

  @override
  State<_InlineHarness> createState() => _InlineHarnessState();
}

class _InlineHarnessState extends State<_InlineHarness> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) => DemoInlineTextAsset(
    assets: widget.assets,
    repository: widget.repository,
    expanded: expanded,
    onExpandedChanged: (value) => setState(() => expanded = value),
    onLoadError: widget.onLoadError,
  );
}

class _TextRepository extends DemoRepository {
  _TextRepository(super.storage);

  final Map<String, Completer<String>> textLoads = {};
  final Map<String, Uint8List> bytes = {};
  final List<String> textReads = [];

  @override
  Future<String> readAssetText(DemoAsset asset) {
    textReads.add(asset.id);
    return textLoads.putIfAbsent(asset.id, Completer<String>.new).future;
  }

  @override
  Future<Uint8List> readAssetBytes(DemoAsset asset) async => bytes[asset.id]!;
}

DemoAsset _asset(
  String id, {
  required String title,
  required String mimeType,
  DemoAssetKind kind = DemoAssetKind.script,
  String sha256 = '',
  int sizeBytes = 10,
}) => DemoAsset(
  id: id,
  title: title,
  kind: kind,
  cover: '',
  contentUrl: 'https://agent.example/api_agent/v2/assets/$id/content',
  mimeType: mimeType,
  sha256: sha256,
  sizeBytes: sizeBytes,
);
