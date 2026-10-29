import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/v2_app.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/presentation/login_page.dart';
import 'package:popi_ai_app/features/ip_guide/domain/ip_guide_draft.dart';
import 'package:popi_ai_app/features/ip_guide/presentation/ip_guide_page.dart';
import 'package:popi_ai_app/features/v2_home/data/v2_onboarding_repository.dart';
import 'package:popi_ai_app/features/v2_home/presentation/v2_guest_page.dart';
import 'package:popi_ai_app/features/v2_home/presentation/v2_home_page.dart';
import 'package:popi_ai_app/features/v2_session/presentation/v2_chat_page.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_repository.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations_zh.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = <String, Object?>{
  'contentDirections': ['校园', '成长'],
  'audienceFeelings': ['治愈'],
  'presentationFormats': ['3D动漫'],
  'creativeConstraints': ['剧情短片'],
  'targetAudience': ['学生群体'],
};

const _captureKey = Key('onboarding-capture');

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['V2_PREVIEW_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    await Future.wait(
      tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => precacheImage(image.image, context)),
    );
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _Storage extends PreferencesStorage {
  _Storage(super.preferences);
  bool failSessionWrites = false;

  @override
  Future<void> setString(String key, String value) async {
    if (failSessionWrites && key == V2Repository.storageKey) {
      throw StateError('Disk unavailable');
    }
    await super.setString(key, value);
  }
}

class _UserController extends UserController {
  void signOut() => state = null;
}

