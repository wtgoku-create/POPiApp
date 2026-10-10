import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/teaching/presentation/teaching_document_page.dart';
import 'package:popi_ai_app/features/teaching/data/teaching_repository.dart';
import 'package:popi_ai_app/features/teaching/domain/teaching.dart';
import 'package:popi_ai_app/features/teaching/presentation/teaching_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

const _categories = [
  TeachingCategory(id: 1, name: '新手教程'),
  TeachingCategory(id: 2, name: '画布拆解'),
  TeachingCategory(id: 3, name: '爆款案例'),
  TeachingCategory(id: 4, name: '系列课程'),
];

List<TeachingCourse> _courses({int count = 4, int start = 1}) => [
  for (var i = start; i < start + count; i++)
    TeachingCourse(
      id: i,
      name: '【新手教学02】AI图片创作指南，小白如何通过',
      coverUrl: 'https://teaching.test/cover${(i - 1) % 4 + 1}.png',
      instructorName: '爱丽丝',
      instructorAvatarUrl: 'https://teaching.test/avatar.png',
      memberLevels: switch (i % 4) {
        2 => [2],
        3 => [3],
        0 => [1],
        _ => [],
      },
    ),
];

class _Repository extends TeachingRepository {
  _Repository() : super(NetworkApi(Dio()));

  Future<TeachingCourseList> Function(int page, int? category)? load;
  bool failCategories = false;
  final requests = <(int, int?)>[];

  @override
  Future<List<TeachingCategory>> fetchCategories() async {
    if (failCategories) throw StateError('Unavailable');
    return _categories;
  }

  @override
  Future<TeachingHighlights> fetchHighlights() async =>
      const TeachingHighlights(
        communityQrUrl: 'https://teaching.test/community.png',
        memberLabels: {1: 'Starter', 2: 'Plus', 3: 'Max'},
        startingPrice: '59',
      );

  @override
  Future<TeachingCourseList> fetchCourses({
    required int page,
    int pageSize = 20,
    int? categoryId,
    String? keyword,
  }) async {
    requests.add((page, categoryId));
    return load != null
        ? load!(page, categoryId)
        : TeachingCourseList(items: _courses(), hasMore: false);
  }
}

