import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/teaching/data/teaching_repository.dart';
import 'package:popi_ai_app/features/teaching/domain/teaching.dart';
import 'package:popi_ai_app/features/teaching/presentation/teaching_document_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/fake_webview.dart';

class _Repository extends TeachingRepository {
  _Repository()
    : super(NetworkApi(Dio(BaseOptions(baseUrl: 'https://api.test'))));

  int requests = 0;
  TeachingDocument? document = const TeachingDocument(
    id: 20,
    title: '文章',
    contentHtml: '<h1>正文</h1>',
    memberLevels: [2],
  );
  Future<TeachingDocument?> Function()? load;

  @override
  Future<TeachingDocument?> fetchCourseDocument(int courseId) async {
    requests++;
    expect(courseId, 10);
    return load == null ? document : await load!();
  }

  @override
  Future<Map<int, String>> fetchMemberLabels() async => {2: 'Plus'};
}

void main() {
  late FakeWebViewPlatform platform;
  late _Repository repository;
  late GoRouter router;
  late ProviderContainer container;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    repository = _Repository();
    container = ProviderContainer();
  });

  Future<void> openPage(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/teaching/document/10',
      routes: [
        GoRoute(
          path: '/teaching/document/10',
          builder: (_, __) => TeachingDocumentPage(
            courseId: 10,
            course: const TeachingCourse(id: 10, name: '课程', description: '简介'),
            repository: repository,
            readerUrl: Uri.parse('https://web.test/teaching/reader'),
          ),
        ),
        GoRoute(
          path: '/profile/membership',
          builder: (_, __) => Scaffold(
            body: TextButton(
              onPressed: () => router.pop(),
              child: const Text('返回课程'),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('登录页')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    platform.delegate.onPageStarted(
      platform.controller.requests.last.uri.toString(),
    );
    await tester.pump();
  }

  Map<String, Object?> renderMessage() {
    final script = platform.controller.scripts.last;
    final literal = script.substring(
      'window.PopiTeachingReader.receive(JSON.parse('.length,
      script.length - 3,
    );
    return Map<String, Object?>.from(
      jsonDecode(jsonDecode(literal) as String) as Map,
    );
  }

  void emit(
    String type, {
    String? requestId,
    String? session,
    Map<String, Object?> values = const {},
  }) {
    platform.controller.channels['PopiTeaching']!.onMessageReceived(
      JavaScriptMessage(
        message: jsonEncode({
          'version': 1,
          'session':
              session ??
              platform
                  .controller
                  .requests
                  .last
                  .uri
                  .queryParameters['bridgeSession'],
          'type': type,
          if (requestId != null) 'requestId': requestId,
          ...values,
        }),
      ),
    );
  }

  Future<String> ready(WidgetTester tester) async {
    emit('ready');
    await tester.pump();
    return renderMessage()['requestId']! as String;
  }

  testWidgets(
    'requests no Web credentials, waits for ready and acknowledges the current render',
    (tester) async {
      await openPage(tester);
      expect(platform.controller.requests.single.headers, isEmpty);
      expect(platform.controller.requests.single.uri.path, '/teaching/reader');
      expect(platform.controller.scripts, isEmpty);
      final requestId = await ready(tester);
      final payload = renderMessage()['payload'] as Map;
      expect((payload['course'] as Map)['description'], '简介');
      expect(payload['requiredMemberLevelName'], 'Plus');
      expect(payload['mediaBaseUrl'], 'https://api.test');
      emit('rendered', requestId: 'old');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      emit('rendered', requestId: requestId);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('supports ready arriving before the document response', (
    tester,
  ) async {
    final response = Completer<TeachingDocument?>();
    repository.load = () => response.future;
    await openPage(tester);
    emit('ready');
    await tester.pump();
    expect(platform.controller.scripts, isEmpty);
    response.complete(repository.document);
    await tester.pump();
    expect(platform.controller.scripts, hasLength(1));
    emit('rendered', requestId: renderMessage()['requestId'] as String);
    await tester.pump();
  });

  testWidgets(
    'catalog selection uses the bridge and external navigation cannot replace the reader',
    (tester) async {
      await openPage(tester);
      final requestId = await ready(tester);
      emit(
        'rendered',
        requestId: requestId,
        values: {
          'catalog': [
            {'id': 'h1', 'title': '第一节', 'level': 1},
            {'id': 'h2', 'title': '第二节', 'level': 2},
          ],
        },
      );
      emit('activeHeading', requestId: requestId, values: {'id': 'h2'});
      await tester.pump();
      await tester.tap(find.byTooltip('课程目录'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '第二节')).selected,
        isTrue,
      );
      await tester.tap(find.text('第一节'));
      await tester.pumpAndSettle();
      expect(renderMessage()['type'], 'scrollTo');
      expect(renderMessage()['id'], 'h1');
      expect(
        await platform.delegate.onNavigationRequest(
          const NavigationRequest(
            url: 'https://external.test',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      expect(
        await platform.delegate.onNavigationRequest(
          NavigationRequest(
            url: platform.controller.requests.last.uri.toString(),
            isMainFrame: true,
          ),
        ),
        NavigationDecision.navigate,
      );
    },
  );

  testWidgets(
    'times out, retries with a fresh session and ignores old messages',
    (tester) async {
      await openPage(tester);
      final oldSession = platform
          .controller
          .requests
          .single
          .uri
          .queryParameters['bridgeSession'];
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('课程内容加载失败，请重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      platform.delegate.onPageStarted(
        platform.controller.requests.last.uri.toString(),
      );
      emit('ready', session: oldSession);
      await tester.pump();
      expect(platform.controller.scripts, isEmpty);
      final requestId = await ready(tester);
      emit('rendered', requestId: requestId);
      await tester.pump();
      expect(find.text('课程内容加载失败，请重试'), findsNothing);
      expect(repository.requests, 2);
    },
  );

  testWidgets('shows empty documents and handles API and reader failures', (
    tester,
  ) async {
    repository.document = null;
    await openPage(tester);
    expect(find.text('该课程暂无内容'), findsOneWidget);
    repository.load = () async => throw StateError('Offline');
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('课程内容加载失败，请重试'), findsOneWidget);
    repository.load = null;
    repository.document = const TeachingDocument(id: 20);
    await tester.tap(find.text('重试'));
    await tester.pump();
    platform.delegate.onPageStarted(
      platform.controller.requests.last.uri.toString(),
    );
    final requestId = await ready(tester);
    emit('error', requestId: requestId);
    await tester.pump();
    expect(find.text('课程内容加载失败，请重试'), findsOneWidget);
  });

  testWidgets('refreshes permissions when returning from membership', (
    tester,
  ) async {
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: '用户', email: ''));
    await openPage(tester);
    final requestId = await ready(tester);
    emit('rendered', requestId: requestId);
    emit('upgrade', requestId: requestId);
    await tester.pumpAndSettle();
    expect(find.text('返回课程'), findsOneWidget);
    await tester.tap(find.text('返回课程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.requests, 2);
    platform.delegate.onPageStarted(
      platform.controller.requests.last.uri.toString(),
    );
    final nextId = await ready(tester);
    emit('rendered', requestId: nextId);
    await tester.pump();
  });
}
