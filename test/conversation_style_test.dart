import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/role_detail_page.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_profile_sheet.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card_content.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_selected_topic_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'conversation_controller_test.dart' show StreamingSessionRepository;
import 'conversation_events_test.dart'
    show chatId, chatEvent, chatMessageJson, chatSnapshotJson;

final _captureKey = GlobalKey();
final _captureDirectory = Platform.environment['CHAT_UX_SCREENSHOTS'];

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDirectory == null) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_captureDirectory!).create(recursive: true);
    await File(
      '$_captureDirectory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Map<String, Object?> _topic(
  String id, {
  String scopeId = '301',
  String action = 'generated',
  String? title,
}) => {
  'type': 'object',
  'kind': 'topic',
  'action': action,
  'scope': {'kind': 'creation', 'id': scopeId},
  'data': {
    'ref': {'kind': 'topic', 'id': id},
    'title': title ?? 'Topic $id',
    'summary':
        '### 故事梗概\n\nStory $id\n\n'
        '### 适合角色的原因\n\nA warm, quiet afternoon together.\n\n'
        '### 核心看点\n\nA playful moment in a familiar home.',
  },
};

Map<String, Object?> _castRole(
  String id,
  String title, {
  String scopeId = '301',
  String action = 'cast',
}) => {
  'type': 'object',
  'kind': 'role',
  'action': action,
  'scope': {'kind': 'session', 'id': scopeId},
  'data': {
    'ref': {'kind': 'role', 'id': id, 'versionId': 'saved-$id'},
    'title': title,
    'status': 'active',
    'avatar': 'assets/images/role_guide_avatar_${id == '1' ? 1 : 2}.png',
    'profile': {'title': title, 'description': 'Saved profile $id'},
  },
};

