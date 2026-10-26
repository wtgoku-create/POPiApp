import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/demo/domain/demo_role_mentions.dart';

void _track(
  DemoRoleMentionTracker tracker, {
  required String roleId,
  required String name,
  required String draft,
  int occurrence = 0,
}) {
  var start = -1;
  var offset = 0;
  for (var index = 0; index <= occurrence; index++) {
    start = draft.indexOf('@$name', offset);
    if (start < 0) throw StateError('mention not found');
    offset = start + name.length + 1;
  }
  tracker.recordSelection(
    roleId: roleId,
    name: name,
    start: start,
    end: start + name.length + 1,
    value: TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    ),
  );
}

void main() {
  group('role mention text', () {
    test('replaces the active @ query at the current caret', () {
      final insertion = buildDemoRoleMentionInsertion(
        const TextEditingValue(
          text: '让 @爱 走进咖啡馆',
          selection: TextSelection.collapsed(offset: 4),
        ),
        '爱丽丝',
      );

      final value = insertion.value;
      expect(value.text, '让 @爱丽丝 走进咖啡馆');
      expect(value.selection, const TextSelection.collapsed(offset: 7));
      expect((insertion.tokenStart, insertion.tokenEnd), (2, 6));
    });

    test('reuses a following newline and places caret after it', () {
      final value = insertDemoRoleMention(
        const TextEditingValue(
          text: '让 @\n继续',
          selection: TextSelection.collapsed(offset: 3),
        ),
        '爱丽丝',
      );

      expect(value.text, '让 @爱丽丝\n继续');
      expect(value.selection, const TextSelection.collapsed(offset: 7));
    });

    test('adds a trailing space when mention is at the end', () {
      final value = insertDemoRoleMention(
        const TextEditingValue(
          text: '让 @',
          selection: TextSelection.collapsed(offset: 3),
        ),
        '爱丽丝',
      );

      expect(value.text, '让 @爱丽丝 ');
      expect(value.selection, const TextSelection.collapsed(offset: 7));
    });

    test('matches only complete readable mentions', () {
      expect(demoRoleMentionCount('参考 @爱丽丝 和 @小明。', '爱丽丝'), 1);
      expect(demoRoleMentionCount('参考 @爱丽丝新版', '爱丽丝'), 0);
      expect(demoRoleMentionCount('mail@爱丽丝', '爱丽丝'), 0);
    });
  });

  group('role mention identities', () {
    test('infers one or multiple uniquely named linked roles', () {
      final tracker = DemoRoleMentionTracker();

      expect(
        tracker.resolve(
          draft: '@爱丽丝 和 @小明 一起喝咖啡',
          linkedRoleIds: const ['alice', 'ming'],
          roleNames: const {'alice': '爱丽丝', 'ming': '小明'},
        ),
        const ['alice', 'ming'],
      );
    });

    test('keeps an explicitly selected ID when names are duplicated', () {
      const draft = '参考 @爱丽丝 创作';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-v2', name: '爱丽丝', draft: draft);

      expect(
        tracker.resolve(
          draft: draft,
          linkedRoleIds: const ['alice-v1', 'alice-v2'],
          roleNames: const {'alice-v1': '爱丽丝', 'alice-v2': '爱丽丝'},
        ),
        const ['alice-v2'],
      );
    });

    test('keeps explicit ID when the linked role is renamed', () {
      const draft = '继续参考 @旧名字 创作';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice', name: '旧名字', draft: draft);

      expect(
        tracker.resolve(
          draft: draft,
          linkedRoleIds: const ['alice'],
          roleNames: const {'alice': '新名字'},
        ),
        const ['alice'],
      );
    });

    test('does not guess a duplicated handwritten name', () {
      final tracker = DemoRoleMentionTracker();

      expect(
        tracker.resolve(
          draft: '参考 @爱丽丝 创作',
          linkedRoleIds: const ['alice-v1', 'alice-v2'],
          roleNames: const {'alice-v1': '爱丽丝', 'alice-v2': '爱丽丝'},
        ),
        isEmpty,
      );
    });

    test('deleting mention text drops its explicit identity', () {
      const draft = '参考 @爱丽丝';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-v2', name: '爱丽丝', draft: draft);
      tracker.reconcileDraft('不再引用角色');

      expect(
        tracker.resolve(
          draft: '@爱丽丝',
          linkedRoleIds: const ['alice-v1', 'alice-v2'],
          roleNames: const {'alice-v1': '爱丽丝', 'alice-v2': '爱丽丝'},
        ),
        isEmpty,
      );
    });

    test('failed retry keeps identity and successful clear releases it', () {
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-v2', name: '爱丽丝', draft: '@爱丽丝');
      const names = {'alice-v1': '爱丽丝', 'alice-v2': '爱丽丝'};
      const linked = ['alice-v1', 'alice-v2'];

      expect(
        tracker.resolve(draft: '@爱丽丝', linkedRoleIds: linked, roleNames: names),
        const ['alice-v2'],
      );
      expect(
        tracker.resolve(draft: '@爱丽丝', linkedRoleIds: linked, roleNames: names),
        const ['alice-v2'],
      );

      tracker.clear();
      expect(
        tracker.resolve(draft: '@爱丽丝', linkedRoleIds: linked, roleNames: names),
        isEmpty,
      );
    });

    test('deleting first duplicated token preserves the second identity', () {
      const draft = '@爱丽丝 @爱丽丝';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-a', name: '爱丽丝', draft: draft);
      _track(
        tracker,
        roleId: 'alice-b',
        name: '爱丽丝',
        draft: draft,
        occurrence: 1,
      );
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: draft,
          selection: TextSelection(baseOffset: 0, extentOffset: 5),
        ),
      );
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: '@爱丽丝',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );

      expect(
        tracker.resolve(
          draft: '@爱丽丝',
          linkedRoleIds: const ['alice-a', 'alice-b'],
          roleNames: const {'alice-a': '爱丽丝', 'alice-b': '爱丽丝'},
        ),
        const ['alice-b'],
      );
    });

    test('deleting last duplicated token preserves the first identity', () {
      const draft = '@爱丽丝 @爱丽丝';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-a', name: '爱丽丝', draft: draft);
      _track(
        tracker,
        roleId: 'alice-b',
        name: '爱丽丝',
        draft: draft,
        occurrence: 1,
      );
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: draft,
          selection: TextSelection(baseOffset: 4, extentOffset: 9),
        ),
      );
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: '@爱丽丝',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );

      expect(
        tracker.resolve(
          draft: '@爱丽丝',
          linkedRoleIds: const ['alice-a', 'alice-b'],
          roleNames: const {'alice-a': '爱丽丝', 'alice-b': '爱丽丝'},
        ),
        const ['alice-a'],
      );
    });

    test('inserting a prefix shifts the tracked token range', () {
      const draft = '看 @爱丽丝';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-b', name: '爱丽丝', draft: draft);
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: '请先 看 @爱丽丝',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );

      expect(
        tracker.resolve(
          draft: '请先 $draft',
          linkedRoleIds: const ['alice-a', 'alice-b'],
          roleNames: const {'alice-a': '爱丽丝', 'alice-b': '爱丽丝'},
        ),
        const ['alice-b'],
      );
    });

    test('editing inside a token clears its explicit identity', () {
      const draft = '看 @爱丽丝';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-b', name: '爱丽丝', draft: draft);

      expect(
        tracker.resolve(
          draft: '看 @爱丽思',
          linkedRoleIds: const ['alice-a', 'alice-b'],
          roleNames: const {'alice-a': '爱丽丝', 'alice-b': '爱丽丝'},
        ),
        isEmpty,
      );
    });

    test('backspace edits only the matching duplicated token', () {
      const draft = '@爱丽丝 @爱丽丝';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-a', name: '爱丽丝', draft: draft);
      _track(
        tracker,
        roleId: 'alice-b',
        name: '爱丽丝',
        draft: draft,
        occurrence: 1,
      );
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: '@爱丽 @爱丽丝',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );

      expect(
        tracker.resolve(
          draft: '@爱丽 @爱丽丝',
          linkedRoleIds: const ['alice-a', 'alice-b'],
          roleNames: const {'alice-a': '爱丽丝', 'alice-b': '爱丽丝'},
        ),
        const ['alice-b'],
      );
    });

    test('IME replacement outside token preserves identity safely', () {
      const draft = '@爱丽丝 ni';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-b', name: '爱丽丝', draft: draft);
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: 7),
          composing: TextRange(start: 5, end: 7),
        ),
      );
      tracker.reconcileEditingValue(
        const TextEditingValue(
          text: '@爱丽丝 你',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange.empty,
        ),
      );

      expect(
        tracker.resolve(
          draft: '@爱丽丝 你',
          linkedRoleIds: const ['alice-a', 'alice-b'],
          roleNames: const {'alice-a': '爱丽丝', 'alice-b': '爱丽丝'},
        ),
        const ['alice-b'],
      );
    });

    test('ambiguous draft-only deletion drops duplicated identities', () {
      const draft = '@爱丽丝 @爱丽丝';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-a', name: '爱丽丝', draft: draft);
      _track(
        tracker,
        roleId: 'alice-b',
        name: '爱丽丝',
        draft: draft,
        occurrence: 1,
      );

      expect(
        tracker.resolve(
          draft: '@爱丽丝',
          linkedRoleIds: const ['alice-a', 'alice-b'],
          roleNames: const {'alice-a': '爱丽丝', 'alice-b': '爱丽丝'},
        ),
        isEmpty,
      );
    });

    test('extending a token clears identity instead of reviving it later', () {
      const draft = '看 @爱丽丝';
      final tracker = DemoRoleMentionTracker();
      _track(tracker, roleId: 'alice-b', name: '爱丽丝', draft: draft);
      const names = {'alice-a': '爱丽丝', 'alice-b': '爱丽丝'};
      const linked = ['alice-a', 'alice-b'];

      expect(
        tracker.resolve(
          draft: '看 @爱丽丝新版',
          linkedRoleIds: linked,
          roleNames: names,
        ),
        isEmpty,
      );
      expect(
        tracker.resolve(draft: draft, linkedRoleIds: linked, roleNames: names),
        isEmpty,
      );
    });
  });
}
