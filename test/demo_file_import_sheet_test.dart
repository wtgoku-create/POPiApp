import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  late PreferencesStorage storage;
  late Dio dio;
  late _ImportApi api;
  late DemoRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
    api = _ImportApi(dio);
    repository = DemoRepository.harness(storage, api)..restore();
  });

  tearDown(() {
    repository.dispose();
    dio.close(force: true);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(375, 760),
    double textScale = 1,
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
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: child,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Widget launcher(
    Future<List<DemoUploadFile>> Function() pickFiles, {
    ValueChanged<List<DemoAsset>>? onImported,
  }) => Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => showDemoImport(
          context,
          repository,
          pickFiles: pickFiles,
          onImported: onImported,
        ),
        child: const Text('Import'),
      ),
    ),
  );

  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (condition()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      if (condition()) return;
    }
    fail('Condition was not reached after 40 frames');
  }

  testWidgets(
    'real files show names and sizes; cancel, error, and removal keep the draft',
    (tester) async {
      final image = _imageFile('image-request', '南极.png');
      final script = _scriptFile('script-request', '分镜.md', '# scene');
      var pickCall = 0;
      Future<List<DemoUploadFile>> pickFiles() async => switch (pickCall++) {
        0 => [image, script],
        1 => const [],
        _ => throw StateError('picker unavailable'),
      };
      await pump(
        tester,
        launcher(pickFiles),
        size: const Size(320, 700),
        textScale: 1.5,
      );

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-import-picker')));
      await tester.pumpAndSettle();

      expect(find.text('南极.png'), findsOneWidget);
      expect(find.text('分镜.md'), findsOneWidget);
      expect(find.textContaining('字节'), findsNWidgets(2));
      expect(find.text('奶茶店的午后'), findsNothing);
      expect(find.text('已选择 2 个文件'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('demo-import-picker')));
      await tester.pump();
      expect(find.text('已选择 2 个文件'), findsOneWidget);

      await tester.tap(find.byKey(const Key('demo-import-picker')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('已选择 2 个文件'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('demo-upload-remove-script-request')),
      );
      await tester.pump();
      expect(find.text('已选择 1 个文件'), findsOneWidget);
      expect(find.text('分镜.md'), findsNothing);
      expect(repository.assets, isEmpty);
    },
  );

  testWidgets('closing an idle sheet leaves the library unchanged', (
    tester,
  ) async {
    await pump(tester, launcher(() async => [_imageFile('one', 'one.png')]));
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-import-picker')));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('上传素材'), findsNothing);
    expect(repository.assets, isEmpty);
  });

  testWidgets(
    'mixed picker error keeps valid files and reselection deduplicates',
    (tester) async {
      final accepted = _imageFile('stable-request', 'valid.png');
      var pickCall = 0;
      Future<List<DemoUploadFile>> pickFiles() async {
        if (pickCall++ == 0) {
          throw DemoUploadException(
            'UNSUPPORTED_TYPE',
            acceptedFiles: [accepted],
          );
        }
        return [accepted];
      }

      await pump(tester, launcher(pickFiles));
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-import-picker')));
      await tester.pump();
      expect(find.text('valid.png'), findsOneWidget);
      expect(find.text('已选择 1 个文件'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('demo-import-picker')));
      await tester.pump();
      expect(find.text('valid.png'), findsOneWidget);
      expect(find.text('已选择 1 个文件'), findsOneWidget);
    },
  );

  testWidgets(
    'partial success remains marked and retry skips the successful file',
    (tester) async {
      final first = _imageFile('first-request', 'first.png');
      final second = _scriptFile('second-request', 'second.md', 'second');
      api.failOnceRequestId = second.clientRequestId;
      final imported = <List<DemoAsset>>[];
      await pump(
        tester,
        launcher(() async => [first, second], onImported: imported.add),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-import-picker')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('上传到官方资产库'));
      await tester.pump();
      await pumpUntil(tester, () => api.requestIds.length == 2);
      await tester.pump();
      expect(api.requestIds, ['first-request', 'second-request']);
      expect(repository.assets.map((asset) => asset.title), ['first.png']);
      expect(find.text('已上传'), findsOneWidget);
      expect(find.text('已选择 2 个文件'), findsOneWidget);
      expect(imported, hasLength(1));
      expect(imported.single.single.title, 'first.png');

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('上传素材'), findsOneWidget);

      await tester.tap(find.text('上传到官方资产库'));
      await tester.pump();
      await pumpUntil(tester, () => api.requestIds.length == 3);
      await pumpUntil(tester, () => find.text('上传素材').evaluate().isEmpty);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.requestIds, [
        'first-request',
        'second-request',
        'second-request',
      ]);
      expect(repository.assets.map((asset) => asset.title).toSet(), {
        'first.png',
        'second.md',
      });
      expect(imported, hasLength(2));
      expect(imported.expand((assets) => assets).map((asset) => asset.title), [
        'first.png',
        'second.md',
      ]);
      expect(find.text('上传素材'), findsNothing);
    },
  );

  testWidgets(
    'upload busy state blocks back, picker, removal, and duplicate submit',
    (tester) async {
      final first = _imageFile('first-request', 'first.png');
      final second = _scriptFile('second-request', 'second.md', 'second');
      final gate = Completer<void>();
      api.uploadGate = gate;
      await pump(tester, launcher(() async => [first, second]));
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-import-picker')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('上传到官方资产库'));
      await tester.pump();
      expect(api.requestIds, ['first-request']);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(const Key('demo-import-picker')),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('demo-upload-remove-second-request')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('上传素材'), findsOneWidget);
      expect(api.requestIds, ['first-request']);

      gate.complete();
      await tester.pump();
      await pumpUntil(tester, () => api.requestIds.length == 2);
      await pumpUntil(tester, () => find.text('上传素材').evaluate().isEmpty);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.requestIds, ['first-request', 'second-request']);
      expect(repository.assets, hasLength(2));
      expect(find.text('上传素材'), findsNothing);
    },
  );

  testWidgets('asset tab keeps profile left and moves upload to the right', (
    tester,
  ) async {
    for (final size in const [Size(320, 700), Size(375, 760)]) {
      await pump(tester, DemoHomePage(repository: repository), size: size);
      final profile = find.byTooltip('个人资料');
      expect(profile, findsOneWidget);
      expect(
        find.descendant(of: profile, matching: find.byType(Image)),
        findsOneWidget,
      );

      final chatCreate = find.byKey(const Key('demo-create'));
      expect(tester.getCenter(profile).dx, lessThan(size.width * .25));
      expect(tester.getCenter(chatCreate).dx, greaterThan(size.width * .75));

      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final upload = find.byKey(const Key('demo-create'));
      final title = find.text('资产');
      expect(tester.getCenter(profile).dx, lessThan(size.width * .25));
      expect(tester.getCenter(upload).dx, greaterThan(size.width * .75));
      expect(tester.getCenter(title).dx, closeTo(size.width / 2, 1));

      await tester.tap(upload);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('上传素材'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('上传素材'), findsNothing);

      await tester.tap(find.byKey(const Key('demo-tab-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}

class _ImportApi extends NetworkAgentApi {
  _ImportApi(super.dio);

  final requestIds = <String>[];
  String? failOnceRequestId;
  Completer<void>? uploadGate;
  final _attempts = <String, int>{};

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
  Future<Map<String, dynamic>> uploadAsset({
    required String clientRequestId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    CancelToken? cancelToken,
  }) async {
    requestIds.add(clientRequestId);
    final attempts = (_attempts[clientRequestId] ?? 0) + 1;
    _attempts[clientRequestId] = attempts;
    final gate = uploadGate;
    if (gate != null) {
      uploadGate = null;
      await gate.future;
    }
    if (clientRequestId == failOnceRequestId && attempts == 1) {
      throw StateError('upload failed');
    }
    final kind = switch (mimeType) {
      'image/png' || 'image/jpeg' || 'image/webp' => 'image',
      'video/mp4' => 'video',
      'text/plain' || 'text/markdown' => 'script',
      'audio/mpeg' || 'audio/wav' || 'audio/mp4' => 'audio',
      _ => throw StateError('unsupported MIME'),
    };
    return {
      'asset': {
        'id': 'asset-$clientRequestId',
        'title': name,
        'kind': kind,
        'sessionId': null,
        'mimeType': mimeType,
        'sha256': 'hash-$clientRequestId',
        'sizeBytes': bytes.length,
        'width': kind == 'image' ? 32 : 0,
        'height': kind == 'image' ? 32 : 0,
        'contentUrl': '/api_agent/v2/assets/asset-$clientRequestId/content',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};
}

DemoUploadFile _imageFile(String id, String name) {
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
  return DemoUploadFile(
    clientRequestId: id,
    name: name,
    mimeType: 'image/png',
    sizeBytes: bytes.length,
    kind: DemoAssetKind.image,
    readBytes: () async => bytes,
  );
}

DemoUploadFile _scriptFile(String id, String name, String content) {
  final bytes = Uint8List.fromList(utf8.encode(content));
  return DemoUploadFile(
    clientRequestId: id,
    name: name,
    mimeType: 'text/markdown',
    sizeBytes: bytes.length,
    kind: DemoAssetKind.script,
    readBytes: () async => bytes,
  );
}