Future<StreamingSessionRepository> _pumpTopicPage(
  WidgetTester tester,
  List<Map<String, Object?>> blocks, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('zh'),
  bool dark = false,
  double scale = 1,
  bool sentByUser = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = StreamingSessionRepository()
    ..data = chatSnapshotJson(
      seq: 1,
      messages: [
        {
          ...chatMessageJson(),
          if (sentByUser) 'role': 'user',
          'blocks': blocks,
        },
      ],
    );
  final container = ProviderContainer(
    overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(() async {
    container.dispose();
    await repository.close();
  });
  await container
      .read(userProvider.notifier)
      .setUser(const User(id: 'a', name: 'User', email: ''));
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _captureDirectory == null
              ? theme
              : theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'ChatCapture'),
                ),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const SessionPage(sessionId: chatId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUpAll(() async {
    // Optional local captures use a real CJK font; CI has no system-font dependency.
    if (_captureDirectory != null) {
      final font = FontLoader('ChatCapture');
      font.addFont(
        File(
          '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final (name, size, locale, dark, scale) in [
    ('mobile', const Size(390, 844), const Locale('zh'), false, 1.0),
    ('desktop', const Size(1280, 900), const Locale('en'), false, 1.0),
    ('accessible-dark', const Size(320, 844), const Locale('en'), true, 1.5),
  ]) {
    testWidgets('confirmed topic reads and collapses at $name', (tester) async {
      final chinese = locale.languageCode == 'zh';
      final title = chinese
          ? '来财的专属晒太阳角落'
          : 'A quiet afternoon in a sunny cardboard home';
      final story = chinese
          ? '午后的阳光落在窗边，来财抱着自己的小纸箱，认真寻找最暖和的位置。'
                '当朋友悄悄靠近，它把纸箱挪出一点空间，邀请对方一起享受这段安静的时光。'
          : 'Afternoon sunlight reaches the window. Carrying a small cardboard '
                'box, the character searches for the warmest corner. When a friend '
                'arrives, it quietly makes room to share a peaceful moment.';
      final hook = chinese
          ? '从独占阳光到主动分享，用一个小动作完成温暖的转变。'
          : 'A small gesture turns a private sunny corner into a shared home.';
      Map<String, Object?> topic({bool long = false}) {
        final value = _topic('confirmed', action: 'selected', title: title);
        final data = value['data'] as Map<String, Object?>;
        data['summary'] = chinese
            ? '### 故事梗概\n\n$story'
            : '### Synopsis\n\n$story';
        if (long) {
          data['summary'] =
              '${data['summary']}\n\n'
              '${List.generate(15, (index) => '$index. $story').join('\n\n')}';
        }
        data['hook'] = hook;
        return value;
      }

      final repository = await _pumpTopicPage(
        tester,
        [
          {'type': 'text', 'text': chinese ? '确认这个选题' : 'Use this story'},
          topic(),
        ],
        size: size,
        locale: locale,
        dark: dark,
        scale: scale,
        sentByUser: true,
      );
      final card = find.byType(ConversationSelectedTopicCard);
      final content = find.byType(ConversationCardContent);
      final toggle = find.byKey(
        const Key('conversation-selected-topic-toggle'),
      );
      final l10n = lookupAppLocalizations(locale);
      expect(card, findsOneWidget);
      final cardRect = tester.getRect(card);
      expect(cardRect.width, closeTo((size.width - 40).clamp(0, 640), .01));
      expect(
        tester
            .getBottomLeft(find.text(chinese ? '确认这个选题' : 'Use this story'))
            .dy,
        lessThan(cardRect.top),
      );
      expect(find.text(l10n.chatTopicConfirmed), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.text(hook), findsOneWidget);
      expect(find.byKey(const Key('conversation-topic-select')), findsNothing);
      expect(find.byKey(const Key('conversation-topic-refresh')), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.getSize(content).height, lessThanOrEqualTo(320));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await _capture(tester, '$name-confirmed-topic');
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(content, findsNothing);
      expect(find.text(title), findsOneWidget);
      expect(find.byTooltip(l10n.chatExpandStory), findsOneWidget);
      await _capture(tester, '$name-confirmed-topic-collapsed');
      repository.streams.single.add(
        chatEvent(2, 'message.updated', {
          'timelineUpdates': [
            {
              ...chatMessageJson(revision: 2),
              'role': 'user',
              'blocks': [topic(long: true)],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(content, findsNothing);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.ensureVisible(content);
      await tester.pumpAndSettle();
      await tester.drag(content, const Offset(0, -150));
      await tester.pumpAndSettle();
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find
                .descendant(of: content, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      final offset = position().pixels;
      expect(offset, greaterThan(0));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(position().pixels, closeTo(offset, .01));
      expect(repository.sends, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('topics share one card and retain the selected item at $name', (
      tester,
    ) async {
      final title = locale.languageCode == 'zh'
          ? '来财的专属晒太阳角落'
          : 'A quiet afternoon in a sunny cardboard home';
      final topics = [_topic('1', title: title), _topic('2'), _topic('3')];
      const intro = {'type': 'text', 'text': 'Recommendations'};
      const ending = {'type': 'text', 'text': 'Choose your favorite story.'};
      final repository = await _pumpTopicPage(
        tester,
        [intro, ...topics, ending],
        size: size,
        locale: locale,
        dark: dark,
        scale: scale,
      );
      final previous = find.byKey(const Key('conversation-topic-previous'));
      final next = find.byKey(const Key('conversation-topic-next'));
      expect(find.byType(ConversationObjectView), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Story 1'), findsOneWidget);
      expect(find.text('Story 2'), findsNothing);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(ConversationObjectView));
      final button = tester.getRect(next);
      for (final key in [
        'conversation-topic-refresh',
        'conversation-topic-select',
      ]) {
        final action = tester.getRect(find.byKey(Key(key)));
        expect(action.left, greaterThanOrEqualTo(card.left + 20));
        expect(action.right, lessThanOrEqualTo(card.right - 20));
        expect(action.bottom, lessThanOrEqualTo(card.bottom - 20));
      }
      expect(button.right, closeTo(card.right - 20, .01));
      expect(button.top, closeTo(card.top + 24, .01));
      expect(
        button.center.dx - tester.getCenter(previous).dx,
        closeTo(24, .01),
      );
      await _capture(tester, '$name-topics-first');
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Story 1'), findsNothing);
      expect(find.text('Story 2'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      await _capture(tester, '$name-topics-second');
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      repository.streams.first.add(
        chatEvent(2, 'message.updated', {
          'timelineUpdates': [
            {
              ...chatMessageJson(revision: 2),
              'blocks': [
                intro,
                _topic('2', title: 'Updated topic 2'),
                topics[2],
                topics[0],
                ending,
              ],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated topic 2'), findsOneWidget);
      expect(find.text('Story 2'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      repository.streams.first.add(
        chatEvent(3, 'message.updated', {
          'timelineUpdates': [
            {
              ...chatMessageJson(revision: 3),
              'blocks': [intro, topics[0], ending],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Story 1'), findsOneWidget);
      expect(next, findsNothing);
      expect(previous, findsNothing);
      expect(find.text('Recommendations'), findsOneWidget);
      expect(find.text('Choose your favorite story.'), findsOneWidget);
      expect(repository.sends, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('cast role uses the horizontal reference layout at $name', (
      tester,
    ) async {
      const title = '来财';
      const description = '橘纹软萌橘猫，裹着毛边白背心，顽固坚守自己的晒太阳角落。';
      await _pumpTopicPage(
        tester,
        [
          {
            'type': 'object',
            'kind': 'role',
            'action': 'cast',
            'data': {
              'title': title,
              'status': 'active',
              'avatar': 'assets/images/role_guide_avatar_1.png',
              'profile': {'description': description},
            },
          },
        ],
        size: size,
        locale: locale,
        dark: dark,
        scale: scale,
        sentByUser: true,
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/role_guide_avatar_1.png'),
          tester.element(find.text(title)),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(
        find.byKey(const Key('conversation-role-summary')),
      );
      final portrait = tester.getRect(
        find.byKey(const Key('conversation-role-portrait')),
      );
      final titleRect = tester.getRect(find.text(title));
      final descriptionRect = tester.getRect(find.text(description));
      expect(portrait.size, const Size(44, 44));
      expect(titleRect.left, closeTo(portrait.right + 18, .01));
      expect(descriptionRect.left, closeTo(titleRect.left, .01));
      expect(descriptionRect.right, lessThanOrEqualTo(card.right - 16));
      expect(tester.widget<Text>(find.text(description)).maxLines, 1);
      expect(tester.takeException(), isNull);
      await _capture(tester, '$name-role-summary');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'multiple cast roles share a card and snapshot preview at $name',
      (tester) async {
        final first = locale.languageCode == 'zh' ? '来财' : 'Alice';
        final second = locale.languageCode == 'zh' ? '来福' : 'Bob';
        final cast = [_castRole('1', first), _castRole('2', second)];
        final repository = await _pumpTopicPage(
          tester,
          [
            const {'type': 'text', 'text': 'Cast updated'},
            ...cast,
          ],
          size: size,
          locale: locale,
          dark: dark,
          scale: scale,
          sentByUser: true,
        );
        final card = find.byKey(const Key('conversation-cast-summary'));
        expect(card, findsOneWidget);
        expect(
          find.byKey(const Key('conversation-role-summary')),
          findsNothing,
        );
        expect(find.text('$first、$second'), findsOneWidget);
        final context = tester.element(card);
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(l10n.roleCastCount(2)), findsOneWidget);
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/images/role_guide_avatar_1.png'),
            context,
          );
          await precacheImage(
            const AssetImage('assets/images/role_guide_avatar_2.png'),
            context,
          );
        });
        await tester.pumpAndSettle();
        final names = tester.getRect(find.text('$first、$second'));
        expect(names.right, lessThanOrEqualTo(tester.getRect(card).right - 10));
        expect(tester.takeException(), isNull);
        await _capture(tester, '$name-cast-summary');
        await tester.tap(find.byKey(const Key('role-guide-view-profiles')));
        await tester.pumpAndSettle();
        final sheet = tester.widget<RoleProfileSheet>(
          find.byType(RoleProfileSheet),
        );
        expect(sheet.useSnapshot, isTrue);
        expect(sheet.roles.map((role) => role.id), ['1', '2']);
        expect(sheet.roles.map((role) => role.profileVersionId), [
          'saved-1',
          'saved-2',
        ]);
        expect(
          tester.widget<RoleDetailPage>(find.byType(RoleDetailPage)).role.id,
          '1',
        );
        await tester.tap(find.byTooltip(l10n.roleNextProfile));
        await tester.pumpAndSettle();
        expect(
          tester.widget<RoleDetailPage>(find.byType(RoleDetailPage)).role.id,
          '2',
        );
        await tester.tap(find.byTooltip(l10n.rolePreviousProfile));
        await tester.pumpAndSettle();
        expect(
          tester.widget<RoleDetailPage>(find.byType(RoleDetailPage)).role.id,
          '1',
        );
        Navigator.of(tester.element(find.byType(RoleProfileSheet))).pop();
        await tester.pumpAndSettle();
        repository.streams.first.add(
          chatEvent(2, 'message.updated', {
            'timelineUpdates': [
              {
                ...chatMessageJson(revision: 2),
                'role': 'user',
                'blocks': [
                  ...cast,
                  _castRole(
                    '3',
                    List.filled(12, 'Long character name').join(' '),
                  ),
                ],
              },
            ],
          }),
        );
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
        expect(find.text(l10n.roleCastCount(3)), findsOneWidget);
        expect(find.text(l10n.roleCastCount(2)), findsNothing);
        expect(tester.takeException(), isNull);
        await _capture(tester, '$name-cast-summary-updated');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('compact role card previews the streamed profile at $name', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final role = <String, Object?>{
        'id': 'role-draft',
        'title': locale.languageCode == 'zh'
            ? '校园爱丽丝'
            : 'Alice in the schoolyard',
        'status': 'draft',
        'profile': {
          'description': locale.languageCode == 'zh'
              ? '叮叮的同桌、室友和闺蜜。'
              : 'A classmate, roommate and close friend.',
          'expressionStyle': locale.languageCode == 'zh'
              ? '轻松日常，略带幽默'
              : 'Relaxed, warm and a little witty',
          'targetAudience': locale.languageCode == 'zh'
              ? '校园故事的读者'
              : 'Readers of school stories',
          'contentTags': ['校园', '可爱角色'],
          'profileData': {
            'personality': {'label': '性格', 'value': '认真、温柔'},
          },
        },
      };
      Map<String, Object?> roleMessage(int revision) => {
        ...chatMessageJson(revision: revision, seq: 2),
        'blocks': [
          {'type': 'object', 'kind': 'role', 'action': 'created', 'data': role},
        ],
      };
      final repository = StreamingSessionRepository()
        ..data = chatSnapshotJson(
          seq: 2,
          messages: [
            {
              ...chatMessageJson(
                text: locale.languageCode == 'zh'
                    ? '我想制作一个可爱的萌宠角色'
                    : 'Create a friendly character for my story.',
              ),
              'id': 'user-message',
              'role': 'user',
            },
            roleMessage(1),
          ],
        );
      final container = ProviderContainer(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'a', name: 'User', email: ''));
      final theme = dark ? AppTheme.dark : AppTheme.light;
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _captureDirectory == null
                  ? theme
                  : theme.copyWith(
                      textTheme: theme.textTheme.apply(
                        fontFamily: 'ChatCapture',
                      ),
                    ),
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const SessionPage(sessionId: chatId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = find.byKey(const Key('conversation-role-view-profile'));
      expect(find.text('校园, 可爱角色'), findsNothing);
      expect(find.text('认真、温柔'), findsNothing);
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      await _capture(tester, '$name-draft');
      role['title'] = 'Updated Alice';
      repository.streams.first.add(
        chatEvent(3, 'message.updated', {
          'timelineUpdates': [roleMessage(2)],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated Alice'), findsOneWidget);
      expect(find.text('校园, 可爱角色'), findsNothing);
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      await tester.tap(preview);
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('conversation-role-profile'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Updated Alice')),
        findsOneWidget,
      );
      await _capture(tester, '$name-role-profile');
      final toggle = find.byKey(const Key('role-profile-toggle'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.descendant(of: sheet, matching: find.text('认真、温柔')),
        150,
        scrollable: find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .first,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('认真、温柔')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.text('校园, 可爱角色'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('cast groups preserve text, scope and role action boundaries', (
    tester,
  ) async {
    await _pumpTopicPage(tester, [
      _castRole('1', 'Alice'),
      _castRole('2', 'Bob'),
      const {'type': 'text', 'text': 'Another cast'},
      _castRole('3', 'Carol'),
      _castRole('4', 'David', scopeId: '302'),
      _castRole('5', 'Edited draft', action: 'edited'),
    ], sentByUser: true);
    expect(find.byKey(const Key('conversation-cast-summary')), findsOneWidget);
    expect(
      find.byKey(const Key('conversation-role-summary')),
      findsNWidgets(2),
    );
    expect(find.byKey(const Key('conversation-role-card')), findsOneWidget);
    expect(find.text('Alice、Bob'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('David'), findsOneWidget);
    expect(find.text('Edited draft'), findsOneWidget);
    expect(find.text('Another cast'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('user role objects use full card width outside the text bubble', (
    tester,
  ) async {
    await _pumpTopicPage(tester, [
      {'type': 'text', 'text': 'Use this character'},
      {
        'type': 'object',
        'kind': 'role',
        'action': 'created',
        'data': {'title': 'Saved draft', 'status': 'draft'},
      },
    ], sentByUser: true);
    final card = tester.getRect(
      find.byKey(const Key('conversation-role-card')),
    );
    expect(card.left, closeTo(20, .01));
    expect(card.width, closeTo(350, .01));
    final text = tester.getRect(find.text('Use this character'));
    expect(text.right, lessThanOrEqualTo(card.right));
    expect(text.bottom, lessThan(card.top));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('topic groups preserve text boundaries, scopes and selections', (
    tester,
  ) async {
    await _pumpTopicPage(tester, [
      _topic('1'),
      _topic('2'),
      {'type': 'text', 'text': 'Another batch'},
      _topic('3'),
      _topic('4', scopeId: '302'),
      _topic('5', action: 'selected'),
    ]);
    expect(find.byType(ConversationObjectView), findsNWidgets(4));
    expect(find.byKey(const Key('conversation-topic-next')), findsOneWidget);
    expect(find.text('Topic 2'), findsNothing);
    expect(find.text('Topic 3'), findsOneWidget);
    expect(find.text('Topic 4'), findsOneWidget);
    expect(find.text('Topic 5'), findsOneWidget);
    expect(find.text('Another batch'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'progress collapses and generation uses the shared confirmation dialog',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = StreamingSessionRepository();
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      final progress = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'progress',
        'data': {
          'state': 'running',
          'steps': [
            {'labelKey': 'script.run.preparing', 'status': 'completed'},
            {
              'labelKey': 'pages.studio.progress.readRole',
              'status': 'completed',
            },
            {'labelKey': 'script.run.generatingReply', 'status': 'running'},
          ],
        },
      });
      final plan = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'plan',
        'data': {
          'id': 'plan',
          'kind': 'generation',
          'title': '角色图生成方案',
          'status': 'ready',
          'body': '让校园爱丽丝穿着校服，站在温暖的校园里。',
          'estimatedPoints': 675,
          'plan': {
            'items': [
              {
                'key': 'image',
                'mediaType': 'image',
                'modelId': 'model',
                'params': {},
                'prompt': '让校园爱丽丝穿着校服，站在温暖的校园里。',
              },
            ],
          },
          'allowedActions': ['confirm', 'cancel'],
        },
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _captureDirectory == null
                ? AppTheme.light
                : AppTheme.light.copyWith(
                    textTheme: AppTheme.light.textTheme.apply(
                      fontFamily: 'ChatCapture',
                    ),
                  ),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEDE9FD), Colors.white],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 40),
                    ConversationObjectView(
                      block: progress,
                      controller: controller,
                    ),
                    ConversationObjectView(block: plan, controller: controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('正在读取角色档案'), findsOneWidget);
      await _capture(tester, 'mobile-progress-plan');
      await tester.tap(find.byTooltip('收起进度'));
      await tester.pump();
      expect(find.text('正在读取角色档案'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await _capture(tester, 'mobile-progress-collapsed');
      await tester.tap(find.text('确认生成'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消').last);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