void main() {
  Future<GoRouter> pumpPage(
    WidgetTester tester,
    _Repository repository, {
    Size size = const Size(440, 956),
    Locale locale = const Locale('zh'),
    bool dark = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/teaching',
      routes: [
        GoRoute(
          path: '/teaching',
          builder: (_, __) => TeachingPage(repository: repository),
          routes: [
            GoRoute(
              path: 'document/:courseId',
              builder: (_, state) => TeachingDocumentPage(
                courseId: int.parse(state.pathParameters['courseId']!),
                course: state.extra! as TeachingCourse,
                repository: repository,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/profile/membership',
          builder: (_, __) => const Scaffold(body: Text('订阅页')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final theme = dark ? AppTheme.dark : AppTheme.light;
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(
          key: const Key('teaching-screenshot'),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: const bool.fromEnvironment('TEACHING_SCREENSHOTS')
                ? theme.copyWith(
                    textTheme: theme.textTheme.apply(fontFamily: 'VisualQA'),
                  )
                : theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  void pageTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      debugNetworkImageHttpClientProvider = () => _ImageClient();
      try {
        await body(tester);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    });
  }

  pageTest(
    'renders two columns, instructor labels and real membership badges',
    (tester) async {
      final repository = _Repository();
      await pumpPage(tester, repository);
      expect(find.text('教学中心'), findsOneWidget);
      expect(find.text('免费'), findsOneWidget);
      expect(find.text('Plus'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Starter'), findsOneWidget);
      final first = tester.getRect(
        find.byKey(const ValueKey('teaching-course-1')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('teaching-course-2')),
      );
      expect(first.left, 20);
      expect(first.top, 371);
      expect(second.left - first.right, 10);
      expect(second.top, first.top);
      expect(first.width, 195);
      expect(
        tester.getRect(find.byKey(const Key('popi-open-navigation'))).left,
        15,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('teaching-badge-1'))).right,
        first.right - 10,
      );
      expect(repository.requests, [(1, null)]);
      expect(tester.takeException(), isNull);
    },
  );

  pageTest('fast category switching ignores the previous response', (
    tester,
  ) async {
    final previous = Completer<TeachingCourseList>();
    final repository = _Repository()
      ..load = (page, category) async {
        if (category == 1) return previous.future;
        return TeachingCourseList(
          items: _courses(start: category == 2 ? 201 : 1),
          hasMore: false,
        );
      };
    await pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey('teaching-category-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('teaching-category-2')));
    await tester.pumpAndSettle();
    previous.complete(
      TeachingCourseList(items: _courses(start: 101), hasMore: false),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('teaching-course-201')), findsOneWidget);
    expect(find.byKey(const ValueKey('teaching-course-101')), findsNothing);
    expect(repository.requests, [(1, null), (1, 1), (1, 2)]);
    expect(tester.takeException(), isNull);
  });

  pageTest(
    'initial failure can retry and empty categories keep navigation available',
    (tester) async {
      var fail = true;
      final repository = _Repository()
        ..load = (page, category) async {
          if (fail) throw StateError('Offline');
          return const TeachingCourseList(items: [], hasMore: false);
        };
      await pumpPage(tester, repository);
      expect(find.byKey(const Key('teaching-retry-courses')), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const Key('teaching-retry-courses')));
      await tester.pumpAndSettle();
      expect(find.text('暂无课程'), findsOneWidget);
      expect(find.byKey(const Key('popi-open-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  pageTest('category failure does not block courses and can recover', (
    tester,
  ) async {
    final repository = _Repository()..failCategories = true;
    await pumpPage(tester, repository);
    expect(find.byKey(const ValueKey('teaching-course-1')), findsOneWidget);
    expect(find.byKey(const Key('teaching-retry-categories')), findsOneWidget);
    repository.failCategories = false;
    await tester.tap(find.byKey(const Key('teaching-retry-categories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teaching-retry-categories')), findsNothing);
    expect(find.byKey(const ValueKey('teaching-category-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  pageTest(
    'pagination failure retains courses, retries the same page and deduplicates',
    (tester) async {
      var fail = true;
      final repository = _Repository()
        ..load = (page, category) async {
          if (page == 1) {
            return TeachingCourseList(
              items: _courses(count: 20),
              hasMore: true,
            );
          }
          if (fail) throw StateError('Offline');
          return TeachingCourseList(
            items: _courses(start: 20, count: 3),
            hasMore: false,
          );
        };
      await pumpPage(tester, repository);
      await tester.drag(
        find.byKey(const Key('teaching-scroll')),
        const Offset(0, -6000),
      );
      await tester.pumpAndSettle();
      expect(repository.requests, [(1, null), (2, null)]);
      final retry = find.byKey(const Key('teaching-retry-more'));
      await tester.ensureVisible(retry);
      fail = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repository.requests, [(1, null), (2, null), (2, null)]);
      expect(find.byKey(const ValueKey('teaching-course-20')), findsOneWidget);
      expect(find.byKey(const ValueKey('teaching-course-22')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  pageTest('course opens its reader and back preserves the catalog', (
    tester,
  ) async {
    final repository = _Repository();
    final router = await pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey('teaching-course-2')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/teaching/document/2');
    final detail = tester.widget<TeachingDocumentPage>(
      find.byType(TeachingDocumentPage),
    );
    expect(detail.courseId, 2);
    expect(detail.course?.id, 2);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(TeachingPage), findsOneWidget);
    expect(repository.requests, [(1, null)]);
    expect(tester.takeException(), isNull);
  });

  pageTest(
    'membership banner swipes into view and opens the subscription page',
    (tester) async {
      final router = await pumpPage(tester, _Repository());
      await tester.drag(
        find.byKey(const Key('teaching-banners')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      final indicator = tester.widget<Container>(
        find.byKey(const ValueKey('teaching-banner-indicator-2')),
      );
      expect(indicator.constraints!.maxWidth, 15);
      await tester.tap(find.byKey(const Key('teaching-membership-banner')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile/membership');
      expect(tester.takeException(), isNull);
    },
  );

  pageTest('community banner previews its configured QR image', (tester) async {
    final router = await pumpPage(tester, _Repository());
    await tester.drag(
      find.byKey(const Key('teaching-banners')),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const NetworkImage('https://teaching.test/community.png'),
        tester.element(find.byType(TeachingPage)),
      ),
    );
    await tester.tap(find.byKey(const Key('teaching-community-banner')));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('asset-preview-image')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as NetworkImage).url,
      'https://teaching.test/community.png',
    );
    expect(router.state.uri.path, '/teaching');
    await tester.tap(find.byKey(const Key('asset-preview-image')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-image')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, locale, dark, scale) in [
    ('design', const Size(440, 956), const Locale('zh'), false, 1.0),
    ('compact', const Size(320, 568), const Locale('zh'), false, 1.0),
    ('dark-en', const Size(390, 844), const Locale('en'), true, 1.0),
    ('large-text', const Size(320, 568), const Locale('en'), false, 1.8),
    ('wide', const Size(1024, 768), const Locale('en'), false, 1.0),
  ]) {
    pageTest('responsive catalog remains usable: $name', (tester) async {
      if (const bool.fromEnvironment('TEACHING_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final font = FontLoader('VisualQA')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    '/System/Library/Fonts/STHeiti Light.ttc',
                  ).readAsBytesSync(),
                ),
              ),
            );
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      await pumpPage(
        tester,
        _Repository(),
        size: size,
        locale: locale,
        dark: dark,
        textScale: scale,
      );
      final firstCourse = find.byKey(const ValueKey('teaching-course-1'));
      expect(tester.getRect(firstCourse).top, lessThan(size.height));
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('TEACHING_SCREENSHOTS')) {
        final imageContext = tester.element(find.byType(TeachingPage));
        await tester.runAsync(() async {
          await Future.wait([
            for (final image in <ImageProvider>[
              const AssetImage('assets/images/teaching_creator.png'),
              const AssetImage('assets/images/teaching_member_background.png'),
              for (var i = 1; i <= 4; i++)
                NetworkImage('https://teaching.test/cover$i.png'),
              const NetworkImage('https://teaching.test/avatar.png'),
              const NetworkImage('https://teaching.test/community.png'),
            ])
              precacheImage(image, imageContext),
          ]);
        });
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('teaching-screenshot')),
        );
        await tester.runAsync(() async {
          final screenshot = await boundary.toImage();
          final bytes = await screenshot.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '/tmp/popi-teaching-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          screenshot.dispose();
        });
      }
      await tester.ensureVisible(firstCourse);
      await tester.pumpAndSettle();
      expect(firstCourse.hitTestable(), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('teaching-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

class _ImageClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final preview = File('/tmp/popi-teaching-${url.pathSegments.last}');
    final bytes =
        const bool.fromEnvironment('TEACHING_SCREENSHOTS') &&
            preview.existsSync()
        ? preview.readAsBytesSync()
        : File('assets/images/assets_works_gallery_01.png').readAsBytesSync();
    return _ImageRequest(bytes);
  }

  @override
  set autoUncompress(bool value) {}

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.bytes);
  final Uint8List bytes;

  @override
  Future<HttpClientResponse> close() async => _ImageResponse(bytes);

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final Uint8List bytes;

  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
