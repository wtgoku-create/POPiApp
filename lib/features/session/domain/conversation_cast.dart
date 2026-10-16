import '../../assets/domain/library_role.dart';
import 'conversation_snapshot.dart';

/// Mirrors Web's current session cast, with replay for snapshots predating it.
List<LibraryRole> conversationCastSelection(ConversationSnapshot? snapshot) {
  if (snapshot == null) return const [];
  final source = snapshot.source;
  List<LibraryRole> roles(Object? value) => [
    for (final item in conversationMaps(value)) LibraryRole.fromJson(item),
  ];
  List<LibraryRole> unique(Iterable<LibraryRole> items) =>
      {for (final role in items) role.id: role}.values.toList();
  if (source['sessionCast'] is List) {
    return unique(roles(source['sessionCast']));
  }

  final changes =
      <
        int,
        ({
          List<LibraryRole>? cast,
          LibraryRole? published,
          ({String sourceId, LibraryRole role})? replacement,
        })
      >{};
  void recordCast(Map<String, Object?> context, int seq) {
    final data = context['data'];
    if (context['kind'] == 'cast.updated' &&
        data is Map &&
        data['cast'] is List) {
      changes[seq] = (
        cast: roles(data['cast']),
        published: null,
        replacement: null,
      );
    }
  }

  for (final context in conversationMaps(source['contextEvents'])) {
    if (context['seq'] case final int seq) recordCast(context, seq);
  }
  for (final message in conversationMaps(source['messages'])) {
    if (message['seq'] case final int seq) {
      if (message['context'] is Map) {
        recordCast(conversationMap(message['context']), seq);
      } else if (message['publishedCastRole'] is Map) {
        changes[seq] = (
          cast: null,
          published: LibraryRole.fromJson(
            conversationMap(message['publishedCastRole']),
          ),
          replacement: null,
        );
      }
    }
  }
  for (final call in conversationMaps(source['toolCalls'])) {
    if (call['seq'] is! int ||
        call['state'] != 'completed' ||
        ![
          'ensure_personal_role',
          'update_personal_role',
          'use_role',
          'update_role',
        ].contains(call['name']) ||
        call['result'] is! Map) {
      continue;
    }
    final result = conversationMap(call['result']);
    final raw = call['name'] == 'update_role'
        ? result
        : result['updatedRole'] ??
              (['ensure_personal_role', 'use_role'].contains(call['name']) ||
                      result['status'] == 'updated'
                  ? result['role']
                  : null);
    if (raw is! Map || raw['id'] == null) continue;
    final role = LibraryRole.fromJson(conversationMap(raw));
    changes[call['seq'] as int] = (
      cast: null,
      published: null,
      replacement: (
        sourceId: result['sourceRoleId']?.toString() ?? role.id,
        role: role,
      ),
    );
  }
  var selected = <LibraryRole>[];
  for (final seq in changes.keys.toList()..sort()) {
    final change = changes[seq]!;
    if (change.cast != null) {
      selected = unique(change.cast!);
    } else if (change.replacement case final replacement?) {
      selected = unique(
        selected.map(
          (role) =>
              role.id == replacement.sourceId || role.id == replacement.role.id
              ? replacement.role
              : role,
        ),
      );
    } else if (selected.isEmpty && change.published != null) {
      selected = [change.published!];
    }
  }
  return List.unmodifiable(selected);
}
