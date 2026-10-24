import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_fixtures.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_controller.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_create_session_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _memberCharacters = <String, BotAvatarCharacter>{
  'popi': BotAvatarCharacter.tiger,
  'designer': BotAvatarCharacter.rabbit,
  'writer': BotAvatarCharacter.monkey,
  'director': BotAvatarCharacter.dragon,
  'sound': BotAvatarCharacter.rooster,
};

const _legacyMemberImages = <String, String>{
  'popi': 'assets/images/demo_avatar_popi.png',
  'designer': 'assets/images/demo_avatar_designer.png',
  'writer': 'assets/images/demo_avatar_writer.png',
  'director': 'assets/images/demo_avatar_director.png',
  'sound': 'assets/images/demo_avatar_sound.png',
};

Future<DemoRepository> _repositoryWith(DemoSession session) async {
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

DemoSession _session({Map<String, String> memberAvatars = const {}}) =>
    DemoSession(
      id: 'zodiac',
      title: '生肖创作组',
      kind: DemoSessionKind.project,
      members: _memberCharacters.keys.toList(),
      roles: const [],
      messages: const [],
      memberAvatars: memberAvatars,
      configRevision: 7,
      configurationStatus: 'configured',
    );

void main() {
  testWidgets('direct Popi creation exposes all zodiac avatar choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDemoCreateSessionSheet(
                context: context,
                repository: repository,
                kind: DemoSessionKind.project,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('创建新的 Popi'), findsOneWidget);
    for (final character in BotAvatarCharacter.values) {
      expect(
        find.byKey(ValueKey('demo-assistant-avatar-${character.name}')),
        findsOneWidget,
        reason: character.name,
      );
    }
    expect(BotAvatarCharacter.values, hasLength(12));
    expect(tester.takeException(), isNull);
  });

  test('legacy role portraits normalize to stable zodiac defaults only', () {
    for (final entry in _legacyMemberImages.entries) {
      expect(
        DemoFixtures.normalizeAvatarAsset(entry.value),
        _memberCharacters[entry.key]!.stillAsset,
        reason: entry.key,
      );
      expect(
        DemoFixtures.memberImage(entry.key, savedImage: entry.value),
        _memberCharacters[entry.key]!.stillAsset,
        reason: entry.key,
      );
    }

    const roleArtwork = 'assets/images/demo_role_2.png';
    const unknownCustom = 'assets/images/demo_bot_2.png';
    expect(DemoFixtures.normalizeAvatarAsset(roleArtwork), roleArtwork);
    expect(DemoFixtures.normalizeAvatarAsset(unknownCustom), unknownCustom);
    expect(
      DemoFixtures.memberImage('director', savedImage: unknownCustom),
      unknownCustom,
    );
    expect(
      DemoFixtures.memberImage(
        'popi',
        savedImage: BotAvatarCharacter.rabbit.stillAsset,
      ),
      BotAvatarCharacter.rabbit.stillAsset,
    );
    expect(
      DemoFixtures.memberImage('sound', savedImage: ''),
      BotAvatarCharacter.rooster.stillAsset,
    );
  });

  test(
    'controller resolves stored avatars without rewriting the snapshot',
    () async {
      final stored = Map<String, String>.from(_legacyMemberImages);
      stored['designer'] = BotAvatarCharacter.snake.stillAsset;
      stored['director'] = 'assets/images/demo_bot_2.png';
      final repository = await _repositoryWith(_session(memberAvatars: stored));
      addTearDown(repository.dispose);
      final controller = DemoChatController(repository, 'zodiac');
      addTearDown(controller.dispose);
      final l = lookupAppLocalizations(const Locale('zh'));

      for (final id in _memberCharacters.keys) {
        expect(
          controller.resolveUser(id, l).imageSource,
          DemoFixtures.memberImage(id, savedImage: stored[id]),
          reason: id,
        );
      }
      expect(
        controller.resolveUser('designer', l).imageSource,
        BotAvatarCharacter.snake.stillAsset,
      );
      expect(
        controller.resolveUser('director', l).imageSource,
        'assets/images/demo_bot_2.png',
      );
      expect(repository.session('zodiac').memberAvatars, stored);
      expect(repository.session('zodiac').configRevision, 7);
    },
  );
}
