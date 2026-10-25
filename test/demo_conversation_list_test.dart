import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_activity_indicator.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_conversation_list_item.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

const _captureEnabled = bool.fromEnvironment('CONVERSATION_LIST_SCREENSHOTS');
final _captureKey = GlobalKey();

Future<void> _pumpWidget(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  bool dark = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  ThemeData captureTheme(ThemeData theme) => !_captureEnabled
      ? theme
      : theme.copyWith(
          textTheme: theme.textTheme.apply(
            fontFamily: 'ConversationListCapture',
          ),
        );
  final lightTheme = AppTheme.light.copyWith(
    scaffoldBackgroundColor: AppColors.profileBackground,
    appBarTheme: AppTheme.light.appBarTheme.copyWith(
      backgroundColor: AppColors.profileBackground,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(lightTheme),
            darkTheme: captureTheme(AppTheme.dark),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DemoSession _session({
  required String id,
  required String title,
  List<String> members = const ['designer'],
  List<DemoMessage> messages = const [],
  Map<String, String> memberNames = const {},
  Map<String, String> memberAvatars = const {},
  Map<String, int> memberColors = const {},
  String time = '11:10',
}) => DemoSession(
  id: id,
  title: title,
  kind: DemoSessionKind.conversation,
  members: members,
  roles: const [],
  messages: messages,
  memberNames: memberNames,
  memberAvatars: memberAvatars,
  memberColors: memberColors,
  activeMemberId: members.first,
  time: time,
);

Future<DemoRepository> _repository() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return DemoRepository(PreferencesStorage(preferences));
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureEnabled) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/conversation-list/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  setUpAll(() async {
    if (!_captureEnabled) return;
    final font = File('/System/Library/Fonts/Hiragino Sans GB.ttc');
    if (font.existsSync()) {
      await (FontLoader(
        'ConversationListCapture',
      )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('row uses saved identity, named summary, time, and activity', (
    tester,
  ) async {
    final session = _session(
      id: 'rabbit',
      title: '南极的咖啡馆',
      messages: const [
        DemoMessage(
          id: 'reply',
          text: '角色参考图已经准备好了。',
          memberId: 'designer',
          activity: DemoActivity(kind: 'image', status: 'running'),
        ),
      ],
      memberNames: const {'designer': '兜兜'},
      memberAvatars: const {
        'designer': 'assets/animations/bot_avatars/rabbit.png',
      },
      memberColors: const {'designer': 0xFFFFF3D9},
    );
    await _pumpWidget(
      tester,
      Scaffold(
        body: DemoConversationListItem(session: session, onTap: () {}),
      ),
    );

    expect(find.text('兜兜'), findsOneWidget);
    expect(find.text('南极的咖啡馆'), findsNothing);
    expect(find.text('兜兜：角色参考图已经准备好了。'), findsOneWidget);
    expect(find.text('11:10'), findsOneWidget);
    expect(find.byType(DemoActivityIndicator), findsOneWidget);
    expect(find.byKey(const Key('demo-activity-avatar')), findsOneWidget);
    final avatars = tester
        .widgetList<DemoAvatar>(find.byType(DemoAvatar))
        .toList();
    expect(avatars.first.members, ['designer']);
    expect(avatars.first.memberAvatars, session.memberAvatars);
    expect(avatars.first.memberColors, session.memberColors);
    final semantics = tester.getSemantics(
      find.byType(DemoConversationListItem),
    );
    expect(RegExp('兜兜').allMatches(semantics.label).length, 1);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('single assistant uses its given name or legacy named title', (
    tester,
  ) async {
    for (final session in [
      _session(
        id: 'named',
        title: '新建会话',
        members: const ['popi'],
        memberNames: const {'popi': '哈哈'},
        messages: const [
          DemoMessage(id: 'named-message', text: '你好', memberId: 'popi'),
        ],
      ),
      _session(
        id: 'legacy',
        title: 'Watt',
        members: const ['popi'],
        messages: const [
          DemoMessage(id: 'legacy-message', text: '你好', memberId: 'popi'),
        ],
      ),
    ]) {
      await _pumpWidget(
        tester,
        Scaffold(
          body: DemoConversationListItem(session: session, onTap: () {}),
        ),
      );
      final expected = session.id == 'named' ? '哈哈' : 'Watt';
      expect(find.text(expected), findsOneWidget);
      expect(find.text('$expected：你好'), findsOneWidget);
      expect(find.text('POPi：你好'), findsNothing);
    }
  });

  testWidgets('dense row constrains a full date at large text scale', (
    tester,
  ) async {
    final session = _session(
      id: 'old',
      title: '一个很长的会话名称用于窄屏验证',
      messages: const [DemoMessage(id: 'reply', text: '消息摘要也需要保留足够空间。')],
      time: '2025年10月23日',
    );
    await _pumpWidget(
      tester,
      Scaffold(
        body: SizedBox(
          width: 280,
          child: DemoConversationListItem(
            session: session,
            dense: true,
            onTap: () {},
          ),
        ),
      ),
      size: const Size(320, 640),
      textScale: 1.5,
    );

    expect(find.text('一个很长的会话名称用于窄屏验证'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group row keeps stable composite identity and remains compact', (
    tester,
  ) async {
    final session = _session(
      id: 'group',
      title: '夏日短片创作组',
      members: const ['popi', 'designer'],
      messages: const [
        DemoMessage(
          id: 'reply',
          text: '这个结尾可以再温暖一点。',
          memberId: 'writer',
          memberName: '首席编剧',
        ),
      ],
      time: '昨天',
    );
    await _pumpWidget(
      tester,
      Scaffold(
        body: SizedBox(
          width: 280,
          child: DemoConversationListItem(
            session: session,
            dense: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('首席编剧：这个结尾可以再温暖一点。'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(tester.widget<DemoAvatar>(find.byType(DemoAvatar)).members, [
      'popi',
      'designer',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile inbox groups, searches, and keeps builder virtualization',
    (tester) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      await repository.updateSession(
        'ding',
        (session) => session.copyWith(
          pinned: true,
          messages: [
            ...session.messages,
            const DemoMessage(
              id: 'active',
              text: '',
              memberId: 'designer',
              activity: DemoActivity(kind: 'script', status: 'running'),
            ),
          ],
        ),
      );
      await _pumpWidget(tester, DemoHomePage(repository: repository));

      final l = AppLocalizations.of(tester.element(find.byType(DemoHomePage)))!;
      expect(find.text(l.demoPinnedConversations), findsOneWidget);
      expect(find.text(l.demoRecentConversations), findsOneWidget);
      expect(find.text(l.demoConversations), findsWidgets);
      expect(find.text(l.demoAssets), findsOneWidget);
      expect(find.byType(AppContextMenu), findsWidgets);
      final list = tester.widget<ListView>(
        find.byKey(const PageStorageKey('demo-conversations')),
      );
      expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());

      await tester.tap(find.byKey(const Key('demo-search-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('demo-mobile-search')), findsOneWidget);
      await tester.enterText(find.byType(TextField), '生成选题');
      await tester.pumpAndSettle();
      expect(find.text('叮叮制作组'), findsOneWidget);
      expect(find.text('校园vlog'), findsNothing);
      await tester.tap(find.byKey(const Key('demo-search-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('demo-mobile-search')), findsNothing);
      expect(find.text('叮叮制作组'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (name: 'mobile-light', dark: false, scale: 1.0),
    (name: 'mobile-dark', dark: true, scale: 1.0),
    (name: 'mobile-compact', dark: false, scale: 1.35),
  ]) {
    testWidgets('${scenario.name} conversation list has no overflow', (
      tester,
    ) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      await repository.updateSession(
        'ding',
        (session) => session.copyWith(
          pinned: true,
          messages: [
            ...session.messages,
            const DemoMessage(
              id: 'active-capture',
              text: '',
              memberId: 'designer',
              activity: DemoActivity(kind: 'script', status: 'running'),
            ),
          ],
        ),
      );
      await _pumpWidget(
        tester,
        DemoHomePage(repository: repository),
        size: const Size(390, 844),
        dark: scenario.dark,
        textScale: scenario.scale,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, scenario.name);
    });
  }
}
