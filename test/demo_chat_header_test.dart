import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_chat_header.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

const _singleTitle = '这是一个会在窄屏上截断的非常长的角色名称';

DemoSession _session({
  List<String> members = const ['popi'],
  Map<String, String> memberNames = const {'popi': _singleTitle},
  List<DemoMessage>? messages,
}) => DemoSession(
  id: 'header-session',
  title: '头部测试会话',
  kind: DemoSessionKind.project,
  members: members,
  roles: const [],
  memberNames: memberNames,
  messages:
      messages ??
      const [DemoMessage(id: 'first', text: '最靠近页头的首条消息', memberId: 'popi')],
);

Future<DemoRepository> _repository(DemoSession session) async {
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': [session.toJson()],
      'assets': const <Object?>[],
    }),
  });
  return DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
}

Future<void> _pumpChat(
  WidgetTester tester,
  DemoSession session, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('zh'),
  ThemeData? theme,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = await _repository(session);
  addTearDown(repository.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-chat'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DemoChatPage(
                        repository: repository,
                        sessionId: session.id,
                      ),
                    ),
                  ),
                  child: const Text('打开会话'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-chat')));
  await tester.pumpAndSettle();
}

Finder _inTitle(Finder matching) => find.descendant(
  of: find.byKey(const Key('demo-chat-title')),
  matching: matching,
);

Size _glassSize(WidgetTester tester, Key buttonKey) {
  final filter = find.descendant(
    of: find.byKey(buttonKey),
    matching: find.byType(BackdropFilter),
  );
  expect(filter, findsOneWidget);
  return tester.getSize(filter);
}

