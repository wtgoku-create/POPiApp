import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/domain/conversation_cast.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';

import 'conversation_events_test.dart' show chatSnapshotJson, chatEvent;

Map<String, Object?> _role(int id, [String? title]) => {
  'id': id,
  'title': title ?? 'Role $id',
  'canRead': true,
  'profileVersion': {
    'id': 'version-$id',
    'profile': {'title': title ?? 'Role $id'},
  },
};

void main() {
  test('current session cast, including explicit empty, overrides history', () {
    for (final cast in [
      [],
      [_role(2), _role(1)],
    ]) {
      final snapshot = ConversationSnapshot.fromJson({
        ...chatSnapshotJson(),
        'sessionCast': cast,
        'contextEvents': [
          {
            'seq': 10,
            'kind': 'cast.updated',
            'data': {
              'cast': [_role(3)],
            },
          },
        ],
      });
      expect(
        conversationCastSelection(snapshot).map((r) => r.id),
        cast.map((r) => (r as Map)['id'].toString()),
      );
    }
    expect(conversationCastSelection(null), isEmpty);
  });

  test(
    'legacy replay preserves cast order and role replacements by sequence',
    () {
      final snapshot = ConversationSnapshot.fromJson({
        ...chatSnapshotJson(),
        'contextEvents': [
          {
            'seq': 2,
            'kind': 'cast.updated',
            'data': {
              'cast': [_role(1), _role(2), _role(1)],
            },
          },
        ],
        'messages': [
          {'seq': 1, 'publishedCastRole': _role(9)},
        ],
        'toolCalls': [
          {
            'seq': 3,
            'state': 'completed',
            'name': 'update_personal_role',
            'result': {'sourceRoleId': 1, 'updatedRole': _role(3, 'Updated')},
          },
          {
            'seq': 4,
            'state': 'running',
            'name': 'update_role',
            'result': _role(8),
          },
        ],
      });
      final selected = conversationCastSelection(snapshot);
      expect(selected.map((r) => r.id), ['3', '2']);
      expect(selected.first.title, 'Updated');
      expect(selected.first.profileVersionId, 'version-3');
    },
  );

  test(
    'SSE session cast updates apply and clear without creation casts overriding',
    () {
      var snapshot = ConversationSnapshot.fromJson({
        ...chatSnapshotJson(),
        'sessionCast': [_role(1)],
      });
      for (final (seq, source, cast, expected) in [
        (1, 'session_cast', [_role(2), _role(3)], ['2', '3']),
        (2, 'home_creation', [_role(9)], ['2', '3']),
        (3, 'conversation_cast', <Map<String, Object?>>[], <String>[]),
      ]) {
        snapshot = applyConversationEvent(
          snapshot,
          chatEvent(seq, 'context.recorded', {
            'context': {
              'kind': 'cast.updated',
              'data': {'source': source, 'cast': cast},
            },
          }),
        );
        expect(conversationCastSelection(snapshot).map((r) => r.id), expected);
      }
      expect(snapshot.source['contextEvents'], hasLength(3));
      final replay = applyConversationEvent(
        snapshot,
        chatEvent(3, 'context.recorded', {
          'context': {
            'kind': 'cast.updated',
            'data': {
              'source': 'session_cast',
              'cast': [_role(9)],
            },
          },
        }),
      );
      expect(conversationCastSelection(replay), isEmpty);
    },
  );
}
