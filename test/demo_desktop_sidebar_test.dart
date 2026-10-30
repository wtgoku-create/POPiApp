import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_desktop_sidebar.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_conversation_list_item.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_menu.dart';

DemoSession _session(
  int index, {
  bool pinned = false,
  DateTime? messageTime,
  String memberId = 'popi',
  String? memberName,
  String? title,
  DemoActivity? activity,
}) => DemoSession(
  id: 'session-$index',
  title: title ?? '会话 $index',
  kind: DemoSessionKind.conversation,
  members: index.isEven ? [memberId] : const ['writer', 'designer'],
  roles: const [],
  memberNames: memberName == null ? const {} : {memberId: memberName},
  pinned: pinned,
  messages: [
    DemoMessage(
      id: 'message-$index',
      text: '第 $index 条摘要',
      memberId: memberId,
      memberName: memberName ?? '',
      createdAt: messageTime,
      activity: activity,
    ),
  ],
);

Future<void> _pumpSidebar(
  WidgetTester tester, {
  required bool expanded,
  required List<DemoSession> sessions,
  String? selectedSessionId,
  ValueChanged<DemoSession>? onSelectSession,
  VoidCallback? onCreate,
  VoidCallback? onAssets,
  VoidCallback? onProfile,
  ValueChanged<String>? onSearch,
  bool assetsSelected = false,
  String query = '',
  List<AppMenuEntry> Function(DemoSession)? sessionMenuBuilder,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(expanded ? 280 : 80, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
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
      home: Scaffold(
        body: SizedBox(
          width: expanded ? 280 : 80,
          child: DemoDesktopSidebar(
            sessions: sessions,
            selectedSessionId: selectedSessionId,
            expanded: expanded,
            onSelectSession: onSelectSession ?? (_) {},
            onCreate: onCreate ?? () {},
            onAssets: onAssets ?? () {},
            onProfile: onProfile ?? () {},
            onSearch: onSearch ?? (_) {},
            profileAvatar: const CircleAvatar(child: Text('P')),
            assetsSelected: assetsSelected,
            query: query,
            sessionMenuBuilder: sessionMenuBuilder,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('expanded sidebar selects sessions and opens inline search', (
    tester,
  ) async {
    final sessions = List.generate(3, _session);
    DemoSession? selected;
    String? search;
    var creates = 0;
    await _pumpSidebar(
      tester,
      expanded: true,
      sessions: sessions,
      selectedSessionId: sessions.first.id,
      onSelectSession: (value) => selected = value,
      onCreate: () => creates++,
      onSearch: (value) => search = value,
      sessionMenuBuilder: (session) => [
        AppMenuItem(label: '置顶 ${session.title}', onSelected: () {}),
      ],
    );

    expect(find.byKey(const Key('demo-desktop-sidebar')), findsOneWidget);
    expect(find.text('会话 0'), findsOneWidget);
    expect(find.text('会话 0：第 0 条摘要'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.selected == true,
      ),
      findsOneWidget,
    );
    final menu = tester.widget<AppContextMenu>(
      find.byKey(const Key('demo-desktop-session-session-0')),
    );
    expect(menu.entries, hasLength(1));

    await tester.tap(find.byKey(const Key('demo-desktop-session-session-1')));
    expect(selected?.id, 'session-1');
    await tester.tap(find.byKey(const Key('demo-desktop-create')));
    expect(creates, 1);

    await tester.tap(find.byKey(const Key('demo-desktop-search')));
    await tester.pump();
    expect(find.byKey(const Key('demo-desktop-search-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('demo-desktop-search-field')),
      '摘要',
    );
    expect(search, '摘要');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expanded sidebar groups sessions and shows real sender, time, and activity',
    (tester) async {
      final now = DateTime.now();
      final timestamp = DateTime(now.year, now.month, now.day, 11, 10);
      final sessions = [
        _session(
          0,
          pinned: true,
          messageTime: timestamp,
          memberId: 'writer',
          memberName: '首席编剧',
          activity: const DemoActivity(kind: 'script', status: 'running'),
        ),
        _session(1, messageTime: timestamp.subtract(const Duration(days: 1))),
      ];

      await _pumpSidebar(
        tester,
        expanded: true,
        sessions: sessions,
        textScale: 1.5,
      );

      expect(
        find.byKey(const Key('demo-desktop-section-pinned')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('demo-desktop-section-recent')),
        findsOneWidget,
      );
      expect(find.text('首席编剧：第 0 条摘要'), findsOneWidget);
      final avatar = tester.widget<DemoAvatar>(
        find
            .descendant(
              of: find.byKey(const Key('demo-desktop-session-session-0')),
              matching: find.byType(DemoAvatar),
            )
            .first,
      );
      expect(avatar.members, const ['writer']);
      expect(
        find.descendant(
          of: find.byKey(const Key('demo-desktop-session-session-0')),
          matching: find.text('11:10'),
        ),
        findsOneWidget,
      );
      expect(find.text('昨天'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('demo-session-activity-session-0')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop search indexes the visible assistant name', (
    tester,
  ) async {
    await _pumpSidebar(
      tester,
      expanded: true,
      query: '首席编剧',
      sessions: [
        _session(0, memberId: 'writer', memberName: '首席编剧'),
        _session(1),
      ],
    );

    expect(
      find.byKey(const Key('demo-desktop-session-session-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('demo-desktop-session-session-1')),
      findsNothing,
    );
    expect(find.text('首席编剧：第 0 条摘要'), findsOneWidget);
  });

  testWidgets('legacy and configured single names drive title and search', (
    tester,
  ) async {
    final named = _session(0, title: '新建会话', memberName: '哈哈');
    final legacy = _session(2, title: 'Watt');
    await _pumpSidebar(
      tester,
      expanded: true,
      query: '哈哈',
      sessions: [named, legacy],
    );
    expect(find.text('哈哈'), findsOneWidget);
    expect(find.text('新建会话'), findsNothing);
    expect(find.text('Watt'), findsNothing);

    await _pumpSidebar(
      tester,
      expanded: false,
      query: 'Watt',
      sessions: [named, legacy],
    );
    expect(
      find.byKey(const Key('demo-desktop-session-session-2')),
      findsOneWidget,
    );
    expect(find.byTooltip('Watt'), findsOneWidget);
  });

  testWidgets('expanded sidebar keeps a long list virtualized', (tester) async {
    await _pumpSidebar(
      tester,
      expanded: true,
      sessions: List.generate(100, _session),
    );

    expect(
      find.byType(DemoConversationListItem).evaluate().length,
      lessThan(20),
    );
    expect(find.text('最近会话'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed rail keeps actions clear of virtual session list', (
    tester,
  ) async {
    final sessions = List.generate(100, _session);
    var assetTaps = 0;
    var profileTaps = 0;
    String? search;
    await _pumpSidebar(
      tester,
      expanded: false,
      sessions: sessions,
      onAssets: () => assetTaps++,
      onProfile: () => profileTaps++,
      onSearch: (value) => search = value,
      assetsSelected: true,
    );

    expect(find.byType(DemoAvatar).evaluate().length, lessThan(20));
    expect(find.byTooltip('会话 0'), findsOneWidget);
    final listRect = tester.getRect(find.byType(ListView));
    final assetsRect = tester.getRect(
      find.byKey(const Key('demo-desktop-assets')),
    );
    expect(listRect.bottom, lessThanOrEqualTo(assetsRect.top));

    await tester.tap(find.byKey(const Key('demo-desktop-assets')));
    await tester.tap(find.byKey(const Key('demo-desktop-profile')));
    expect(assetTaps, 1);
    expect(profileTaps, 1);

    await tester.tap(find.byKey(const Key('demo-desktop-search')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('demo-desktop-search-field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, '会话 9');
    expect(search, '会话 9');
    expect(tester.takeException(), isNull);
  });
}
