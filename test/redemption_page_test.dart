import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/redemption/data/redemption_repository.dart';
import 'package:popi_ai_app/features/redemption/domain/redemption.dart';
import 'package:popi_ai_app/features/redemption/presentation/redemption_page.dart';
import 'package:popi_ai_app/features/redemption/presentation/widgets/registration_reward_tab.dart';
import 'package:popi_ai_app/features/redemption/presentation/widgets/wechat_binding_dialog.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:toastification/toastification.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_dialog.dart';

class FakeRedemptionRepository extends RedemptionRepository {
  FakeRedemptionRepository() : super(NetworkApi(Dio()));
  bool bound = true;
  int boundRequests = 0;
  int codeRequests = 0;
  int recordRequests = 0;
  int claims = 0;
  bool failCodes = false;
  bool failClaim = false;
  bool failReward = false;
  bool rewardClosed = false;
  bool bindingSucceeded = false;
  bool qrExpired = false;
  int bindingChecks = 0;
  int qrRequests = 0;
  String? submittedCode;
  Completer<void>? submitCompleter;
  RegistrationReward reward = const RegistrationReward(
    points: 125,
    claimed: false,
    code: '',
  );

  @override
  Future<bool> isWechatBound() async {
    boundRequests++;
    return bound;
  }

  @override
  Future<InvitationPage<InvitationCode>> fetchCodes(
    int page, {
    int pageSize = 20,
  }) async {
    codeRequests++;
    if (failCodes) throw const ApiException();
    return InvitationPage(
      items: page == 1
          ? const [
              InvitationCode(code: 'UNUSED123', usedCount: 0),
              InvitationCode(code: 'USED123', usedCount: 1),
            ]
          : const [InvitationCode(code: 'NEXT123', usedCount: 0)],
      hasMore: page == 1,
    );
  }

