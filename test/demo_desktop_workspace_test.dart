import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/speech/speech_input.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_assets_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_desktop_workspace.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/speech_input_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<DemoRepository> _pumpHome(
  WidgetTester tester, {
  required Size size,
  TargetPlatform platform = TargetPlatform.macOS,
  SpeechInput Function()? speechInputFactory,
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (speechInputFactory != null)
          speechInputFactoryProvider.overrideWithValue(speechInputFactory),
      ],
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: platform),
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

IndexedStack _chatStack(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byKey(const Key('demo-desktop-chats')));

String _activeSessionId(WidgetTester tester) {
  final stack = _chatStack(tester);
  final host = stack.children[stack.index!];
  final page = find.descendant(
    of: find.byKey(host.key!),
    matching: find.byType(DemoChatPage),
  );
  return tester.widget<DemoChatPage>(page).sessionId;
}

Finder _session(String id) => find.byKey(Key('demo-desktop-session-$id'));

List<SemanticsNode> _semanticsNodesWithLabel(SemanticsNode root, String label) {
  final matches = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.label.contains(label) || node.tooltip == label) matches.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return matches;
}

void main() {
  testWidgets('desktop keeps the sidebar and selected chat visible together', (
    tester,
  ) async {
    final repository = await _pumpHome(tester, size: const Size(1200, 820));

    expect(find.byType(DemoDesktopWorkspace), findsOneWidget);
    expect(find.byType(DemoChatPage), findsOneWidget);
    expect(_activeSessionId(tester), repository.sessions.first.id);
    expect(
      tester.getSize(find.byKey(const Key('demo-desktop-sidebar-frame'))).width,
      280,
    );

    tester.view.physicalSize = const Size(560, 820);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('demo-desktop-sidebar-frame'))).width,
      80,
    );
    expect(find.byType(DemoChatPage), findsOneWidget);
  });

  testWidgets('sidebar and chat controls share the root semantics tree', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = await _pumpHome(tester, size: const Size(1200, 820));
    final context = tester.element(find.byType(DemoHomePage));
    final localizations = AppLocalizations.of(context)!;
    final root = tester
        .binding
        .renderViews
        .single
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!;

    for (final label in [
      localizations.searchConversations,
      localizations.demoCreateAssistant,
      localizations.demoAssets,
      localizations.demoProfile,
      localizations.demoSettings,
    ]) {
      expect(
        _semanticsNodesWithLabel(root, label),
        isNotEmpty,
        reason: '$label should remain exposed in the root semantics tree',
      );
    }
    final selectedSessionNodes = _semanticsNodesWithLabel(
      root,
      repository.sessions.first.title,
    );
    expect(
      selectedSessionNodes.any(
        (node) =>
            node.flagsCollection.isSelected == Tristate.isTrue &&
            node.flagsCollection.isButton,
      ),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('draft survives session switches and compact sidebar resize', (
    tester,
  ) async {
    final repository = await _pumpHome(tester, size: const Size(1200, 820));
    final first = repository.sessions[0];
    final second = repository.sessions[1];
    final composer = find.byKey(const Key('popi-message-input')).hitTestable();

    await tester.tap(composer);
    await tester.pump();
    tester.testTextInput.enterText('保留的桌面草稿');
    await tester.pump();
    final firstComposer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer).hitTestable(),
    );
    final draftController = firstComposer.controller;
    expect(draftController.textController.text, '保留的桌面草稿');
    await tester.tap(_session(second.id));
    await tester.pumpAndSettle();
    expect(_activeSessionId(tester), second.id);

    await tester.tap(_session(first.id));
    await tester.pumpAndSettle();
    expect(_activeSessionId(tester), first.id);
    expect(
      tester
          .widget<PopiMessageComposer>(
            find.byType(PopiMessageComposer).hitTestable(),
          )
          .controller,
      same(draftController),
    );
    expect(draftController.textController.text, '保留的桌面草稿');

    tester.view.physicalSize = const Size(950, 820);
    await tester.pumpAndSettle();
    expect(_activeSessionId(tester), first.id);
    expect(draftController.textController.text, '保留的桌面草稿');
  });

  testWidgets('search filters the sidebar without changing the active chat', (
    tester,
  ) async {
    final repository = await _pumpHome(tester, size: const Size(1200, 820));
    final selected = repository.sessions.first;
    final other = repository.sessions.last;

    await tester.tap(find.byKey(const Key('demo-desktop-search')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('demo-desktop-search-field')),
      other.title,
    );
    await tester.pump();

    expect(_session(other.id), findsOneWidget);
    expect(_session(selected.id), findsNothing);
    expect(_activeSessionId(tester), selected.id);
  });

  testWidgets('assets opens once and a session selection returns to chat', (
    tester,
  ) async {
    final repository = await _pumpHome(tester, size: const Size(1200, 820));
    final nextSession = repository.sessions[1];

    await tester.tap(find.byKey(const Key('demo-desktop-assets')));
    await tester.tap(find.byKey(const Key('demo-desktop-assets')));
    await tester.pumpAndSettle();
    expect(find.byType(DemoAssetsView), findsOneWidget);

    await tester.tap(_session(nextSession.id));
    await tester.pumpAndSettle();
    expect(find.byType(DemoAssetsView), findsNothing);
    expect(_activeSessionId(tester), nextSession.id);
  });

  testWidgets('switching chats cancels voice input in the hidden editor', (
    tester,
  ) async {
    final speechInputs = <_WorkspaceSpeech>[];
    final repository = await _pumpHome(
      tester,
      size: const Size(1200, 820),
      speechInputFactory: () {
        final input = _WorkspaceSpeech();
        speechInputs.add(input);
        return input;
      },
    );

    await tester.tap(find.byKey(const Key('popi-voice-input')).hitTestable());
    await tester.pumpAndSettle();
    expect(speechInputs.single.starts, 1);

    await tester.tap(_session(repository.sessions[1].id));
    await tester.pumpAndSettle();
    expect(speechInputs.first.cancels, 1);
  });

  testWidgets(
    'opaque pages and compact search cancel voice without losing its draft',
    (tester) async {
      final speechInputs = <_WorkspaceSpeech>[];
      await _pumpHome(
        tester,
        size: const Size(1200, 820),
        speechInputFactory: () {
          final input = _WorkspaceSpeech();
          speechInputs.add(input);
          return input;
        },
      );
      final composer = find
          .byKey(const Key('popi-message-input'))
          .hitTestable();
      await tester.tap(composer);
      await tester.pump();
      tester.testTextInput.enterText('覆盖前的草稿');
      await tester.pumpAndSettle();
      final controller = tester
          .widget<PopiMessageComposer>(
            find.byType(PopiMessageComposer).hitTestable(),
          )
          .controller;

      await tester.tap(find.byKey(const Key('popi-voice-input')).hitTestable());
      await tester.pumpAndSettle();
      expect(speechInputs.single.starts, 1);

      final rootNavigator = Navigator.of(
        tester.element(find.byType(DemoHomePage)),
      );
      rootNavigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('覆盖页')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('覆盖页'), findsOneWidget);
      expect(speechInputs.single.cancels, 1);

      rootNavigator.pop();
      await tester.pumpAndSettle();
      expect(speechInputs.single.starts, 1);
      expect(controller.textController.text, '覆盖前的草稿');
      expect(
        tester
            .widget<PopiMessageComposer>(
              find.byType(PopiMessageComposer).hitTestable(),
            )
            .controller,
        same(controller),
      );

      tester.view.physicalSize = const Size(560, 820);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('popi-voice-input')).hitTestable());
      await tester.pumpAndSettle();
      expect(speechInputs.single.starts, 2);

      await tester.tap(find.byKey(const Key('demo-desktop-search')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('demo-desktop-search-field')),
        findsOneWidget,
      );
      expect(speechInputs.single.cancels, 2);

      rootNavigator.pop();
      await tester.pumpAndSettle();
      expect(speechInputs.single.starts, 2);
      expect(controller.textController.text, '覆盖前的草稿');
    },
  );

  testWidgets('deleting the selected session falls back to its next neighbor', (
    tester,
  ) async {
    final repository = await _pumpHome(tester, size: const Size(1200, 820));
    final selected = repository.sessions[1];
    final fallback = repository.sessions[2];

    await tester.tap(_session(selected.id));
    await tester.pumpAndSettle();
    expect(_activeSessionId(tester), selected.id);

    await repository.deleteSession(selected.id);
    await tester.pumpAndSettle();

    expect(_activeSessionId(tester), fallback.id);
    expect(
      find.byKey(ValueKey('demo-desktop-chat-${selected.id}')),
      findsNothing,
    );
  });

  testWidgets('deleting the final session leaves a stable empty workspace', (
    tester,
  ) async {
    final repository = await _pumpHome(tester, size: const Size(1200, 820));

    for (final session in List.of(repository.sessions)) {
      await repository.deleteSession(session.id);
    }
    await tester.pumpAndSettle();

    expect(repository.sessions, isEmpty);
    expect(find.byType(DemoChatPage), findsNothing);
    expect(find.byKey(const Key('demo-desktop-sidebar-frame')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone layout remains the existing mobile home', (tester) async {
    await _pumpHome(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );

    expect(find.byType(DemoDesktopWorkspace), findsNothing);
    expect(find.byKey(const Key('demo-bottom-tabs')), findsOneWidget);
    expect(find.byKey(const Key('demo-desktop-sidebar-frame')), findsNothing);
  });
}

final class _WorkspaceSpeech implements SpeechInput {
  int starts = 0;
  int cancels = 0;

  @override
  Future<void> start({
    required String locale,
    required void Function(String text) onResult,
    required void Function(String code) onError,
    required void Function() onDone,
  }) async {
    starts += 1;
  }

  @override
  Future<void> cancel() async {
    cancels += 1;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
