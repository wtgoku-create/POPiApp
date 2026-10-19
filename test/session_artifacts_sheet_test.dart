import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/data/session_artifact_repository.dart';
import 'package:popi_ai_app/features/session/domain/session_artifact.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/session_artifacts_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player.dart';
import 'support/session_artifact_fixtures.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    bool dark = false,
    double textScale = 1,
    SessionArtifactRepository repository =
        const FixtureSessionArtifactRepository(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: SessionArtifactsSheet(repository: repository),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('filters outputs and returns from details to selected category', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(find.text('萌宠角色三视图'), findsOneWidget);
    expect(find.text('《围巾不见了》分镜剧本'), findsOneWidget);
    expect(find.text('角色故事短片'), findsOneWidget);
    await tap(tester, 'session-artifact-filter-script');
    expect(find.text('萌宠角色三视图'), findsNothing);
    expect(find.text('角色故事短片'), findsNothing);
    await tap(tester, 'session-artifact-open-mock-script');
    expect(find.text('脚本详情'), findsOneWidget);
    final detail = find.byKey(
      const ValueKey('session-artifact-detail-mock-script'),
    );
    await tester.drag(detail, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('镜头 06 · 温暖的结尾'), findsOneWidget);
    await tap(tester, 'session-artifact-back');
    expect(find.text('当前对话产物'), findsOneWidget);
    expect(find.text('萌宠角色三视图'), findsNothing);
    expect(find.text('《围巾不见了》分镜剧本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'image details preserve full image and platform back returns to list',
    (tester) async {
      await pumpSheet(tester);
      await tap(tester, 'session-artifact-open-mock-role');
      expect(find.text('图片详情'), findsOneWidget);
      final detail = find.byKey(
        const ValueKey('session-artifact-detail-mock-role'),
      );
      final image = find.descendant(of: detail, matching: find.byType(Image));
      expect(tester.widget<Image>(image).fit, BoxFit.contain);
      final bounds = tester.getSize(
        find.descendant(of: detail, matching: find.byType(AspectRatio)),
      );
      expect(bounds.width, bounds.height);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('当前对话产物'), findsOneWidget);
      expect(find.text('图片详情'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('video starts on demand and releases player on detail return', (
    tester,
  ) async {
    final original = VideoPlayerPlatform.instance;
    final platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    await pumpSheet(tester);
    await tap(tester, 'session-artifact-filter-video');
    await tap(tester, 'session-artifact-open-mock-video');
    expect(find.text('视频详情'), findsOneWidget);
    expect(platform.sources, isEmpty);
    await tap(tester, 'session-artifact-video-play');
    expect(find.byType(AppVideoPlayer), findsOneWidget);
    expect(platform.playing, isTrue);
    await tap(tester, 'session-artifact-back');
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.disposed, [1]);
    expect(platform.playing, isFalse);
    expect(find.text('角色故事短片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('compact layout fits all categories and details, dark=$dark', (
      tester,
    ) async {
      await pumpSheet(tester, size: const Size(320, 568), dark: dark);
      for (final type in ['image', 'script', 'video']) {
        await tap(tester, 'session-artifact-filter-$type');
        final id = type == 'image' ? 'role' : type;
        await tap(tester, 'session-artifact-open-mock-$id');
        expect(tester.takeException(), isNull);
        await tap(tester, 'session-artifact-back');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty outputs show empty state with filters available', (
    tester,
  ) async {
    await pumpSheet(tester, repository: const _EmptyRepository());
    expect(find.text('暂无产物'), findsOneWidget);
    await tap(tester, 'session-artifact-filter-script');
    expect(find.text('暂无产物'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real text drafts preview Markdown without adopt or edit actions at large text scale',
    (tester) async {
      await pumpSheet(
        tester,
        size: const Size(320, 568),
        dark: true,
        textScale: 1.5,
        repository: const _TextRepository(),
      );
      await tap(tester, 'session-artifact-filter-script');
      expect(find.textContaining('未记录时长'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('session-artifact-download-text')),
        findsNothing,
      );
      await tap(tester, 'session-artifact-open-text');
      expect(find.text('故事正文'), findsOneWidget);
      expect(find.text('第二段正文'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('session-artifact-download-detail')),
        findsNothing,
      );
      expect(find.text('采用'), findsNothing);
      expect(find.text('修改'), findsNothing);
      await tap(tester, 'session-artifact-back');
      expect(find.text('真实稿件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late responses from the previous session cannot replace current outputs',
    (tester) async {
      final repository = _DeferredRepository();
      final session = ValueNotifier('first');
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<String>(
                valueListenable: session,
                builder: (_, id, _) => SessionArtifactsSheet(
                  sessionId: id,
                  repository: repository,
                ),
              ),
            ),
          ),
        ),
      );
      session.value = 'second';
      await tester.pump();
      repository.requests['second']!.complete([
        SessionArtifact.fromTextDraft({
          'id': 'new',
          'title': 'Current output',
          'content': 'Current',
        }),
      ]);
      await tester.pumpAndSettle();
      repository.requests['first']!.complete([
        SessionArtifact.fromTextDraft({
          'id': 'old',
          'title': 'Obsolete output',
          'content': 'Old',
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Current output'), findsOneWidget);
      expect(find.text('Obsolete output'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DeferredRepository extends SessionArtifactRepository {
  final requests = <String, Completer<List<SessionArtifact>>>{};

  @override
  Future<List<SessionArtifact>> list(String? sessionId) =>
      (requests[sessionId!] = Completer<List<SessionArtifact>>()).future;
}

class _TextRepository extends SessionArtifactRepository {
  const _TextRepository();

  @override
  Future<List<SessionArtifact>> list(String? sessionId) async => [
    SessionArtifact.fromTextDraft({
      'id': 'text',
      'kind': 'topic',
      'title': '真实稿件',
      'content': '## 故事正文\n\n第二段正文',
      'durationSeconds': 0,
      'createdAt': '2026-10-19T03:15:00Z',
    }),
  ];
}

class _EmptyRepository extends SessionArtifactRepository {
  const _EmptyRepository();

  @override
  Future<List<SessionArtifact>> list(String? sessionId) async => const [];
}