void main() {
  testWidgets('single chat header follows the reference control proportions', (
    tester,
  ) async {
    await _pumpChat(tester, _session(memberNames: const {'popi': 'POPi'}));

    final title = find.byKey(const Key('demo-chat-title'));
    final back = find.byKey(const Key('demo-chat-back'));
    final settings = find.byKey(const Key('demo-settings'));
    expect(tester.getSize(title).height, closeTo(50, .01));
    expect(tester.getSize(back), const Size.square(40));
    expect(tester.getSize(settings), const Size.square(40));
    expect(
      _glassSize(tester, const Key('demo-chat-back')),
      const Size.square(36),
    );
    expect(
      _glassSize(tester, const Key('demo-settings')),
      const Size.square(36),
    );

    final avatar = _inTitle(find.byType(DemoAvatar));
    expect(avatar, findsOneWidget);
    expect(tester.getSize(avatar), const Size.square(30));
    expect(tester.getCenter(title).dx, closeTo(195, .01));
    expect(tester.getCenter(back).dx, lessThan(tester.getCenter(title).dx));
    expect(
      tester.getCenter(settings).dx,
      greaterThan(tester.getCenter(title).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'three group avatars overlap horizontally and title stays centered',
    (tester) async {
      await _pumpChat(
        tester,
        _session(
          members: const ['popi', 'writer', 'designer'],
          memberNames: const {},
        ),
      );

      final title = find.byKey(const Key('demo-chat-title'));
      final avatars = _inTitle(find.byType(DemoAvatar));
      expect(avatars, findsNWidgets(3));
      final rects =
          avatars
              .evaluate()
              .map((element) => tester.getRect(find.byWidget(element.widget)))
              .toList()
            ..sort((a, b) => a.left.compareTo(b.left));
      expect(
        rects.map((rect) => rect.size),
        everyElement(const Size.square(30)),
      );
      expect(rects[1].left - rects[0].left, closeTo(17, .01));
      expect(rects[2].left - rects[1].left, closeTo(17, .01));
      expect(rects[0].right, greaterThan(rects[1].left));
      expect(tester.getCenter(title).dx, closeTo(195, .01));
      expect(find.text('POPi等3人'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow large text truncates the visual title but exposes it fully',
    (tester) async {
      await _pumpChat(
        tester,
        _session(),
        size: const Size(320, 760),
        textScale: 1.5,
      );

      final title = find.byKey(const Key('demo-chat-title'));
      final titleText = tester.widget<Text>(_inTitle(find.text(_singleTitle)));
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
      expect(find.byTooltip(_singleTitle), findsOneWidget);
      final leftButton = tester.getRect(
        find.byKey(const Key('demo-chat-back')),
      );
      final rightButton = tester.getRect(
        find.byKey(const Key('demo-settings')),
      );
      final titleRect = tester.getRect(title);
      expect(titleRect.left, greaterThanOrEqualTo(leftButton.right));
      expect(titleRect.right, lessThanOrEqualTo(rightButton.left));
      expect(tester.getCenter(title).dx, closeTo(160, .01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'English group header supports dark mode and limits avatars to three',
    (tester) async {
      await _pumpChat(
        tester,
        _session(
          members: const ['popi', 'writer', 'designer', 'director'],
          memberNames: const {},
        ),
        size: const Size(320, 760),
        locale: const Locale('en'),
        theme: AppTheme.dark,
        textScale: 1.5,
      );

      expect(find.text('POPi + 4 Bots'), findsOneWidget);
      expect(_inTitle(find.byType(DemoAvatar)), findsNWidgets(3));
      final text = tester.widget<Text>(_inTitle(find.text('POPi + 4 Bots')));
      expect(text.style?.color, AppTheme.dark.colorScheme.onSurface);
      expect(find.byType(DemoChatHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('title and settings open settings while header back returns', (
    tester,
  ) async {
    await _pumpChat(tester, _session(memberNames: const {'popi': 'POPi'}));

    await tester.tap(find.byKey(const Key('demo-chat-title')));
    await tester.pumpAndSettle();
    expect(find.byType(DemoSettingsPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(DemoSettingsPage))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('demo-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(DemoSettingsPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(DemoSettingsPage))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('demo-chat-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-chat')), findsOneWidget);
    expect(find.byType(DemoChatPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'messages start below the floating toolbar and scroll underneath',
    (tester) async {
      final messages = [
        for (var index = 0; index < 18; index++)
          DemoMessage(
            id: 'message-$index',
            text: index == 0
                ? '最靠近页头的首条消息'
                : '消息 $index：这是用于验证页头浮在滚动内容上方的较长文本。',
            memberId: 'popi',
          ),
      ];
      await _pumpChat(
        tester,
        _session(memberNames: const {'popi': 'POPi'}, messages: messages),
      );

      final header = tester.getRect(find.byType(DemoChatHeader));
      final first = find.text('最靠近页头的首条消息');
      expect(first, findsOneWidget);
      expect(tester.getTopLeft(first).dy, greaterThanOrEqualTo(header.bottom));

      final chatScrollable = find
          .descendant(
            of: find.byType(DemoChatPage),
            matching: find.byType(Scrollable),
          )
          .first;
      final scrollPosition = tester
          .state<ScrollableState>(chatScrollable)
          .position;
      await tester.drag(chatScrollable, const Offset(0, -500));
      await tester.pumpAndSettle();

      final visibleMessages = find.descendant(
        of: find.byType(DemoChatPage),
        matching: find.textContaining('消息'),
      );
      final movedUnderHeader = visibleMessages.evaluate().any((element) {
        final render = element.findRenderObject();
        if (render is! RenderBox || !render.attached) return false;
        return render.localToGlobal(Offset.zero).dy < header.bottom;
      });
      expect(movedUnderHeader, isTrue);

      final offsetBeforeHeaderGapDrag = scrollPosition.pixels;
      final headerGap = Offset(80, header.center.dy);
      expect(
        tester
            .getRect(find.byKey(const Key('demo-chat-back')))
            .contains(headerGap),
        isFalse,
      );
      expect(
        tester
            .getRect(find.byKey(const Key('demo-chat-title')))
            .contains(headerGap),
        isFalse,
      );
      await tester.dragFrom(headerGap, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(scrollPosition.pixels, greaterThan(offsetBeforeHeaderGapDrag));

      expect(
        find.byKey(const Key('demo-chat-back')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('demo-settings')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
