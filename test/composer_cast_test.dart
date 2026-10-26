import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/domain/conversation_session.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:toastification/toastification.dart';

import 'conversation_events_test.dart' show chatId, chatSnapshotJson;
import 'support/role_library_fixtures.dart';
import 'support/session_fixtures.dart';

final _roles = List.generate(
  6,
  (index) => LibraryRole(
    id: '${index + 1}',
    title: 'Role ${index + 1}',
    description: '',
    canRead: true,
    profileVersion: 1,
  ),
);

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_COMPOSER_CAST')) {
      final font = FontLoader('CastCapture')
        ..addFont(
          File(
            '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await font.load();
    }
  });
  Future<_CastRepository> pumpSession(
    WidgetTester tester, {
    String? sessionId,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _CastRepository();
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        dioProvider.overrideWithValue(
          roleLibraryDio(
            loadPage:
                ({required category, required page, required pageSize}) async =>
                    LibraryRolePage(items: _roles, page: page, pageCount: 1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: 'User', email: ''));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SessionPage(sessionId: sessionId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('draft selector selects and clears without creating a session', (
    tester,
  ) async {
    final repository = await pumpSession(tester);
    final castButton = find.byKey(const Key('popi-composer-cast'));
    expect(castButton.hitTestable(), findsNothing);
    final input = find.byKey(const Key('popi-message-input'));
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(castButton.hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('popi-composer-cast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-library-select-2')));
    await tester.tap(find.byKey(const Key('role-selection-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-selection-sheet')), findsNothing);
    expect(repository.creates, 0);
    expect(repository.changes, isEmpty);
    expect(
      tester
          .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
          .castRoles!
          .single
          .id,
      '2',
    );
    await tester.tap(find.byKey(const Key('popi-composer-cast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-library-select-2')));
    await tester.tap(find.byKey(const Key('role-selection-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('未匹配'), findsOneWidget);
    expect(repository.creates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active selector retains failed selection and input, then updates or clears',
    (tester) async {
      final repository = await pumpSession(tester, sessionId: chatId);
      final composer = tester.widget<PopiMessageComposer>(
        find.byType(PopiMessageComposer),
      );
      await composer.controller.setText('Keep this draft');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('popi-composer-cast')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-library-select-1')));
      await tester.tap(find.byKey(const Key('role-library-select-2')));
      repository.failNext = true;
      await tester.tap(find.byKey(const Key('role-selection-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role-selection-sheet')), findsOneWidget);
      expect(composer.controller.markdown, 'Keep this draft');
      await tester.tap(find.byKey(const Key('role-selection-confirm')));
      await tester.pumpAndSettle();
      expect(repository.changes, [
        ['2'],
        ['2'],
      ]);
      expect(find.byKey(const Key('role-selection-sheet')), findsNothing);
      expect(
        tester
            .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
            .castRoles!
            .single
            .id,
        '2',
      );
      expect(composer.controller.markdown, 'Keep this draft');
      await tester.tap(find.byKey(const Key('popi-composer-cast')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-library-select-2')));
      await tester.tap(find.byKey(const Key('role-selection-confirm')));
      await tester.pumpAndSettle();
      expect(repository.changes.last, isEmpty);
      expect(find.text('未匹配'), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
    },
  );

  for (final size in [const Size(320, 568), const Size(1280, 900)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('cast toolbar fits $size at scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PopiMessageComposerController();
        var parameterRequests = 0;
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: const bool.fromEnvironment('CAPTURE_COMPOSER_CAST')
                  ? AppTheme.dark.copyWith(
                      textTheme: AppTheme.dark.textTheme.apply(
                        fontFamily: 'CastCapture',
                      ),
                    )
                  : AppTheme.dark,
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: RepaintBoundary(
                      key: const Key('cast-capture'),
                      child: PopiMessageComposer(
                        controller: controller,
                        selectedImages: const [],
                        castRoles: _roles.take(5).toList(),
                        onCastRequested: () {},
                        conversationMode: true,
                        sessionLayout: true,
                        onModelParametersRequested: () => parameterRequests++,
                        onAttachment: () {},
                        onRemoveImage: (_) {},
                        onHeightChanged: (_) {},
                        onSubmitted: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('popi-composer-cast')).hitTestable(),
          findsNothing,
        );
        await controller.setText('Hello');
        await tester.pumpAndSettle();
        final cast = tester.getRect(
          find.byKey(const Key('popi-composer-cast')),
        );
        final model = tester.getRect(
          find.byKey(const Key('popi-model-parameters')),
        );
        final send = tester.getRect(find.byKey(const Key('popi-send-button')));
        final toolbar = tester.getRect(
          find.byKey(const Key('popi-composer-tools')),
        );
        expect(cast.overlaps(model), isFalse);
        expect(toolbar.overlaps(send), isFalse);
        expect(
          find.descendant(
            of: find.byKey(const Key('popi-model-parameters')),
            matching: find.text('Model / settings'),
          ),
          findsOneWidget,
        );
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('popi-composer-tools')),
            matching: find.byType(Scrollable),
          ),
        );
        if (model.right > toolbar.right) {
          expect(scrollable.position.maxScrollExtent, greaterThan(0));
          await tester.drag(
            find.byKey(const Key('popi-composer-tools')),
            Offset(-scrollable.position.maxScrollExtent, 0),
          );
          await tester.pumpAndSettle();
        }
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('popi-model-parameters'))),
          alignment: 1,
        );
        await tester.pumpAndSettle();
        final visibleModel = tester
            .getRect(find.byKey(const Key('popi-model-parameters')))
            .intersect(toolbar);
        expect(visibleModel.isEmpty, isFalse);
        await tester.tapAt(visibleModel.center);
        expect(parameterRequests, 1);
        expect(tester.takeException(), isNull);
        if (scale == 1 && const bool.fromEnvironment('CAPTURE_COMPOSER_CAST')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('cast-capture')),
          );
          await tester.runAsync(() async {
            final pixels = await boundary.toImage(pixelRatio: 2);
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/composer-cast-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

class _CastRepository extends FixtureSessionRepository {
  var cast = <String>['1'];
  final changes = <List<String>>[];
  int creates = 0;
  bool failNext = false;

  @override
  Future<ConversationSession> create(
    String userId,
    String? title, {
    CancelToken? cancelToken,
  }) {
    creates++;
    return super.create(userId, title, cancelToken: cancelToken);
  }

  @override
  Future<ConversationSession> createFromContent(
    String userId, {
    CancelToken? cancelToken,
  }) {
    creates++;
    return super.createFromContent(userId, cancelToken: cancelToken);
  }

  @override
  Future<ConversationSnapshot> snapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final json = chatSnapshotJson();
    return ConversationSnapshot.fromJson({
      ...json,
      'session': {
        ...json['session'] as Map,
        'id': id,
        'bindingStatus': 'ready',
        'creatorV1': true,
      },
      'sessionCast': [
        for (final id in cast)
          {'id': int.parse(id), 'title': 'Role $id', 'canRead': true},
      ],
    });
  }

  @override
  Future<void> updateCast(
    String userId,
    String id,
    List<String> roleIds, {
    CancelToken? cancelToken,
  }) async {
    changes.add(List.of(roleIds));
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    cast = List.of(roleIds);
  }
}
