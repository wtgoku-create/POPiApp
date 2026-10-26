import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_assistant_identity.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

DemoSession _session({
  String title = '新建会话',
  List<String> members = const ['popi'],
  String activeMemberId = 'popi',
  Map<String, String> memberNames = const {},
  List<DemoMessage> messages = const [],
}) => DemoSession(
  id: 'session',
  title: title,
  kind: DemoSessionKind.conversation,
  members: members,
  roles: const [],
  activeMemberId: activeMemberId,
  memberNames: memberNames,
  messages: messages,
);

void main() {
  test('configured given name wins over generic POPi category and title', () {
    final session = _session(title: 'Watt', memberNames: const {'popi': '哈哈'});
    expect(DemoAssistantIdentity.primaryMemberId(session), 'popi');
    expect(DemoAssistantIdentity.singleName(session), '哈哈');
  });

  test('legacy single session title is recovered before snapshots', () {
    final session = _session(
      title: 'Watt',
      memberNames: const {'popi': 'POPi'},
      messages: const [
        DemoMessage(
          id: 'message',
          text: '旧回复',
          memberId: 'popi',
          memberName: '旧快照名',
        ),
      ],
    );
    expect(DemoAssistantIdentity.singleName(session), 'Watt');
  });

  test('default titles and generic names fall back to a snapshot name', () {
    for (final title in [
      '新建会话',
      '新会话',
      'New conversation',
      'New chat',
      'Session',
    ]) {
      expect(
        DemoAssistantIdentity.singleName(
          _session(
            title: title,
            memberNames: const {'popi': 'popi'},
            messages: const [
              DemoMessage(
                id: 'message',
                text: '旧回复',
                memberId: 'popi',
                memberName: '哈哈',
              ),
            ],
          ),
        ),
        '哈哈',
        reason: title,
      );
    }
  });

  test('group room title never becomes a member name', () {
    final session = _session(
      title: '短片创作组',
      members: const ['writer', 'designer'],
      activeMemberId: 'writer',
    );
    expect(DemoAssistantIdentity.singleName(session), isNull);
    expect(DemoAssistantIdentity.givenName(session, 'writer'), isNull);
    expect(
      DemoAssistantIdentity.givenName(session, 'removed', snapshotName: '旧助手'),
      '旧助手',
    );
  });

  test('member ID echoes are not treated as user-given snapshot names', () {
    final session = _session(
      title: '创作组',
      members: const ['designer', 'writer'],
      activeMemberId: 'designer',
      messages: const [
        DemoMessage(
          id: 'message',
          text: '开始设计',
          memberId: 'designer',
          memberName: 'designer',
        ),
      ],
    );
    expect(DemoAssistantIdentity.givenName(session, 'designer'), isNull);
  });

  test(
    'primary member follows valid active identity then stable member order',
    () {
      expect(
        DemoAssistantIdentity.primaryMemberId(
          _session(
            members: const ['writer', 'designer'],
            activeMemberId: 'designer',
          ),
        ),
        'designer',
      );
      expect(
        DemoAssistantIdentity.primaryMemberId(
          _session(members: const ['writer'], activeMemberId: 'removed'),
        ),
        'writer',
      );
    },
  );

  test('offline explicit title and member renames stay synchronized', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    );
    addTearDown(repository.dispose);
    final id = await repository.createSession(
      '初始名字',
      DemoSessionKind.conversation,
      assistant: const DemoAssistantProfile(
        id: 'profile',
        memberId: 'popi',
        name: '初始名字',
        instructions: '保持温柔简洁',
        avatarAsset: 'assets/animations/bot_avatars/rabbit.png',
        avatarColor: 0xFFE4DCFE,
      ),
    );

    await repository.updateSession(
      id,
      (session) => session.copyWith(title: '标题改名'),
    );
    expect(repository.session(id).memberNames['popi'], '标题改名');

    await repository.updateSession(
      id,
      (session) => session.copyWith(
        memberNames: {...session.memberNames, 'popi': '助手改名'},
      ),
    );
    expect(repository.session(id).title, '助手改名');
    expect(repository.session(id).memberNames['popi'], '助手改名');
    expect(repository.session(id).memberInstructions['popi'], '保持温柔简洁');
    expect(
      repository.session(id).memberAvatars['popi'],
      'assets/animations/bot_avatars/rabbit.png',
    );
    expect(repository.session(id).memberColors['popi'], 0xFFE4DCFE);
  });
}