void main() {
  late SharedPreferences preferences;
  late _Storage storage;
  late V2Repository sessions;

  setUpAll(() async {
    final font = Platform.environment['V2_PREVIEW_FONT'];
    if (font == null) return;
    await (FontLoader(
      'Roboto',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    storage = _Storage(preferences);
    sessions = V2Repository(storage)..restore();
  });
  tearDown(() => sessions.dispose());

  V2OnboardingRepository guide(String userId) => V2OnboardingRepository(
    storage,
    sessions,
    AppLocalizationsZh(),
    userId: userId,
  );

  test(
    'drafts restore per account and clear without creating a session',
    () async {
      final first = guide('one');
      final second = guide('two');
      expect(first.load(), isNull);
      expect(sessions.hasCompletedOnboarding('one'), isFalse);
      final draft = IpGuideDraft()
        ..step = 3
        ..nickname = '校园故事';
      draft.directions.toggle(IpContentDirection.campus);
      await first.save(draft);
      expect(guide('one').load()!.step, 3);
      expect(guide('one').load()!.directions.values, [
        IpContentDirection.campus,
      ]);
      expect(second.load(), isNull);
      expect(sessions.sessions, hasLength(7));
      await first.clear();
      expect(first.load(), isNull);
      expect(sessions.hasCompletedOnboarding('one'), isFalse);
    },
  );

  test(
    'one confirmation stores all selections and durable completion',
    () async {
      final repository = guide('one');
      final draft = IpGuideDraft()..nickname = '校园故事';
      final id = await repository.create(draft, _profile);
      expect(sessions.sessions, hasLength(8));
      final restored = V2Repository(storage)..restore();
      addTearDown(restored.dispose);
      expect(restored.hasCompletedOnboarding('one'), isTrue);
      expect(restored.hasCompletedOnboarding('two'), isFalse);
      expect(restored.session(id).direction, '校园 / 成长');
      expect(restored.session(id).positioning, '3D动漫');
      expect(restored.session(id).accountPreferences, {
        'feeling': '治愈',
        'format': '剧情短片',
        'audience': '学生群体',
      });
      expect(restored.session(id).messages, isEmpty);
      await sessions.deleteSession(id);
      await sessions.reset();
      expect(sessions.hasCompletedOnboarding('one'), isTrue);
    },
  );

  test(
    'failure preserves draft and request ID; retries create only once',
    () async {
      final repository = guide('one');
      final draft = IpGuideDraft()..nickname = '校园故事';
      storage.failSessionWrites = true;
      await expectLater(repository.create(draft, _profile), throwsStateError);
      expect(sessions.hasCompletedOnboarding('one'), isFalse);
      expect(sessions.sessions, hasLength(7));
      final saved = repository.load()!;
      expect(saved.nickname, '校园故事');
      expect(saved.sessionRequestId, draft.sessionRequestId);
      storage.failSessionWrites = false;
      final ids = await Future.wait([
        repository.create(saved, _profile),
        repository.create(IpGuideDraft()..nickname = '另一次点击', _profile),
      ]);
      expect(ids[0], ids[1]);
      expect(sessions.sessions, hasLength(8));
      final restored = V2Repository(storage)..restore();
      addTearDown(restored.dispose);
      expect(restored.hasCompletedOnboarding('one'), isTrue);
    },
  );

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    Size size = const Size(440, 956),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 52, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        preferencesStorageProvider.overrideWithValue(storage),
        userBootstrapProvider.overrideWith((ref) async {}),
        userProvider.overrideWith(_UserController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const V2App(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('sign in, preview, create, chat, sign out and return', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    expect(find.byType(V2GuestPage), findsOneWidget);
    await _capture(tester, 'guest-mobile');
    expect(find.byType(V2HomePage), findsNothing);
    await tap(tester, 'v2-guest-login');
    expect(find.byType(LoginPage), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(LoginPage)));
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'first', name: '用户', email: ''));
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.byType(IpGuidePage), findsOneWidget);
    await _capture(tester, 'guide-introduction');
    await tap(tester, 'ip-guide-start');
    await tap(tester, 'ip-direction-校园');
    await tap(tester, 'ip-guide-next-1');
    await tap(tester, 'ip-feeling-治愈');
    await tap(tester, 'ip-guide-next-2');
    await tap(tester, 'ip-presentation-3D动漫');
    await tap(tester, 'ip-guide-next-3');
    await tap(tester, 'ip-audience-学生群体');
    await tap(tester, 'ip-guide-next-4');
    final nickname = find.descendant(
      of: find.byKey(const Key('ip-nickname')),
      matching: find.byType(TextField),
    );
    await tester.enterText(nickname, '校园故事');
    await _capture(tester, 'guide-review');
    expect(storage.getString(V2Repository.storageKey), isNull);
    storage.failSessionWrites = true;
    await tap(tester, 'ip-confirm');
    expect(find.byType(IpGuidePage), findsOneWidget);
    expect(tester.widget<TextField>(nickname).controller!.text, '校园故事');
    expect(storage.getString(V2Repository.storageKey), isNull);
    expect(find.text('确认创建'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    storage.failSessionWrites = false;
    await tap(tester, 'ip-confirm');
    expect(find.byType(IpGuidePage), findsNothing);
    expect(find.byType(V2ChatPage), findsOneWidget);
    await _capture(tester, 'onboarding-chat');
    final snapshot = V2Repository(storage)..restore();
    addTearDown(snapshot.dispose);
    expect(snapshot.sessions, hasLength(8));
    expect(snapshot.hasCompletedOnboarding('first'), isTrue);
    (container.read(userProvider.notifier) as _UserController).signOut();
    await tester.pumpAndSettle();
    expect(find.byType(V2GuestPage), findsOneWidget);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'first', name: '用户', email: ''));
    await tester.pumpAndSettle();
    expect(find.byType(V2HomePage), findsOneWidget);
    expect(find.byType(IpGuidePage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const V2App()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(V2HomePage), findsOneWidget);
    expect(find.byType(IpGuidePage), findsNothing);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'second', name: '另一位用户', email: ''));
    await tester.pumpAndSettle();
    expect(find.byType(IpGuidePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(1200, 800)]) {
    testWidgets('signed-out home fits $size and composer opens login', (
      tester,
    ) async {
      await pumpApp(tester, size: size);
      await _capture(tester, 'guest-${size.width.toInt()}');
      expect(find.text('你的短视频账号顾问'), findsOneWidget);
      await tap(tester, 'v2-guest-composer');
      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
