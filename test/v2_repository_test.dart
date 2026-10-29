import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_repository.dart';
import 'package:popi_ai_app/features/v2_shared/domain/v2_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Storage extends PreferencesStorage {
  _Storage(super.preferences);
  final values = <String, String>{};
  bool failWrites = false;
  @override
  String? getString(String key) => values[key];
  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('Disk unavailable');
    values[key] = value;
  }
}

void main() {
  late _Storage storage;
  late V2Repository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage(await SharedPreferences.getInstance());
    repository = V2Repository(storage)..restore();
  });
  tearDown(() => repository.dispose());

  test('starts with seven conversations and every media kind', () {
    expect(repository.sessions, hasLength(7));
    expect(
      repository.assets.map((a) => a.kind).toSet(),
      V2AssetKind.values.toSet(),
    );
    expect(repository.session('alice').unread, 2);
  });

  test(
    'restores edits, attachments, custom roles and member settings',
    () async {
      await repository.updateSession(
        'alice',
        (s) => s.copyWith(
          title: 'New title',
          roles: ['custom:Test'],
          memberNames: {'popi': 'My assistant'},
          memberInstructions: {'popi': 'Make short films'},
          memberAvatars: {'popi': 'assets/images/demo_bot_2.png'},
          memberColors: {'popi': 0xFFD6E8FF},
          capabilities: ['video'],
        ),
      );
      await repository.addMessage(
        'alice',
        const V2Message(
          id: 'new',
          text: 'Hello',
          user: true,
          assetIds: ['milk'],
        ),
      );
      final restored = V2Repository(storage)..restore();
      addTearDown(restored.dispose);
      final session = restored.session('alice');
      expect(session.title, 'New title');
      expect(session.roles, ['custom:Test']);
      expect(session.memberNames['popi'], 'My assistant');
      expect(session.memberInstructions['popi'], 'Make short films');
      expect(session.memberAvatars['popi'], 'assets/images/demo_bot_2.png');
      expect(session.memberColors['popi'], 0xFFD6E8FF);
      expect(session.capabilities, ['video']);
      expect(session.messages.last.assetIds, ['milk']);
      expect(session.unread, 0);
    },
  );

  test('queues overlapping updates without losing either edit', () async {
    await Future.wait([
      repository.updateSession('alice', (s) => s.copyWith(title: 'Renamed')),
      repository.updateSession('alice', (s) => s.copyWith(roles: ['er'])),
    ]);
    expect(repository.session('alice').title, 'Renamed');
    expect(repository.session('alice').roles, ['er']);
  });

  test('creates and restores a configured assistant in one write', () async {
    final id = await repository.createSession(
      'My POPi',
      V2SessionKind.conversation,
      memberNames: {'popi': 'My POPi'},
      memberInstructions: {'popi': 'Keep replies concise'},
      memberAvatars: {'popi': 'assets/images/popi_avatar_horse.png'},
      memberColors: {'popi': 0xFFFCDCCE},
    );
    final restored = V2Repository(storage)..restore();
    addTearDown(restored.dispose);
    final session = restored.session(id);
    expect(session.title, 'My POPi');
    expect(session.memberNames, {'popi': 'My POPi'});
    expect(session.memberInstructions, {'popi': 'Keep replies concise'});
    expect(session.memberAvatars, {
      'popi': 'assets/images/popi_avatar_horse.png',
    });
    expect(session.memberColors, {'popi': 0xFFFCDCCE});
    expect(session.messages, isEmpty);
    expect(session.roles, isEmpty);
  });

  test('failed assistant creation adds no partial session', () async {
    storage.failWrites = true;
    await expectLater(
      repository.createSession(
        'My POPi',
        V2SessionKind.conversation,
        memberNames: {'popi': 'My POPi'},
      ),
      throwsStateError,
    );
    expect(repository.sessions, hasLength(7));
    expect(storage.values, isEmpty);
  });

  test('batch generation adds five related assets with unique IDs', () async {
    await repository.reply(
      'alice',
      '批量生成五张场景图',
      text: 'reply',
      imageText: 'images',
      scriptText: 'script',
      audioText: 'audio',
      videoText: 'video',
    );
    final result = repository.session('alice').messages.last;
    expect(result.assetIds, hasLength(5));
    expect(result.assetIds.toSet(), hasLength(5));
    expect(
      repository.assets
          .where((a) => result.assetIds.contains(a.id))
          .every((a) => a.sessionId == 'alice'),
      isTrue,
    );
    final restored = V2Repository(storage)..restore();
    addTearDown(restored.dispose);
    expect(restored.session('alice').messages.last.assetIds, result.assetIds);
  });

  test('reset clears demo edits and persists the original fixtures', () async {
    await repository.deleteSession('alice');
    await repository.deleteAsset('milk');
    await repository.createSession('Temporary', V2SessionKind.workflow);
    await repository.reset();
    final restored = V2Repository(storage)..restore();
    addTearDown(restored.dispose);
    expect(restored.sessions, hasLength(7));
    expect(restored.session('alice').title, '爱丽丝视频');
    expect(restored.assets.any((a) => a.id == 'milk'), isTrue);
  });

  test('failed writes leave the displayed and saved snapshot intact', () async {
    storage.failWrites = true;
    await expectLater(repository.deleteSession('alice'), throwsStateError);
    expect(repository.session('alice').title, '爱丽丝视频');
    expect(storage.values, isEmpty);
    storage.failWrites = false;
    await repository.updateSession(
      'alice',
      (s) => s.copyWith(title: 'Recovered'),
    );
    expect(repository.session('alice').title, 'Recovered');
  });

  test('corrupt saved data falls back to usable fixtures', () {
    storage.values[V2Repository.storageKey] = '{broken';
    repository.restore();
    expect(repository.sessions, hasLength(7));
    expect(repository.assets, isNotEmpty);
  });
}
