import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_guide_summary.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card_content.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player.dart';
import 'support/session_fixtures.dart';

class _VideoRepository extends FixtureSessionRepository {
  @override
  Future<ConversationMedia> media(
    String id, {
    CancelToken? cancelToken,
  }) async => ConversationMedia(
    id: id,
    kind: 'video',
    url: 'https://example.com/result.mp4',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('markdown selection spans paragraphs, lists and code blocks', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const Scaffold(
          body: MarkdownMessage(
            text:
                'First paragraph\n\nSecond paragraph\n\n'
                '- First item\n- Second item\n\n'
                '```text\nCode prompt\n```\n\nLast paragraph',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.toolbar);
    await tester.pump();
    region.contextMenuButtonItems
        .firstWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();
    expect(
      copied,
      matches(
        RegExp(
          r'First paragraph[\s\S]*Second paragraph[\s\S]*First item'
          r'[\s\S]*Second item[\s\S]*Code prompt[\s\S]*Last paragraph',
        ),
      ),
    );
  });
  const captureFont = String.fromEnvironment('CONVERSATION_CAPTURE_FONT');
  const iconFont = String.fromEnvironment('CONVERSATION_CAPTURE_ICON_FONT');
  setUpAll(() async {
    for (final (family, path) in [
      ('ConversationCapture', captureFont),
      ('MaterialIcons', iconFont),
    ]) {
      if (path.isEmpty) continue;
      final loader = FontLoader(family)
        ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final width in [320.0, 390.0]) {
    for (final dark in [false, true]) {
      testWidgets('prompt, cast and video at $width dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final original = VideoPlayerPlatform.instance;
        final platform = FakeVideoPlayer();
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = original);
        final controller = ConversationController(_VideoRepository(), 'user');
        addTearDown(controller.dispose);
        final capture = GlobalKey();
        final prompt = List.generate(
          10,
          (i) =>
              'Shot $i: Keep the same character, costume and lighting. '
              'The complete prompt must wrap inside this card.',
        ).join('\n');
        var profilesOpened = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: captureFont.isEmpty
                ? dark
                      ? AppTheme.dark
                      : AppTheme.light
                : (dark ? AppTheme.dark : AppTheme.light).copyWith(
                    textTheme: (dark ? AppTheme.dark : AppTheme.light).textTheme
                        .apply(fontFamily: 'ConversationCapture'),
                  ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    RoleCastSummary(
                      cast: List.generate(
                        5,
                        (i) => LibraryRole(
                          id: '$i',
                          title: 'Character $i',
                          description: 'Cast member',
                          avatar:
                              'assets/images/role_guide_avatar_${i + 3}.png',
                        ),
                      ),
                      onViewProfiles: () => profilesOpened = true,
                    ),
                    const SizedBox(height: 16),
                    ConversationCardContent(
                      storageId: 'prompt',
                      child: MarkdownMessage(
                        text: '### Video prompt\n\n```text\n$prompt\n```',
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConversationObjectView(
                      block: ConversationBlock.fromJson({
                        'type': 'object',
                        'kind': 'artifact',
                        'data': {
                          'id': 'video-result',
                          'title': 'Video result',
                          'body': 'Video generation completed.',
                          'mediaIds': ['video'],
                        },
                      }),
                      controller: controller,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final content = find.byType(ConversationCardContent).first;
        final nestedScrolls = find.descendant(
          of: content,
          matching: find.byType(SingleChildScrollView),
        );
        expect(nestedScrolls, findsOneWidget);
        expect(
          tester.widget<SingleChildScrollView>(nestedScrolls).scrollDirection,
          Axis.vertical,
        );
        final text = find.descendant(
          of: content,
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == prompt,
          ),
        );
        expect(text, findsOneWidget);
        expect(tester.getSize(text).width, lessThan(width - 32));
        final scroll = tester
            .widget<SingleChildScrollView>(nestedScrolls)
            .controller!;
        await tester.drag(nestedScrolls, const Offset(0, -140));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));

        final angles = List.generate(
          3,
          (i) => tester
              .widget<Transform>(find.byKey(ValueKey('role-cast-fan-$i')))
              .transform
              .entry(1, 0),
        );
        expect(angles.first, lessThan(0));
        expect(angles[1], 0);
        expect(angles.last, greaterThan(0));
        await tester.tap(find.byKey(const Key('role-guide-view-profiles')));
        await tester.pumpAndSettle();
        expect(profilesOpened, isTrue);

        expect(find.byType(AppVideoPlayer), findsOneWidget);
        expect(find.text('Play video'), findsNothing);
        expect(platform.sources.single.uri, 'https://example.com/result.mp4');
        await tester.tap(
          find.byKey(const Key('conversation-video-video-play')),
        );
        await tester.pump();
        expect(platform.playing, isTrue);
        await tester.tap(
          find.byKey(const Key('conversation-video-video-play')),
        );
        await tester.pumpAndSettle();
        expect(platform.playing, isFalse);
        expect(
          find.byKey(const Key('conversation-video-video-fullscreen')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        if (const bool.fromEnvironment('CAPTURE_CONVERSATION_RENDERING')) {
          await tester.runAsync(() async {
            for (var i = 3; i <= 5; i++) {
              await precacheImage(
                AssetImage('assets/images/role_guide_avatar_$i.png'),
                capture.currentContext!,
              );
            }
          });
          await tester.pumpAndSettle();
          final boundary =
              capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/conversation-rendering-${width.toInt()}-$dark.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
