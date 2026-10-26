import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_assets_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<DemoRepository> _pumpHome(
  WidgetTester tester, {
  required Size size,
  Future<void> Function(DemoRepository repository)? prepare,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final repository = DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
  addTearDown(repository.dispose);
  await prepare?.call(repository);
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.macOS),
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DemoHomePage(repository: repository),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder _session(String id) => find.byKey(Key('demo-desktop-session-$id'));

Finder get _inspector => find.byKey(const Key('demo-desktop-inspector-frame'));

Finder get _chatFrame => find.byKey(const Key('demo-desktop-chat-frame'));

DemoSettingsPage _inspectorSettings(WidgetTester tester) =>
    tester.widget<DemoSettingsPage>(
      find.descendant(of: _inspector, matching: find.byType(DemoSettingsPage)),
    );

PopiMessageComposer _activeComposer(WidgetTester tester) =>
    tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer).hitTestable(),
    );

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  testWidgets('large desktop uses non-overlapping three-column geometry', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(1440, 900));

    final sidebar = tester.getRect(
      find.byKey(const Key('demo-desktop-sidebar-frame')),
    );
    final chat = tester.getRect(_chatFrame);
    final inspector = tester.getRect(_inspector);
    expect(sidebar.width, 280);
    expect(chat.left, sidebar.right);
    expect(chat.right, inspector.left);
    expect(inspector.width, 320);
    expect(inspector.right, 1440);
    expect(chat.width, greaterThanOrEqualTo(800));

    tester.view.physicalSize = const Size(1680, 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(_inspector).width, 360);
    expect(tester.getRect(_chatFrame).right, tester.getRect(_inspector).left);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspector closes and the chat header reopens it in place', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(1440, 900));
    final chatContext = tester.element(find.byType(DemoChatPage).hitTestable());
    expect(Navigator.of(chatContext).canPop(), isFalse);

    await tester.tap(find.byKey(const Key('demo-inspector-close')));
    await tester.pumpAndSettle();
    expect(_inspector, findsNothing);
    expect(find.byType(DemoChatPage).hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-settings')).hitTestable());
    await tester.pumpAndSettle();
    expect(_inspector, findsOneWidget);
    expect(Navigator.of(chatContext).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('breakpoints preserve the chat controller draft and history', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      size: const Size(1440, 900),
      prepare: (repository) async {
        final session = repository.sessions.first;
        await repository.updateSession(
          session.id,
          (current) => current.copyWith(
            messages: [
              for (var index = 0; index < 28; index++)
                DemoMessage(
                  id: 'wide-history-$index',
                  user: index.isEven,
                  text:
                      '第 $index 条用于验证宽屏布局的历史消息。\n'
                      '切换布局后仍要停留在同一阅读位置。',
                ),
            ],
          ),
        );
      },
    );
    final composer = _activeComposer(tester);
    final controller = composer.controller;
    await tester.tap(find.byKey(const Key('popi-message-input')).hitTestable());
    tester.testTextInput.enterText('三列布局中的草稿');
    await tester.pump();

    final chatList = tester.widget<ChatAnimatedList>(
      find.byType(ChatAnimatedList).hitTestable(),
    );
    final position = chatList.scrollController!.position;
    expect(position.maxScrollExtent, greaterThan(300));
    await tester.drag(
      find.byType(ChatAnimatedList).hitTestable(),
      const Offset(0, 360),
    );
    await tester.pump();
    final readingOffset = position.pixels;
    expect(readingOffset, lessThan(position.maxScrollExtent));

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(_inspector, findsNothing);
    expect(_activeComposer(tester).controller, same(controller));
    expect(controller.textController.text, '三列布局中的草稿');
    expect(position.pixels, closeTo(readingOffset, 1));

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(_inspector, findsOneWidget);
    expect(_activeComposer(tester).controller, same(controller));
    expect(controller.textController.text, '三列布局中的草稿');
    expect(position.pixels, closeTo(readingOffset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspector follows the selected session and its real outputs', (
    tester,
  ) async {
    final repository = await _pumpHome(tester, size: const Size(1440, 900));
    final first = repository.sessions.first;
    final second = repository.sessions[1];
    expect(_inspectorSettings(tester).sessionId, first.id);

    await tester.tap(_session(second.id));
    await tester.pumpAndSettle();
    expect(_inspectorSettings(tester).sessionId, second.id);

    final outputs = find.descendant(of: _inspector, matching: find.text('产物'));
    await tester.tap(outputs);
    await tester.pumpAndSettle();
    final assets = tester.widget<DemoAssetsView>(
      find.descendant(of: _inspector, matching: find.byType(DemoAssetsView)),
    );
    expect(assets.sessionId, second.id);
    expect(
      repository.assets.where((asset) => asset.sessionId == second.id),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat output requests switch the dock without pushing a route', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(1440, 900));
    final chat = tester.widget<DemoChatPage>(
      find.byType(DemoChatPage).hitTestable(),
    );
    final chatContext = tester.element(find.byType(DemoChatPage).hitTestable());
    expect(chat.onOpenSettings, isNotNull);
    expect(Navigator.of(chatContext).canPop(), isFalse);

    chat.onOpenSettings!(2);
    await tester.pumpAndSettle();
    expect(_inspectorSettings(tester).initialTab, 2);
    expect(
      find.descendant(of: _inspector, matching: find.byType(DemoAssetsView)),
      findsOneWidget,
    );
    expect(Navigator.of(chatContext).canPop(), isFalse);

    chat.onOpenSettings!(0);
    await tester.pumpAndSettle();
    expect(_inspectorSettings(tester).initialTab, 0);
    expect(Navigator.of(chatContext).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting selected and final sessions keeps inspector stable', (
    tester,
  ) async {
    final repository = await _pumpHome(tester, size: const Size(1440, 900));
    final selected = repository.sessions[1];
    final fallback = repository.sessions[2];
    await tester.tap(_session(selected.id));
    await tester.pumpAndSettle();
    expect(_inspectorSettings(tester).sessionId, selected.id);

    await repository.deleteSession(selected.id);
    await tester.pumpAndSettle();
    expect(_inspectorSettings(tester).sessionId, fallback.id);
    expect(tester.takeException(), isNull);

    for (final session in List.of(repository.sessions)) {
      await repository.deleteSession(session.id);
    }
    await tester.pumpAndSettle();
    expect(find.byType(DemoChatPage), findsNothing);
    expect(_inspector, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium desktop keeps two columns and routes settings normally', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(1200, 820));
    expect(_inspector, findsNothing);
    final chatContext = tester.element(find.byType(DemoChatPage).hitTestable());
    expect(Navigator.of(chatContext).canPop(), isFalse);

    await tester.tap(find.byKey(const Key('demo-settings')).hitTestable());
    await tester.pumpAndSettle();
    expect(_inspector, findsNothing);
    expect(find.byType(DemoSettingsPage), findsOneWidget);
    expect(Navigator.of(chatContext).canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('three-column breakpoint starts at 1440 physical pixels', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(1439, 820));
    expect(_inspector, findsNothing);
    tester.view.physicalSize = const Size(1440, 820);
    await tester.pumpAndSettle();
    expect(_inspector, findsOneWidget);
  });
}
