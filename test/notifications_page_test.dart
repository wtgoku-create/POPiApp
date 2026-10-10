import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/h5/presentation/h5_page.dart';
import 'package:popi_ai_app/features/notifications/data/notification_repository.dart';
import 'package:popi_ai_app/features/notifications/domain/app_notification.dart';
import 'package:popi_ai_app/features/notifications/presentation/notification_detail_page.dart';
import 'package:popi_ai_app/features/notifications/presentation/notifications_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/type/notification_type.dart';
import 'package:toastification/toastification.dart';

AppNotification fixtureNotification(
  int id, {
  bool unread = true,
  NotificationTarget? target,
}) => AppNotification(
  id: id,
  title: 'Announcement $id',
  content: 'Full notification content $id.\nSecond line of the message.',
  isUnread: unread,
  sentAt: DateTime(2026, 8, 9),
  target: target,
);

class FixtureNotificationRepository extends NotificationRepository {
  FixtureNotificationRepository() : super(NetworkApi(Dio()));

  final requests = <(NotificationType, int)>[];
  final readRequests = <int>[];
  final failures = <(NotificationType, int)>{};
  final pages = <(NotificationType, int), NotificationListPage>{
    (NotificationType.system, 1): NotificationListPage(
      items: [fixtureNotification(1), fixtureNotification(2, unread: false)],
      hasMore: false,
    ),
    (NotificationType.personal, 1): NotificationListPage(
      items: [
        fixtureNotification(
          3,
          target: const NotificationTarget.page('/profile/membership'),
        ),
      ],
      hasMore: false,
    ),
  };
  Completer<NotificationListPage>? pending;
  Completer<void>? pendingRead;
  bool readFails = false;

  @override
  Future<NotificationListPage> fetchNotifications(
    NotificationType type, {
    required int page,
    int pageSize = 20,
  }) async {
    requests.add((type, page));
    final request = pending;
    pending = null;
    if (request != null) return request.future;
    if (failures.contains((type, page))) throw const ApiException();
    return pages[(type, page)] ??
        const NotificationListPage(items: [], hasMore: false);
  }

  @override
  Future<void> markRead(int id) async {
    readRequests.add(id);
    await pendingRead?.future;
    if (readFails) throw const ApiException();
  }
}

