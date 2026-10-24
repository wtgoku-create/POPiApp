import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_desktop_sidebar.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_menu.dart';

DemoSession _session(int index) => DemoSession(
  id: 'session-$index',
  title: '会话 $index',
  kind: DemoSessionKind.conversation,
  members: index.isEven ? const ['popi'] : const ['writer', 'designer'],
  roles: const [],
  messages: [
    DemoMessage(id: 'message-$index', text: '第 $index 条摘要', memberId: 'popi'),
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
    expect(find.text('第 0 条摘要'), findsOneWidget);
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
