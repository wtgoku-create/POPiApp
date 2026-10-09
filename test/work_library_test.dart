import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/assets/data/work_library_repository.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:popi_ai_app/features/assets/presentation/assets_page.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player.dart';

Map<String, Object?> task(String id, {int type = 1, int status = 2}) => {
  'id': 'task-$id',
  'type': type,
  'status': status,
  'createTime': '2026-10-08T12:00:00+08:00',
  'resultList': [
    {
      'id': id,
      'images': ['/media/$id.png'],
      if (type == 2) 'video': '/media/$id.mp4',
      if (type == 2) 'cover': '/media/$id-cover.png',
    },
  ],
};

class TestUserController extends UserController {
  @override
  User? build() => const User(id: 'user', name: 'User', email: '');

  @override
  Future<void> clearUser() async => state = null;
}

class TestWorkRepository extends WorkLibraryRepository {
  TestWorkRepository(this.load) : super(NetworkApi(Dio()));
  final Future<LibraryWorkPage> Function(int, int) load;
  final requests = <(int, int)>[];

  @override
  Future<LibraryWorkPage> fetchPage({
    required int type,
    required int page,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    requests.add((type, page));
    return load(type, page);
  }
}

LibraryWorkPage workPage(String id, {bool hasMore = false}) => LibraryWorkPage(
  items: [
    LibraryWork(
      id: id,
      previewUrl: 'https://example.test/$id.png',
      isVideo: false,
      createdAt: DateTime(2026, 10, 8),
    ),
  ],
  hasMore: hasMore,
);

void main() {
  for (final type in [0, 1, 2]) {
    test('uses completed app task contract for filter $type', () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'status': '0000',
                  'data': {
                    'list': [
                      task('image'),
                      task('video', type: 2),
                      task('pending', status: 1),
                    ],
                    'pageInfo': {'pageCount': '3'},
                  },
                },
              ),
            );
          },
        ),
      );
      final page = await WorkLibraryRepository(
        NetworkApi(dio),
      ).fetchPage(type: type, page: 2);
      expect(request.path, '/api_client/anime/task/list');
      expect(request.queryParameters, {
        'origin': 'app',
        'status_min': 2,
        'page': 2,
        'pageSize': 20,
        if (type != 0) 'type': type,
        if (type == 1) 'excludeSubType': '106',
      });
      expect(page.items.map((work) => work.id), ['image', 'video']);
      expect(page.items.last.isVideo, isTrue);
      expect(page.items.last.videoUrl, 'https://example.test/media/video.mp4');
      expect(
        page.items.last.previewUrl,
        'https://example.test/media/video-cover.png',
      );
      expect(
        page.items.first.createdAt?.millisecondsSinceEpoch,
        DateTime.parse('2026-10-08T12:00:00+08:00').millisecondsSinceEpoch,
      );
      expect(page.hasMore, isTrue);
    });
  }

  test('pagination counts raw tasks even with no visible works', () {
    final page = LibraryWorkPage.fromJson(
      {
        'list': [task('failed', status: 3)],
      },
      page: 1,
      pageSize: 1,
      mediaBaseUrl: 'https://example.test',
    );
    expect(page.items, isEmpty);
    expect(page.hasMore, isTrue);
    expect(
      LibraryWorkPage.fromJson(
        {'list': []},
        page: 2,
        pageSize: 1,
        mediaBaseUrl: 'https://example.test',
      ).hasMore,
      isFalse,
    );
  });

  test('business failures do not become an empty list', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'status': '1001',
                'message': 'Failed',
                'data': {'list': []},
              },
            ),
          );
        },
      ),
    );
    await expectLater(
      WorkLibraryRepository(NetworkApi(dio)).fetchPage(type: 0, page: 1),
      throwsA(isA<ApiException>()),
    );
  });

  Future<ProviderContainer> pumpLibrary(
    WidgetTester tester,
    TestWorkRepository repository,
  ) async {
    final container = ProviderContainer(
      overrides: [userProvider.overrideWith(TestUserController.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AssetsPage(repository: repository),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('loads real works, paginates, refreshes and clears on logout', (
    tester,
  ) async {
    final first = Completer<LibraryWorkPage>();
    final repository = TestWorkRepository(
      (_, page) async => page == 1 ? first.future : workPage('second'),
    );
    final container = await pumpLibrary(tester, repository);
    expect(find.byKey(const Key('assets-works-skeleton')), findsOneWidget);
    first.complete(workPage('first', hasMore: true));
    await tester.pumpAndSettle();
    expect(repository.requests, [(0, 1), (0, 2)]);
    expect(find.byKey(const Key('assets-work-1')), findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('assets-work-0')),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as NetworkImage).url, 'https://example.test/first.png');
    final refreshing = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refreshing;
    expect(
      repository.requests.where((request) => request.$2 == 1),
      hasLength(2),
    );
    await container.read(userProvider.notifier).clearUser();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assets-works-empty-state')), findsOneWidget);
    expect(find.byKey(const Key('assets-work-0')), findsNothing);
  });

  testWidgets('shows failure and retries the first page', (tester) async {
    var attempts = 0;
    final repository = TestWorkRepository((_, __) async {
      if (attempts++ == 0) throw const ApiException();
      return workPage('retried');
    });
    await pumpLibrary(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assets-works-error')), findsOneWidget);
    expect(find.byKey(const Key('assets-works-empty-state')), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assets-work-0')), findsOneWidget);
    expect(repository.requests, [(0, 1), (0, 1)]);
  });

  testWidgets('video without a cover opens its actual video URL', (
    tester,
  ) async {
    final original = VideoPlayerPlatform.instance;
    final platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    final repository = TestWorkRepository(
      (_, __) async => LibraryWorkPage(
        items: const [
          LibraryWork(
            id: 'video',
            previewUrl: '',
            videoUrl: 'https://example.test/actual.mp4',
            isVideo: true,
            createdAt: null,
          ),
        ],
        hasMore: false,
      ),
    );
    await pumpLibrary(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assets-work-0')));
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(platform.sources.single.uri, 'https://example.test/actual.mp4');
    expect(platform.playing, isTrue);
    expect(find.byKey(const Key('asset-preview-image')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.disposed, [1]);
  });

  testWidgets('filter changes and logout discard old responses', (
    tester,
  ) async {
    final old = Completer<LibraryWorkPage>();
    final repository = TestWorkRepository(
      (type, _) async => type == 0 ? old.future : workPage('filtered'),
    );
    final container = await pumpLibrary(tester, repository);
    await tester.tap(find.byKey(const Key('assets-history-filter-1')));
    await tester.pumpAndSettle();
    expect(repository.requests, [(0, 1), (1, 1)]);
    await container.read(userProvider.notifier).clearUser();
    old.complete(workPage('stale'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assets-work-0')), findsNothing);
    expect(find.byKey(const Key('assets-works-empty-state')), findsOneWidget);
  });
}
