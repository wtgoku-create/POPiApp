import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';

void main() {
  DemoSession session({DateTime? updatedAt, DateTime? createdAt}) =>
      DemoSession(
        id: 'session',
        title: 'Session',
        kind: DemoSessionKind.conversation,
        members: const ['popi'],
        roles: const [],
        messages: [
          DemoMessage(id: 'message', text: 'Hello', createdAt: createdAt),
        ],
        updatedAt: updatedAt,
      );

  test('timestamps round-trip as normalized UTC instants', () {
    final value = session(
      updatedAt: DateTime.parse('2026-10-25T11:10:00+08:00'),
      createdAt: DateTime.parse('2026-10-25T10:48:00+08:00'),
    );

    final restored = DemoSession.fromJson(value.toJson());

    expect(restored.updatedAt, DateTime.utc(2026, 10, 25, 3, 10));
    expect(
      restored.messages.single.createdAt,
      DateTime.utc(2026, 10, 25, 2, 48),
    );
    expect(restored.toJson()['updatedAt'], '2026-10-25T03:10:00.000Z');
    expect(
      restored.messages.single.toJson()['createdAt'],
      '2026-10-25T02:48:00.000Z',
    );
  });

  test('old or invalid cached timestamps remain readable as null', () {
    final json = session().toJson();
    json.remove('updatedAt');
    final message = Map<String, Object?>.from(
      (json['messages'] as List).single as Map,
    )..['createdAt'] = 'invalid';
    json['messages'] = [message];

    final restored = DemoSession.fromJson(json);

    expect(restored.updatedAt, isNull);
    expect(restored.messages.single.createdAt, isNull);
  });

  test('copyWith preserves timestamps unless a replacement is supplied', () {
    final original = session(updatedAt: DateTime.utc(2026, 10, 23));
    final replacement = DateTime.utc(2026, 10, 25);

    expect(original.copyWith(title: 'Renamed').updatedAt, original.updatedAt);
    expect(original.copyWith(updatedAt: replacement).updatedAt, replacement);
  });
}
