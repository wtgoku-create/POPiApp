import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/demo_upload_file.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_bot_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

const _captureEnabled = bool.fromEnvironment('CAPTURE_CHAT_ATTACHMENTS');
final _captureKey = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureEnabled) return;
  final unmatched = find.text('未匹配');
  if (unmatched.evaluate().length == 1) {
    final paragraph = tester.renderObject<RenderParagraph>(unmatched);
    final span = paragraph.text as TextSpan;
    paragraph.text = TextSpan(
      text: span.text,
      children: span.children,
      style: span.style?.copyWith(fontFamily: 'AttachmentCapture'),
    );
  }
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/chat-device-attachments/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  late Dio dio;
  late _AttachmentApi api;
  late DemoRepository repository;

  setUpAll(() async {
    if (!_captureEnabled) return;
    await (FontLoader('AttachmentCapture')..addFont(
          File(
            '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() async {
    AppBotAvatar.debugAnimationsEnabled = false;
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
    api = _AttachmentApi(dio);
    repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 0,
    )..restore();
    await repository.refreshSessions();
  });

  tearDown(() {
    AppBotAvatar.debugAnimationsEnabled = true;
    repository.dispose();
    dio.close(force: true);
    toastification.dismissAll(delayForAnimation: false);
  });

  Future<void> pump(
    WidgetTester tester, {
    Future<List<DemoUploadFile>> Function()? pickFiles,
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ButtonStyle captureButtonStyle(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStatePropertyAll(
            (style?.textStyle?.resolve({}) ??
                    AppTheme.light.textTheme.labelLarge!)
                .copyWith(fontFamily: 'AttachmentCapture'),
          ),
        );
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: ProviderScope(
          child: ToastificationWrapper(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: !_captureEnabled
                  ? AppTheme.light
                  : AppTheme.light.copyWith(
                      scaffoldBackgroundColor: AppColors.profileBackground,
                      appBarTheme: AppTheme.light.appBarTheme.copyWith(
                        backgroundColor: AppColors.profileBackground,
                      ),
                      textTheme: AppTheme.light.textTheme.apply(
                        fontFamily: 'AttachmentCapture',
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: captureButtonStyle(
                          AppTheme.light.textButtonTheme.style,
                        ),
                      ),
                      filledButtonTheme: FilledButtonThemeData(
                        style: captureButtonStyle(
                          AppTheme.light.filledButtonTheme.style,
                        ),
                      ),
                      outlinedButtonTheme: OutlinedButtonThemeData(
                        style: captureButtonStyle(
                          AppTheme.light.outlinedButtonTheme.style,
                        ),
                      ),
                    ),
              locale: const Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: DemoChatPage(
                repository: repository,
                sessionId: 'attachment-session',
                pickAttachmentFiles: pickFiles,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    for (
      var attempt = 0;
      attempt < 20 && repository.isSessionLoading('attachment-session');
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    expect(repository.isSessionLoading('attachment-session'), isFalse);
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (condition()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    fail('Condition was not reached');
  }

  testWidgets(
    'device upload joins the draft and double tap opens the attachment preview',
    (tester) async {
      final file = _imageFile('device-image', '角色参考.png');
      await pump(tester, pickFiles: () async => [file]);
      final composer = tester.widget<PopiMessageComposer>(
        find.byType(PopiMessageComposer),
      );
      await composer.controller.setText('请参考这张图');
      await tester.pump();

      tester
          .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
          .onAttachment();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('从设备上传'), findsOneWidget);
      expect(find.text('从素材库选择'), findsOneWidget);
      await _capture(tester, 'source-picker');
      await tester.tap(find.byKey(const Key('demo-attachment-device')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const Key('demo-import-picker')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('角色参考.png'), findsOneWidget);

      await tester.tap(find.text('上传到官方资产库'));
      await pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('popi-selected-asset-asset-device-image'))
            .evaluate()
            .isNotEmpty,
      );

      expect(api.uploadIds, ['device-image']);
      expect(repository.assets.single.title, '角色参考.png');
      expect(composer.controller.markdown, '请参考这张图');
      expect(find.byKey(const Key('popi-selected-assets')), findsOneWidget);

      final preview = find.byKey(
        const ValueKey('popi-preview-selected-asset-asset-device-image'),
      );
      final previewRect = tester.getRect(preview);
      final previewPoint = previewRect.bottomLeft + const Offset(20, -20);
      await tester.tapAt(previewPoint);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('asset-preview-gallery')), findsNothing);
      await tester.tapAt(previewPoint);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(previewPoint);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('asset-preview-gallery')), findsOneWidget);
      expect(composer.controller.markdown, '请参考这张图');
      final closingPreview = tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 700));
      await closingPreview;
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('library selection uses the same composer attachment strip', (
    tester,
  ) async {
    await pump(tester);
    final asset = await repository.uploadFile(
      _scriptFile('library-script', '分镜.md'),
    );
    await tester.pump();
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    await composer.controller.setText('草稿不应丢失');

    tester
        .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
        .onAttachment();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('demo-attachment-library')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(ValueKey(asset.id)));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(ValueKey('popi-selected-asset-${asset.id}')),
      findsOneWidget,
    );
    expect(find.text('分镜.md'), findsOneWidget);
    await _capture(tester, 'selected-script');
    expect(composer.controller.markdown, '草稿不应丢失');
    await tester.tap(find.byTooltip('移除资产'));
    await tester.pump();
    expect(find.byKey(const Key('popi-selected-assets')), findsNothing);
    expect(composer.controller.markdown, '草稿不应丢失');
  });

  testWidgets('closing the attachment source chooser keeps the draft', (
    tester,
  ) async {
    await pump(tester);
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    await composer.controller.setText('取消后仍在');
    tester
        .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
        .onAttachment();
    await tester.pump(const Duration(milliseconds: 600));
    Navigator.of(
      tester.element(find.byKey(const Key('demo-attachment-library'))),
    ).pop();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('popi-selected-assets')), findsNothing);
    expect(composer.controller.markdown, '取消后仍在');
  });

  for (final (code, expected) in [
    ('message_attachment_unsupported', '当前助手暂不支持读取这类附件，请选择图片或文本脚本。'),
    ('message_attachment_not_found', '附件已不存在，请移除后重新上传。'),
    ('message_attachment_too_large', '本次附件总大小过大，请减少附件或选择较小的文件。'),
    ('message_attachment_limit', '附件数量过多或包含重复项，请调整后再发送。'),
    ('message_attachment_invalid', '附件无法读取或已发生变化，请重新上传。'),
  ]) {
    testWidgets(
      '$code gives an actionable toast and preserves the send draft',
      (tester) async {
        api.sendErrorCode = code;
        await pump(tester);
        final asset = await repository.uploadFile(
          _scriptFile('error-script', '分镜.md'),
        );
        await tester.pump();
        var composer = tester.widget<PopiMessageComposer>(
          find.byType(PopiMessageComposer),
        );
        await composer.controller.setText('请参考附件，保留这个草稿');
        composer.onAttachment();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.byKey(const Key('demo-attachment-library')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.byKey(ValueKey(asset.id)));
        await tester.pump(const Duration(milliseconds: 600));
        composer = tester.widget<PopiMessageComposer>(
          find.byType(PopiMessageComposer),
        );
        api.sendGate = Completer<void>();
        composer.onSubmitted(composer.controller.markdown);
        await pumpUntil(tester, () => api.sentMediaIds != null);
        api.sendGate!.complete();
        await pumpUntil(tester, () {
          final current = tester.widget<PopiMessageComposer>(
            find.byType(PopiMessageComposer),
          );
          return api.sentMediaIds != null &&
              !current.sending &&
              find.text(expected).evaluate().isNotEmpty;
        });
        composer = tester.widget<PopiMessageComposer>(
          find.byType(PopiMessageComposer),
        );
        expect(api.sentMediaIds, [asset.id]);
        expect(composer.controller.markdown, '请参考附件，保留这个草稿');
        expect(
          find.byKey(ValueKey('popi-selected-asset-${asset.id}')),
          findsOneWidget,
        );
        expect(find.text(expected), findsOneWidget);
        expect(find.text('网络请求失败，请稍后重试'), findsNothing);
        expect(
          find.textContaining('DO_NOT_RENDER_SERVER_DETAIL'),
          findsNothing,
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(milliseconds: 700));
      },
    );
  }
}

