import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/role_detail_page.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_profile_sheet.dart';
import 'package:popi_ai_app/features/session/domain/conversation_role_profile.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_role_card.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';

ConversationBlock _role({
  String action = 'created',
  String status = 'active',
}) => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'role',
  'action': action,
  'data': {
    'ref': {'kind': 'role', 'id': 'alice', 'versionId': 'saved-v1'},
    'title': 'Alice',
    'status': status,
    'version': 2,
    'avatar': 'assets/images/role_guide_avatar_1.png',
    'threeViewImage': 'assets/images/role_guide_result_preview.png',
    'profile': {
      'description': 'Saved description',
      'expressionStyle': 'Warm',
      'targetAudience': 'Readers',
      'contentTags': ['School', 'Friends'],
      'profileData': {
        'personality': {
          'label': 'Personality',
          'value': [
            'Kind',
            ['Quiet', 'Patient'],
          ],
        },
        'age': {'value': 18},
        'details': {
          'label': 'Details',
          'value': {'favorite': 'Books'},
        },
      },
    },
  },
});

Future<List<RequestOptions>> _pump(
  WidgetTester tester,
  ConversationBlock block,
) async {
  final requests = <RequestOptions>[];
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.reject(DioException(requestOptions: request));
        },
      ),
    );
  addTearDown(dio.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConversationRoleCard(block: block),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requests;
}

Future<void> _expandProfile(WidgetTester tester) async {
  final toggle = find.byKey(const Key('role-profile-toggle'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  test('saved profile follows Web field order and value formatting', () {
    final block = _role();
    final role = ConversationRoleProfile.fromBlock(block);
    expect(role.fields, [
      ('title', 'Alice'),
      ('description', 'Saved description'),
      ('expressionStyle', 'Warm'),
      ('targetAudience', 'Readers'),
      ('contentTags', 'School, Friends'),
      ('Personality', 'Kind、Quiet、Patient'),
      ('age', '18'),
      ('Details', '{"favorite":"Books"}'),
    ]);
    expect(role.portrait, 'assets/images/role_guide_avatar_1.png');
    expect(role.snapshotRole.id, 'alice');
    expect(role.snapshotRole.profileVersionId, 'saved-v1');
    expect(role.snapshotRole.profileVersion, 2);
    expect(role.snapshotRole.profile, block.data['profile']);
    expect(role.showProfileCard, isTrue);
    expect(
      ConversationRoleProfile.fromBlock(_role(action: 'cast')).showProfileCard,
      isFalse,
    );
    expect(
      ConversationRoleProfile.fromBlock(
        _role(action: 'cast', status: 'draft'),
      ).showProfileCard,
      isFalse,
    );
    expect(
      ConversationRoleProfile.fromBlock(
        _role(action: 'selected', status: 'draft'),
      ).showProfileCard,
      isTrue,
    );
  });

  testWidgets('edited active role shows three-view image without cropping', (
    tester,
  ) async {
    final requests = await _pump(tester, _role(action: 'edited'));
    expect(find.text('Character profile updated'), findsOneWidget);
    expect(find.text('Kind、Quiet、Patient'), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/role_guide_result_preview.png',
    );
    expect(image.fit, BoxFit.contain);
    await tester.tap(find.byKey(const Key('conversation-role-view-profile')));
    await tester.pumpAndSettle();
    final detail = tester.widget<RoleDetailPage>(find.byType(RoleDetailPage));
    expect(detail.useSnapshot, isTrue);
    expect(detail.role.avatar, 'assets/images/role_guide_result_preview.png');
    await _expandProfile(tester);
    await tester.scrollUntilVisible(
      find.text('Kind / Quiet / Patient'),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('conversation-role-profile')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Kind / Quiet / Patient'), findsOneWidget);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cast role has compact card and saved profile preview', (
    tester,
  ) async {
    final requests = await _pump(tester, _role(action: 'cast'));
    expect(find.byKey(const Key('conversation-role-summary')), findsOneWidget);
    expect(find.byKey(const Key('conversation-role-card')), findsNothing);
    final portrait = tester.getRect(
      find.byKey(const Key('conversation-role-portrait')),
    );
    expect(portrait.size, const Size(44, 44));
    expect(
      tester.getTopLeft(find.text('Alice')).dx,
      greaterThan(portrait.right),
    );
    expect(
      tester.getSize(find.byKey(const Key('conversation-role-summary'))).height,
      lessThanOrEqualTo(88),
    );
    expect(find.text('Saved description'), findsOneWidget);
    expect(find.text('Kind、Quiet、Patient'), findsNothing);
    await tester.tap(find.byKey(const Key('conversation-role-view-profile')));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const Key('conversation-role-profile'));
    expect(sheet, findsOneWidget);
    expect(tester.widget(sheet), isA<RoleProfileSheet>());
    expect(find.byKey(const Key('role-profile-summary')), findsOneWidget);
    expect(find.byKey(const Key('role-profile-actions')), findsNothing);
    expect(find.byKey(const Key('role-creation-edit-entry')), findsNothing);
    expect(
      find.descendant(of: sheet, matching: find.text('Saved description')),
      findsOneWidget,
    );
    await _expandProfile(tester);
    await tester.scrollUntilVisible(
      find.descendant(of: sheet, matching: find.text('Kind / Quiet / Patient')),
      150,
      scrollable: find
          .descendant(of: sheet, matching: find.byType(Scrollable))
          .first,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Kind / Quiet / Patient')),
      findsOneWidget,
    );
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('published profile opens role library', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: ConversationRoleCard(block: _role(action: 'published')),
            ),
          ),
        ),
        GoRoute(
          path: '/assets',
          builder: (_, state) => Scaffold(
            body: Text('Library: ${state.uri.queryParameters['section']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Character profile published'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('conversation-role-view-profile')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation-role-view-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Library: roles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
