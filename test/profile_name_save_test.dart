import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/profile/data/local_profile_repository.dart';
import 'package:popi_ai_app/features/profile/domain/local_profile.dart';
import 'package:popi_ai_app/features/profile/presentation/edit_profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/local_profile_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

final _avatarBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _RetryRepository extends LocalProfileRepository {
  _RetryRepository(super.storage);

  int attempts = 0;
  final gate = Completer<void>();

  @override
  Future<LocalProfile> save({
    required String name,
    Uint8List? avatarBytes,
  }) async {
    attempts++;
    if (attempts == 1) throw StateError('First write failed');
    await gate.future;
    return super.save(name: name, avatarBytes: avatarBytes);
  }
}

class _RecordingUserController extends UserController {
  int updateCalls = 0;

  @override
  User? build() => const User(
    id: 'production-user',
    code: 'u-production',
    name: '原名字',
    email: 'user@example.com',
  );

  @override
  Future<void> updateUser({
    String? name,
    String? avatarUrl,
    String? signature,
  }) async {
    updateCalls++;
    final current = state!;
    state = User(
      id: current.id,
      code: current.code,
      name: name ?? current.name,
      email: current.email,
      avatarUrl: avatarUrl ?? current.avatarUrl,
      signature: signature ?? current.signature,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => toastification.managers.clear());
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  Future<({ProviderContainer container, GoRouter router})> pumpProfileApp(
    WidgetTester tester, {
    bool localEnabled = true,
    LocalProfileRepository? repository,
    Future<XFile?> Function()? pickAvatar,
    Map<String, Object> stored = const {},
    bool simpleHome = false,
    bool authenticated = false,
  }) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(stored);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        localProfileEnabledProvider.overrideWithValue(localEnabled),
        sharedPreferencesProvider.overrideWithValue(preferences),
        if (repository != null)
          localProfileRepositoryProvider.overrideWithValue(repository),
        if (authenticated)
          userProvider.overrideWith(_RecordingUserController.new),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => simpleHome
              ? Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => context.push('/profile/edit'),
                      child: const Text('编辑资料'),
                    ),
                  ),
                )
              : const ProfilePage(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, __) => EditProfilePage(pickAvatar: pickAvatar),
        ),
        GoRoute(path: '/login', builder: (_, __) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ToastificationWrapper(
          child: MaterialApp.router(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, router: router);
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfilePage), findsOneWidget);
  }

  testWidgets('local name and avatar save, navigate back, and reopen', (
    tester,
  ) async {
    await pumpProfileApp(
      tester,
      pickAvatar: () async => XFile.fromData(
        _avatarBytes,
        name: 'avatar.png',
        mimeType: 'image/png',
      ),
    );
    await openEditor(tester);

    await tester.enterText(find.byKey(const Key('profile-name')), '  PPP  ');
    await tester.tap(find.byKey(const Key('edit-profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('PPP'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsOneWidget,
    );

    await openEditor(tester);
    final field = tester.widget<TextField>(
      find.byKey(const Key('profile-name')),
    );
    expect(field.controller?.text, 'PPP');
    expect(find.text('UID'), findsOneWidget);
    expect(find.text('303180'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('keeps edits on failure, retries, and ignores double taps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _RetryRepository(PreferencesStorage(preferences));
    await pumpProfileApp(tester, repository: repository);
    await openEditor(tester);
    await tester.enterText(find.byKey(const Key('profile-name')), '重试昵称');

    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pumpAndSettle();
    expect(repository.attempts, 1);
    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(find.text('重试昵称'), findsOneWidget);
    expect(find.text('资料更新失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pump();
    expect(repository.attempts, 2);
    repository.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('重试昵称'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('rejects empty and overlength names before persistence', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _RetryRepository(PreferencesStorage(preferences));
    await pumpProfileApp(tester, repository: repository);
    await openEditor(tester);

    await tester.enterText(find.byKey(const Key('profile-name')), '');
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(repository.attempts, 0);
    expect(find.text('请输入昵称'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));

    await tester.enterText(
      find.byKey(const Key('profile-name')),
      List.filled(16, '🙂').join(),
    );
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pump();
    expect(repository.attempts, 0);
    expect(find.byType(EditProfilePage), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('late authenticated user does not overwrite active typing', (
    tester,
  ) async {
    final app = await pumpProfileApp(
      tester,
      stored: {LocalProfileRepository.storageKey: '{"name":"本地昵称"}'},
      simpleHome: true,
    );
    await openEditor(tester);
    await tester.enterText(find.byKey(const Key('profile-name')), '正在输入');

    await app.container
        .read(userProvider.notifier)
        .setUser(
          const User(
            id: 'new-user',
            code: 'u-new',
            name: '远端名字',
            email: 'user@example.com',
          ),
        );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('profile-name')),
    );
    expect(field.controller?.text, '正在输入');
  });

  testWidgets('signed-out production profile reports failure and stays open', (
    tester,
  ) async {
    await pumpProfileApp(tester, localEnabled: false, simpleHome: true);
    await openEditor(tester);
    await tester.enterText(find.byKey(const Key('profile-name')), '不会保存');
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(find.text('资料更新失败，请稍后重试'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('authenticated profile keeps the existing user update path', (
    tester,
  ) async {
    final app = await pumpProfileApp(
      tester,
      localEnabled: false,
      simpleHome: true,
      authenticated: true,
    );
    await openEditor(tester);
    final initialField = tester.widget<TextField>(
      find.byKey(const Key('profile-name')),
    );
    expect(initialField.controller?.text, '原名字');

    await tester.enterText(find.byKey(const Key('profile-name')), '正式账号新名字');
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pumpAndSettle();

    final controller =
        app.container.read(userProvider.notifier) as _RecordingUserController;
    expect(controller.updateCalls, 1);
    expect(app.container.read(userProvider)?.name, '正式账号新名字');
    expect(app.container.read(userStatusProvider).name, 'authenticated');
    expect(app.container.read(localProfileProvider), isNull);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });
}
