import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:dio/dio.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';
import 'package:popi_ai_app/shared/widgets/app_bot_avatar.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';

import 'support/project_fixtures.dart';
import 'support/session_fixtures.dart';
import 'support/role_library_fixtures.dart';
import 'support/work_library_fixtures.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';

void main() {
  testWidgets(
    'gallery uploads show progress, retry failures and reuse media on send',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _UploadSessionRepository();
      final container = ProviderContainer(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: 'User', email: ''));
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _LocalizedTestApp(
            theme: AppTheme.light,
            home: SessionPage(
              initialPrompt: 'Create content',
              pickImages: () async => [
                XFile.fromData(bytes, name: 'photo.png'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('添加附件'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attachment-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.uploads, hasLength(1));
      expect(repository.sentMedia, isEmpty);
      expect(find.byKey(const Key('popi-selected-image-0')), findsOneWidget);
      final send = find.byKey(const Key('popi-send-button'));
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      repository.progress!(50, 100);
      await tester.pump();
      expect(find.text('50%'), findsOneWidget);
      expect(
        tester
            .getRect(find.byKey(const Key('popi-image-upload-progress-0')))
            .overlaps(
              tester.getRect(
                find.byKey(const Key('popi-remove-selected-image-0')),
              ),
            ),
        isFalse,
      );
      repository.progress!(100, 100);
      await tester.pump();
      expect(find.text('处理中'), findsOneWidget);
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      repository.uploads.single.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('上传失败'), findsOneWidget);
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      await tester.tap(find.byKey(const Key('popi-image-upload-retry-0')));
      await tester.pump();
      expect(repository.uploads, hasLength(2));
      repository.uploads.last.complete('media-42');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('popi-image-upload-ready-0')),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
      // Failed message sends must retain the uploaded attachment for retry.
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(repository.sentMedia.single, ['media-42']);
      expect(find.text('请求失败，请稍后重试'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ConversationTimeline),
          matching: find.text('请求失败，请稍后重试'),
        ),
        findsNothing,
      );
      expect(find.byTooltip('重试'), findsNothing);
      expect(
        find.byKey(const Key('popi-image-upload-ready-0')),
        findsOneWidget,
      );
      repository.failSend = false;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(repository.sentMedia.last, ['media-42']);
      expect(repository.uploads, hasLength(2));
      expect(find.byKey(const Key('popi-selected-images')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    },
  );

  test('message composer controller exports markdown', () async {
    final controller = PopiMessageComposerController(initialText: '初始内容');
    addTearDown(controller.dispose);

    expect(controller.markdown, '初始内容');

    await controller.setText('做一个新IP');

    expect(controller.markdown, '做一个新IP');
  });

  testWidgets(
    'removing images and switching accounts cancel pending gallery uploads',
    (tester) async {
      final repository = _UploadSessionRepository();
      final container = ProviderContainer(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: 'User', email: ''));
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _LocalizedTestApp(
            theme: AppTheme.dark,
            home: SessionPage(
              initialPrompt: 'Create content',
              pickImages: () async => [
                XFile.fromData(bytes, path: 'first.png', name: 'first.png'),
                XFile.fromData(bytes, path: 'second.png', name: 'second.png'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('添加附件'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attachment-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.uploads, hasLength(2));
      await tester.tap(find.byKey(const Key('popi-remove-selected-image-0')));
      await tester.pump();
      expect(repository.uploadTokens.first.isCancelled, isTrue);
      expect(repository.uploadTokens.last.isCancelled, isFalse);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '2', name: 'Other user', email: ''));
      await tester.pumpAndSettle();
      expect(repository.uploadTokens.last.isCancelled, isTrue);
      repository.uploads.first.complete('late');
      repository.uploads.last.completeError(StateError('cancelled'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popi-selected-images')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('message composer controller keeps a valid selection on dismiss', () {
    final controller = PopiMessageComposerController(initialText: '输入内容');
    addTearDown(controller.dispose);
    controller.textController.selection = const TextSelection.collapsed(
      offset: 2,
    );

    controller.dismissKeyboard();

    expect(controller.textController.selection.extentOffset, 2);
  });

  for (final source in ['files', 'roles', 'assets']) {
    testWidgets('composer attachment source $source is pending', (
      tester,
    ) async {
      final repository = _RoleSessionRepository();
      final container = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          userProvider.overrideWith(LibraryTestUserController.new),
          dioProvider.overrideWithValue(roleLibraryDio()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _LocalizedTestApp(
            theme: AppTheme.light,
            home: SessionPage(pickImages: () async => []),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('添加附件'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('attachment-source-$source')));
      await tester.pumpAndSettle();
      expect(find.text('功能待开发'), findsOneWidget);
      expect(find.byKey(const Key('attachment-confirm')), findsOneWidget);
      expect(find.byKey(const Key('role-selection-confirm')), findsNothing);
      expect(find.byKey(const Key('asset-selection-confirm')), findsNothing);
      expect(repository.sentRoles, isEmpty);
      expect(repository.sentMedia, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byTooltip('添加附件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(440, 956),
    const Size(320, 568),
    const Size(1280, 900),
  ]) {
    testWidgets('session welcome adapts to the keyboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final container = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(
            FixtureSessionRepository(),
          ),
          projectRepositoryProvider.overrideWithValue(
            FixtureProjectRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(safeAreaInsetsProvider.notifier)
          .update(const EdgeInsets.only(top: 52, bottom: 20));
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: 'User', email: ''));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _LocalizedTestApp(
            theme: AppTheme.light,
            home: const SessionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mascot = find.byKey(const Key('popi-welcome-mascot'));
      final composer = find.byKey(const Key('popi-message-composer'));
      final input = find.byKey(const Key('popi-message-input'));
      expect(find.text('嗨，用户～'), findsOneWidget);
      expect(find.text('告诉我，你现在最想做什么？'), findsOneWidget);
      expect(find.byKey(const Key('home-membership-entry')), findsNothing);
      expect(tester.getSize(mascot), const Size(150, 150));
      expect(tester.getSize(composer).height, 60);
      expect(
        tester.getRect(mascot).bottom,
        lessThan(tester.getRect(composer).top),
      );
      expect(tester.getSize(composer).width, lessThanOrEqualTo(640));
      final initialMascotTop = tester.getTopLeft(mascot).dy;
      await tester.tap(input);
      tester.testTextInput.enterText('我想制作一个可爱的角色');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 600 ? 240 : 345,
      );
      await tester.pumpAndSettle();
      expect(find.text('嗨，用户～'), findsNothing);
      expect(find.text('告诉我，你现在最想做什么？'), findsNothing);
      expect(find.text('AI生成结果可能有误，仅供参考'), findsNothing);
      expect(tester.getSize(composer).height, 105);
      expect(find.byKey(const Key('popi-model-parameters')), findsOneWidget);
      expect(find.byKey(const Key('popi-send-button')), findsOneWidget);
      expect(
        tester.getRect(mascot).bottom,
        lessThan(tester.getRect(composer).top),
      );
      expect(
        tester.getBottomRight(composer).dy,
        closeTo(size.height - tester.view.viewInsets.bottom - 10, 1),
      );
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(
        tester.widget<ExtendedTextField>(input).controller!.text,
        '我想制作一个可爱的角色',
      );
      expect(find.text('嗨，用户～'), findsOneWidget);
      // Clearing the unfocused controller also collapses the composer.
      tester.widget<ExtendedTextField>(input).controller!.clear();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(mascot).dy, closeTo(initialMascotTop, 1));
      await tester.tap(find.byTooltip('打开导航'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popi-navigation-drawer')), findsOneWidget);
      expect(find.byKey(const Key('drawer-new-session')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('renders home content in English', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          home: const SessionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Tell me, what would you like to create?'),
      findsOneWidget,
    );
    expect(find.text('Hi there!'), findsOneWidget);
    expect(find.text('Say something to POPi...'), findsOneWidget);
    expect(find.byTooltip('Open navigation'), findsOneWidget);
  });

  testWidgets('collapsing the focused editor does not read dirty text layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: const SessionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 300));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }

    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      60,
    );
  });

  testWidgets('picks at most five images inside the composer and removes one', (
    tester,
  ) async {
    final imageBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final images = List.generate(
      6,
      (index) => XFile.fromData(
        imageBytes,
        path: 'picked-$index.png',
        name: 'picked-$index.png',
        mimeType: 'image/png',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: SessionPage(pickImages: () async => images),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('相册'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attachment-confirm')));
    await tester.pumpAndSettle();

    final imageStrip = find.byKey(const Key('popi-selected-images'));
    expect(imageStrip, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('popi-message-composer')),
        matching: imageStrip,
      ),
      findsOneWidget,
    );
    for (var index = 0; index < 5; index++) {
      expect(find.byKey(Key('popi-selected-image-$index')), findsOneWidget);
    }
    expect(find.byKey(const Key('popi-selected-image-5')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      60,
    );

    final firstImage = find.byKey(const Key('popi-selected-image-0'));
    final firstRemoveButton = find.byKey(
      const Key('popi-remove-selected-image-0'),
    );
    expect(tester.getSize(firstImage), const Size.square(28));
    expect(firstRemoveButton, findsNothing);

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      163,
    );
    final expandedImageRect = tester.getRect(firstImage);
    final expandedRemoveButtonRect = tester.getRect(firstRemoveButton);
    expect(expandedImageRect.contains(expandedRemoveButtonRect.center), isTrue);
    expect(expandedRemoveButtonRect.top, expandedImageRect.top + 3);
    expect(expandedRemoveButtonRect.right, expandedImageRect.right - 3);

    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      60,
    );
    expect(firstRemoveButton, findsNothing);

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-remove-selected-image-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('popi-selected-image-4')), findsNothing);
    expect(find.byKey(const Key('popi-selected-image-3')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('does not add the same gallery image twice', (tester) async {
    final imageBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final duplicate = XFile.fromData(
      imageBytes,
      path: 'duplicate.png',
      name: 'duplicate.png',
      mimeType: 'image/png',
    );
    final unique = XFile.fromData(
      imageBytes,
      path: 'unique.png',
      name: 'unique.png',
      mimeType: 'image/png',
    );
    var pickCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: SessionPage(
            pickImages: () async =>
                pickCount++ == 0 ? [duplicate] : [duplicate, unique],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> pickFromGallery() async {
      await tester.tap(find.byTooltip('添加附件'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attachment-confirm')));
      await tester.pumpAndSettle();
    }

    await pickFromGallery();
    await pickFromGallery();

    expect(find.byKey(const Key('popi-selected-image-0')), findsOneWidget);
    expect(find.byKey(const Key('popi-selected-image-1')), findsOneWidget);
    expect(find.byKey(const Key('popi-selected-image-2')), findsNothing);
  });

  testWidgets('rejects a gallery image larger than 6MB', (tester) async {
    final oversizedImage = XFile.fromData(
      Uint8List(6 * 1024 * 1024 + 1),
      name: 'oversized.png',
      mimeType: 'image/png',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: SessionPage(pickImages: () async => [oversizedImage]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('相册'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attachment-confirm')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.byKey(const Key('popi-selected-images')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('uses dark theme colors on the home page and drawer', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
        projectRepositoryProvider.overrideWithValue(FixtureProjectRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: '当前用户', email: ''));
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.fromLTRB(24, 24, 28, 34));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _LocalizedTestApp(
          theme: AppTheme.dark,
          home: const SessionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final welcomeTitle = tester.widget<Text>(find.text('嗨，用户～'));
    expect(welcomeTitle.style!.color, AppTheme.dark.colorScheme.onSurface);

    final composer = tester.widget<Container>(
      find.byKey(const Key('popi-message-composer')),
    );
    expect(
      (composer.decoration! as BoxDecoration).color,
      AppTheme.dark.colorScheme.surfaceContainerHigh,
    );
    expect(find.byKey(const Key('popi-composer-region-blur')), findsOneWidget);
    expect(
      find.byKey(const Key('popi-composer-region-feather')),
      findsOneWidget,
    );
    final composerRegionSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('popi-composer-region-surface')),
    );
    expect(
      composerRegionSurface.color,
      AppTheme.dark.colorScheme.surface.withValues(alpha: .14),
    );

    final mascot = tester.widget<AppBotAvatar>(
      find.byKey(const Key('popi-welcome-mascot')),
    );
    expect(mascot.character, BotAvatarCharacter.tiger);

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();

    final newSessionIcon = tester
        .widgetList<AppSvgIcon>(find.byType(AppSvgIcon))
        .firstWhere((icon) => icon.assetName == 'home_drawer_project_add');
    expect(newSessionIcon.color, AppTheme.dark.colorScheme.onSurface);
    final sessionLabel = tester.widget<Text>(find.text('校园野餐vlog'));
    expect(sessionLabel.style?.color, AppTheme.dark.colorScheme.onSurface);
    await tester.tap(find.byKey(const Key('drawer-nav-view-all')));
    await tester.pumpAndSettle();
    final navigationLabel = tester.widget<Text>(find.text('角色'));
    expect(navigationLabel.style?.color, AppTheme.dark.colorScheme.onSurface);
    expect(tester.takeException(), isNull);
  });
}

class _UploadSessionRepository extends _RoleSessionRepository {
  final uploads = <Completer<String>>[];
  final uploadTokens = <CancelToken>[];
  ProgressCallback? progress;

  @override
  Future<String> upload(
    String userId,
    String name,
    Uint8List bytes, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) {
    final completion = Completer<String>();
    uploads.add(completion);
    uploadTokens.add(cancelToken!);
    progress = onSendProgress;
    return completion.future;
  }
}

class _RoleSessionRepository extends FixtureSessionRepository {
  final sentRoles = <List<String>>[];
  final sentMedia = <List<String>>[];
  String? sentText;
  bool failSend = true;

  @override
  Future<void> send(
    String userId,
    String id,
    String text,
    List<String> mediaIds, {
    List<String> roleIds = const [],
    CancelToken? cancelToken,
  }) async {
    sentRoles.add(List.of(roleIds));
    sentMedia.add(List.of(mediaIds));
    sentText = text;
    if (failSend) throw StateError('Offline');
  }
}

class _LocalizedTestApp extends StatelessWidget {
  const _LocalizedTestApp({
    required this.theme,
    required this.home,
    this.locale = const Locale('zh'),
  });

  final ThemeData theme;
  final Widget home;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );
  }
}