class _AttachmentApi extends NetworkAgentApi {
  _AttachmentApi(super.dio);

  final uploadIds = <String>[];
  final uploaded = <Map<String, Object?>>[];
  String sendErrorCode = 'REQUEST_FAILED';
  List<String>? sentMediaIds;
  Completer<void>? sendGate;

  @override
  Future<Map<String, dynamic>> sendSessionMessage(
    String id, {
    required String clientRequestId,
    required String text,
    String? taskId,
    List<String>? mediaIds,
    List<String>? contextRoleIds,
    CancelToken? cancelToken,
  }) async {
    sentMediaIds = mediaIds;
    if (sendGate case final gate?) await gate.future;
    throw AgentApiException(
      code: sendErrorCode,
      statusCode: 400,
      message: 'DO_NOT_RENDER_SERVER_DETAIL',
    );
  }

  Map<String, Object?> get record => {
    'id': 'attachment-session',
    'title': '附件测试',
    'kind': 'conversation',
    'revision': 1,
    'createdAt': '2026-10-25T00:00:00.000Z',
    'updatedAt': '2026-10-25T00:00:00.000Z',
    'archived': false,
    'bindingStatus': 'ready',
    'configurationStatus': 'configured',
    'configRevision': 1,
    'configuration': {
      'members': ['popi'],
      'roles': <String>[],
      'capabilities': <String>[],
      'memberNames': {'popi': 'Watt'},
      'memberInstructions': <String, String>{},
      'memberAvatars': <String, String>{},
      'memberColors': <String, int>{},
      'memberCapabilities': <String, Object?>{},
      'workMode': 'onDemand',
      'activeMemberId': 'popi',
    },
  };

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [record],
    'pageInfo': {'page': 1, 'pageSize': 20, 'pageCount': 1, 'total': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => {
    'session': record,
    'lastSeq': 0,
    'messages': <Object?>[],
    'mediaJobs': <Object?>[],
    'runs': <Object?>[],
    'assets': <Object?>[],
  };

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': uploaded};

  @override
  Future<Map<String, dynamic>> uploadAsset({
    required String clientRequestId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    CancelToken? cancelToken,
  }) async {
    uploadIds.add(clientRequestId);
    final kind = mimeType == 'text/markdown' ? 'script' : 'image';
    final asset = <String, Object?>{
      'id': 'asset-$clientRequestId',
      'title': name,
      'kind': kind,
      'sessionId': null,
      'mimeType': mimeType,
      'sha256': 'hash-$clientRequestId',
      'sizeBytes': bytes.length,
      'width': 32,
      'height': 32,
      'contentUrl': '/api_agent/v2/assets/asset-$clientRequestId/content',
    };
    uploaded.add(asset);
    return {'asset': asset};
  }
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

DemoUploadFile _scriptFile(String id, String name) {
  final bytes = Uint8List.fromList('# scene'.codeUnits);
  return DemoUploadFile(
    clientRequestId: id,
    name: name,
    mimeType: 'text/markdown',
    sizeBytes: bytes.length,
    kind: DemoAssetKind.script,
    readBytes: () async => bytes,
  );
}