Widget notificationTestApp(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double scale = 1,
}) => ToastificationWrapper(
  child: MaterialApp(
    theme: theme ?? AppTheme.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  Future<ProviderContainer> pumpPage(
    WidgetTester tester,
    FixtureNotificationRepository repository, {
    bool signedIn = true,
    ThemeData? theme,
    double scale = 1,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    if (signedIn) {
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: 'User', email: ''));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: notificationTestApp(
          NotificationsPage(repository: repository),
          theme: theme,
          scale: scale,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> backFromDetail(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('notification-back')).last);
    await tester.pumpAndSettle();
  }

  testWidgets('requires sign-in before fetching deliveries', (tester) async {
    final repository = FixtureNotificationRepository();
    await pumpPage(tester, repository, signedIn: false);
    expect(find.text('Sign in to view notifications'), findsOneWidget);
    expect(repository.requests, isEmpty);
  });

  testWidgets('switches categories lazily and preserves loaded lists', (
    tester,
  ) async {
    final repository = FixtureNotificationRepository();
    await pumpPage(tester, repository);
    expect(repository.requests, [(NotificationType.system, 1)]);
    expect(find.byKey(const Key('notification-new-1')), findsOneWidget);
    expect(find.byKey(const Key('notification-new-2')), findsNothing);
    await tester.tap(find.byKey(const Key('notification-tab-personal')));
    await tester.pumpAndSettle();
    expect(find.text('Announcement 3'), findsOneWidget);
    expect(find.text('Learn more'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification-tab-system')));
    await tester.pumpAndSettle();
    expect(find.text('Announcement 1'), findsOneWidget);
    expect(repository.requests, [
      (NotificationType.system, 1),
      (NotificationType.personal, 1),
    ]);
  });

  testWidgets('shows full content and marks unread deliveries once', (
    tester,
  ) async {
    final repository = FixtureNotificationRepository()
      ..pendingRead = Completer<void>();
    await pumpPage(tester, repository);
    await tester.tap(find.byKey(const Key('notification-card-1')));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationDetailPage), findsOneWidget);
    expect(
      find.text('Full notification content 1.\nSecond line of the message.'),
      findsOneWidget,
    );
    expect(repository.readRequests, [1]);
    await backFromDetail(tester);
    expect(find.byKey(const Key('notification-new-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification-card-1')));
    await tester.pumpAndSettle();
    expect(repository.readRequests, [1]);
    repository.pendingRead!.complete();
    await tester.pumpAndSettle();
    await backFromDetail(tester);
    expect(find.byKey(const Key('notification-new-1')), findsNothing);
    await tester.tap(find.byKey(const Key('notification-card-1')));
    await tester.pumpAndSettle();
    expect(repository.readRequests, [1]);
    await backFromDetail(tester);
  });

  testWidgets('failed reads retain unread state and can be retried', (
    tester,
  ) async {
    final repository = FixtureNotificationRepository()..readFails = true;
    await pumpPage(tester, repository);
    await tester.tap(find.byKey(const Key('notification-card-1')));
    await tester.pumpAndSettle();
    await backFromDetail(tester);
    expect(find.byKey(const Key('notification-new-1')), findsOneWidget);
    repository.readFails = false;
    await tester.tap(find.byKey(const Key('notification-card-1')));
    await tester.pumpAndSettle();
    await backFromDetail(tester);
    expect(repository.readRequests, [1, 1]);
    expect(find.byKey(const Key('notification-new-1')), findsNothing);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets(
    'refresh preserves successful local read state against stale data',
    (tester) async {
      final repository = FixtureNotificationRepository();
      await pumpPage(tester, repository);
      await tester.tap(find.byKey(const Key('notification-card-1')));
      await tester.pumpAndSettle();
      await backFromDetail(tester);
      await tester.drag(
        find.byKey(const Key('notification-list-system')),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(
        repository.requests.where(
          (request) => request.$1 == NotificationType.system,
        ),
        hasLength(2),
      );
      expect(find.byKey(const Key('notification-new-1')), findsNothing);
    },
  );

  testWidgets('initial failures retry and display an empty inbox', (
    tester,
  ) async {
    final repository = FixtureNotificationRepository()
      ..failures.add((NotificationType.system, 1))
      ..pages[(NotificationType.system, 1)] = const NotificationListPage(
        items: [],
        hasMore: false,
      );
    await pumpPage(tester, repository);
    expect(
      find.text('Could not load notifications. Please retry.'),
      findsOneWidget,
    );
    repository.failures.clear();
    await tester.tap(find.byKey(const Key('notification-retry-system')));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(repository.requests, hasLength(2));
  });

  testWidgets(
    'failed pagination retries the same page and deduplicates deliveries',
    (tester) async {
      final repository = FixtureNotificationRepository()
        ..pages[(NotificationType.system, 1)] = NotificationListPage(
          items: [for (var i = 1; i <= 8; i++) fixtureNotification(i)],
          hasMore: true,
        )
        ..pages[(NotificationType.system, 2)] = NotificationListPage(
          items: [fixtureNotification(8), fixtureNotification(9)],
          hasMore: false,
        )
        ..failures.add((NotificationType.system, 2));
      await pumpPage(tester, repository);
      await tester.drag(
        find.byKey(const Key('notification-list-system')),
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();
      final retry = find.byKey(const Key('notification-retry-system'));
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      repository.failures.clear();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repository.requests, [
        (NotificationType.system, 1),
        (NotificationType.system, 2),
        (NotificationType.system, 2),
      ]);
      expect(find.byKey(const Key('notification-card-8')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('notification-card-9')));
      expect(find.byKey(const Key('notification-card-9')), findsOneWidget);
    },
  );

  testWidgets('switching users discards stale list responses', (tester) async {
    final pending = Completer<NotificationListPage>();
    final repository = FixtureNotificationRepository()..pending = pending;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: 'One', email: ''));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: notificationTestApp(NotificationsPage(repository: repository)),
      ),
    );
    await tester.pump();
    repository.pages[(NotificationType.system, 1)] = NotificationListPage(
      items: [fixtureNotification(7)],
      hasMore: false,
    );
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '2', name: 'Two', email: ''));
    await tester.pumpAndSettle();
    pending.complete(
      NotificationListPage(items: [fixtureNotification(99)], hasMore: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Announcement 7'), findsOneWidget);
    expect(find.text('Announcement 99'), findsNothing);
  });

  testWidgets('open detail hides private content after account changes', (
    tester,
  ) async {
    final repository = FixtureNotificationRepository();
    final container = await pumpPage(tester, repository);
    await tester.tap(find.byKey(const Key('notification-card-1')));
    await tester.pumpAndSettle();
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '2', name: 'Two', email: ''));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationDetailPage), findsOneWidget);
    expect(
      find.text('Full notification content 1.\nSecond line of the message.'),
      findsNothing,
    );
    expect(find.text('Sign in to view notifications'), findsOneWidget);
  });

  for (final web in [false, true]) {
    testWidgets(
      'detail opens ${web ? 'web' : 'native'} destinations and returns to inbox',
      (tester) async {
        final repository = FixtureNotificationRepository()
          ..pages[(NotificationType.system, 1)] = NotificationListPage(
            items: [
              fixtureNotification(
                1,
                target: web
                    ? NotificationTarget.web(
                        Uri.parse('https://example.com/news'),
                      )
                    : const NotificationTarget.page('/profile/membership'),
              ),
            ],
            hasMore: false,
          );
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container
            .read(userProvider.notifier)
            .setUser(const User(id: '1', name: 'User', email: ''));
        final router = GoRouter(
          initialLocation: '/notifications',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SizedBox()),
            GoRoute(
              path: '/notifications',
              builder: (_, _) => NotificationsPage(repository: repository),
            ),
            GoRoute(
              path: '/profile/membership',
              builder: (_, _) =>
                  const Scaffold(body: Text('Membership destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('notification-card-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('notification-detail-action')));
        await tester.pumpAndSettle();
        if (web) {
          expect(
            tester.widget<H5Page>(find.byType(H5Page)).url.toString(),
            'https://example.com/news',
          );
          await tester.tap(find.byTooltip('Back'));
        } else {
          expect(find.text('Membership destination'), findsOneWidget);
          router.pop();
        }
        await tester.pumpAndSettle();
        await backFromDetail(tester);
        expect(find.byType(NotificationsPage), findsOneWidget);
        expect(find.byKey(const Key('notification-new-1')), findsNothing);
      },
    );
  }

  for (final width in [320.0, 440.0, 1024.0]) {
    testWidgets('fits both tabs and long titles at $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FixtureNotificationRepository()
        ..pages[(NotificationType.personal, 1)] = const NotificationListPage(
          items: [
            AppNotification(
              id: 3,
              title: 'Membership expires tomorrow and requires renewal',
              content:
                  'A long message that wraps across several lines without covering other content.',
              isUnread: true,
              target: NotificationTarget.page('/profile/membership'),
            ),
          ],
          hasMore: false,
        );
      await pumpPage(tester, repository, theme: AppTheme.dark, scale: 1.4);
      await tester.tap(find.byKey(const Key('notification-tab-personal')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('notification-card-3')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