  @override
  Future<InvitationPage<InvitationRecord>> fetchRecords(
    int page, {
    int pageSize = 20,
  }) async {
    recordRequests++;
    return InvitationPage(
      items: [
        InvitationRecord(
          name: 'Friend',
          createdAt: DateTime.parse('2026-09-02T09:46:00+08:00'),
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<RegistrationReward> fetchRegistrationReward() async {
    if (rewardClosed) throw const RegistrationRewardUnavailable();
    if (failReward) throw const ApiException();
    return reward;
  }

  @override
  Future<void> claimRegistrationReward(String code) async {
    claims++;
    submittedCode = code;
    await submitCompleter?.future;
    if (failClaim) throw const ApiException(message: 'Code expired');
  }

  @override
  Future<WechatBindingQrCode> fetchBindingQrCode() async {
    qrRequests++;
    return WechatBindingQrCode(
      sceneCode: 'scene',
      url: 'https://example.com/qr.png',
      expiresAt: DateTime.now().add(Duration(seconds: qrExpired ? -1 : 180)),
    );
  }

  @override
  Future<bool> checkBinding(String sceneCode) async {
    bindingChecks++;
    return bindingSucceeded;
  }
}

Widget redemptionTestApp(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double scale = 1,
}) => ToastificationWrapper(
  child: MaterialApp(
    theme: theme ?? AppTheme.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  Future<void> pumpPage(
    WidgetTester tester,
    FakeRedemptionRepository repo,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: 'User', email: ''));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: redemptionTestApp(RedemptionPage(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('requires sign-in without calling authenticated endpoints', (
    tester,
  ) async {
    final repo = FakeRedemptionRepository();
    await tester.pumpWidget(
      ProviderScope(child: redemptionTestApp(RedemptionPage(repository: repo))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to use the Redemption Center'), findsOneWidget);
    expect(repo.boundRequests, 0);
  });

  testWidgets('shows used codes, copies unused ones and appends pagination', (
    tester,
  ) async {
    final repo = FakeRedemptionRepository();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPage(tester, repo);
    expect(find.byKey(const Key('redemption-tab-0')), findsOneWidget);
    expect(find.byKey(const Key('redemption-tab-1')), findsOneWidget);
    expect(find.byKey(const Key('redemption-tab-2')), findsNothing);
    expect(find.text('Activity Code'), findsNothing);
    expect(find.text('UNUSED123'), findsOneWidget);
    expect(find.text('Used by a friend'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-copy-USED123')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('invite-copy-UNUSED123')));
    await tester.pumpAndSettle();
    expect(copied, 'UNUSED123');
    final more = find.descendant(
      of: find.byKey(const Key('invite-codes-status')),
      matching: find.byType(TextButton),
    );
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(repo.codeRequests, 2);
    expect(find.text('NEXT123'), findsOneWidget);
    expect(find.text('UNUSED123'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('binding is required before fetching codes or records', (
    tester,
  ) async {
    final repo = FakeRedemptionRepository()..bound = false;
    await pumpPage(tester, repo);
    expect(find.byKey(const Key('redemption-bind-required')), findsOneWidget);
    expect(repo.codeRequests, 0);
    expect(repo.recordRequests, 0);
  });

  testWidgets('retries a failed invitation list without losing records', (
    tester,
  ) async {
    final repo = FakeRedemptionRepository()..failCodes = true;
    await pumpPage(tester, repo);
    final retry = find.descendant(
      of: find.byKey(const Key('invite-codes-status')),
      matching: find.byType(TextButton),
    );
    await tester.ensureVisible(retry);
    repo.failCodes = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(repo.codeRequests, 2);
    expect(repo.recordRequests, 1);
    expect(find.text('UNUSED123'), findsOneWidget);
  });

  testWidgets('restores claimed reward and prevents repeat submission', (
    tester,
  ) async {
    final repo = FakeRedemptionRepository()
      ..reward = const RegistrationReward(
        points: 125,
        claimed: true,
        code: 'CLAIMED123',
      );
    await tester.pumpWidget(
      redemptionTestApp(
        Scaffold(
          body: RegistrationRewardTab(repository: repo, onReward: () async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+125'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(find.text('CLAIMED123'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('redemption-claim')))
          .onPressed,
      isNull,
    );
    expect(repo.claims, 0);
  });

  testWidgets(
    'locks in-flight claims and refreshes rewards only after success',
    (tester) async {
      final repo = FakeRedemptionRepository()
        ..submitCompleter = Completer<void>();
      int refreshes = 0;
      await tester.pumpWidget(
        redemptionTestApp(
          Scaffold(
            body: RegistrationRewardTab(
              repository: repo,
              onReward: () async {
                refreshes++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('redemption-claim'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '  FRIEND  ');
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(refreshes, 0);
      expect(repo.claims, 1);
      expect(repo.submittedCode, 'FRIEND');
      repo.submitCompleter!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Claimed'), findsOneWidget);
      expect(refreshes, 1);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(milliseconds: 700));
    },
  );

  testWidgets('keeps failed registration claim input and allows retry', (
    tester,
  ) async {
    final repo = FakeRedemptionRepository()..failClaim = true;
    int refreshes = 0;
    await tester.pumpWidget(
      redemptionTestApp(
        Scaffold(
          body: RegistrationRewardTab(
            repository: repo,
            onReward: () async {
              refreshes++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'FRIEND');
    await tester.pump();
    await tester.tap(find.byKey(const Key('redemption-claim')));
    await tester.pumpAndSettle();
    expect(find.text('Code expired'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'FRIEND',
    );
    expect(refreshes, 0);
    repo.failClaim = false;
    await tester.tap(find.byKey(const Key('redemption-claim')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'FRIEND',
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(repo.claims, 2);
    expect(refreshes, 1);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets(
    'closed rewards hide retry and pull to refresh restores the form',
    (tester) async {
      final repo = FakeRedemptionRepository()..rewardClosed = true;
      await tester.pumpWidget(
        redemptionTestApp(
          Scaffold(
            body: RegistrationRewardTab(
              repository: repo,
              onReward: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Welcome rewards are currently unavailable'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('A welcome gift from a friend'), findsNothing);
      expect(find.text("Friend's Invite Code"), findsNothing);
      expect(find.text('Retry'), findsNothing);
      repo.rewardClosed = false;
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('+125'), findsOneWidget);
    },
  );

  testWidgets(
    'successful registration claim refreshes the shared user and balance',
    (tester) async {
      final requests = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options.path);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'status': '0000',
                  'data': options.path.endsWith('/info')
                      ? <String, dynamic>{
                          'user': <String, dynamic>{
                            'id': 1,
                            'name': 'User',
                            'allCoins': 225,
                          },
                        }
                      : <String, dynamic>{'availableTotalPoints': 225},
                },
              ),
            );
          },
        ),
      );
      addTearDown(dio.close);
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: 'User', email: '', allCoins: 100));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: redemptionTestApp(
            RedemptionPage(repository: FakeRedemptionRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('redemption-tab-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('redemption-friend-input')),
        'FRIEND',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('redemption-claim')));
      await tester.pumpAndSettle();
      expect(container.read(userProvider)!.allCoins, 225);
      expect(requests, [
        '/api_client/users/user/info',
        '/api_client/users/userPoints/total',
      ]);
      expect(container.read(userPointsProvider).hasValue, isTrue);
      expect(
        container.read(userPointsProvider).valueOrNull!.availableTotalPoints,
        225,
      );
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(milliseconds: 700));
    },
  );

  testWidgets('successful binding closes its dialog and cancels polling', (
    tester,
  ) async {
    final repo = FakeRedemptionRepository()..bindingSucceeded = true;
    bool? result;
    await tester.pumpWidget(
      redemptionTestApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await AppDialog.show<bool>(
                  context: context,
                  builder: (_) => WechatBindingDialog(repository: repo),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(repo.bindingChecks, 1);
    expect(find.byType(WechatBindingDialog), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(repo.bindingChecks, 1);
  });

  testWidgets('expired binding QR refreshes and polling stops on disposal', (
    tester,
  ) async {
    final repo = FakeRedemptionRepository()..qrExpired = true;
    await tester.pumpWidget(
      redemptionTestApp(WechatBindingDialog(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('QR code expired. Please refresh.'), findsOneWidget);
    expect(repo.bindingChecks, 0);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.qrRequests, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(repo.bindingChecks, 0);
  });

  for (final width in [320.0, 440.0, 1024.0]) {
    testWidgets('fits tabs and forms at $width with large English text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: 'User', email: ''));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: redemptionTestApp(
            RedemptionPage(repository: FakeRedemptionRepository()),
            scale: 1.4,
            theme: AppTheme.dark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(Key('redemption-tab-$i')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
