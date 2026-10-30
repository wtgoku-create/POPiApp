import 'package:flutter/widgets.dart';

/// A role chosen from the mention picker keeps its server identity even when
/// multiple linked roles share the same visible name.
class DemoRoleMentionTracker {
  final List<_ExplicitRoleMention> _explicit = [];
  TextEditingValue _value = TextEditingValue.empty;

  void recordSelection({
    required String roleId,
    required String name,
    required int start,
    required int end,
    required TextEditingValue value,
  }) {
    final draft = value.text;
    final normalizedName = name.trim();
    final token = '@$normalizedName';
    if (roleId.isEmpty ||
        normalizedName.isEmpty ||
        start < 0 ||
        end > draft.length ||
        start >= end ||
        !_isDemoRoleMentionAt(draft, start, end, token)) {
      return;
    }
    reconcileEditingValue(value);
    _explicit.removeWhere(
      (mention) => mention.start == start && mention.end == end,
    );
    _explicit.add(
      _ExplicitRoleMention(
        roleId: roleId,
        name: normalizedName,
        start: start,
        end: end,
      ),
    );
    _value = value;
  }

  /// Uses the previous selection/caret to identify which identical token was
  /// edited, then updates the surviving UTF-16 ranges.
  void reconcileEditingValue(TextEditingValue value) {
    if (value.text == _value.text) {
      _value = value;
      return;
    }
    if (_explicit.isEmpty) {
      _value = value;
      return;
    }
    final edit =
        _selectionEdit(_value, value) ??
        _commonAffixEdit(_value.text, value.text);
    _applyEdit(edit, value.text);
    _value = value;
  }

  /// Compatibility path for callers without an editing selection. When
  /// identical visible names make a deletion ambiguous, all affected explicit
  /// identities are dropped instead of guessing which role survived.
  void reconcileDraft(String draft) {
    if (draft == _value.text) return;
    if (_explicit.isEmpty) {
      _value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      return;
    }
    final ambiguousNames = <String>{};
    for (final name in _explicit.map((mention) => mention.name).toSet()) {
      final oldCount = demoRoleMentionCount(_value.text, name);
      final newCount = demoRoleMentionCount(draft, name);
      if (oldCount > 1 && newCount < oldCount) ambiguousNames.add(name);
    }
    _applyEdit(_commonAffixEdit(_value.text, draft), draft);
    _explicit.removeWhere((mention) => ambiguousNames.contains(mention.name));
    _value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  void _applyEdit(_DemoTextEdit edit, String draft) {
    final delta = edit.newEnd - edit.oldEnd;
    _explicit.removeWhere((mention) {
      if (edit.oldEnd <= mention.start) {
        mention
          ..start += delta
          ..end += delta;
      } else if (edit.start < mention.end && edit.oldEnd > mention.start) {
        return true;
      }
      return mention.start < 0 ||
          mention.end > draft.length ||
          !_isDemoRoleMentionAt(
            draft,
            mention.start,
            mention.end,
            '@${mention.name}',
          );
    });
  }

  List<String> resolve({
    required String draft,
    required List<String> linkedRoleIds,
    required Map<String, String> roleNames,
  }) {
    reconcileDraft(draft);
    final linked = linkedRoleIds.toSet();
    final result = <String>[];
    final remainingByName = <String, int>{};
    final names = {
      ...roleNames.values.map((name) => name.trim()),
      ..._explicit.map((mention) => mention.name),
    };
    for (final name in names) {
      if (name.isNotEmpty) {
        remainingByName[name] = demoRoleMentionCount(draft, name);
      }
    }

    // Explicit picker choices take precedence over name inference.
    for (final mention in _explicit) {
      final remaining = remainingByName[mention.name] ?? 0;
      if (!linked.contains(mention.roleId) || remaining == 0) continue;
      if (!result.contains(mention.roleId)) result.add(mention.roleId);
      remainingByName[mention.name] = remaining - 1;
    }

    final idsByName = <String, List<String>>{};
    for (final id in linkedRoleIds) {
      final name = roleNames[id]?.trim() ?? '';
      if (name.isNotEmpty) (idsByName[name] ??= []).add(id);
    }
    for (final entry in remainingByName.entries) {
      if (entry.value == 0) continue;
      final matchingIds = idsByName[entry.key] ?? const [];
      // A handwritten name is safe to infer only when it is unambiguous.
      if (matchingIds.length == 1 && !result.contains(matchingIds.single)) {
        result.add(matchingIds.single);
      }
    }
    return result;
  }

  void clear() {
    _explicit.clear();
    _value = TextEditingValue.empty;
  }
}

class _DemoTextEdit {
  const _DemoTextEdit({
    required this.start,
    required this.oldEnd,
    required this.newEnd,
  });

  final int start;
  final int oldEnd;
  final int newEnd;
}

_DemoTextEdit? _selectionEdit(
  TextEditingValue previous,
  TextEditingValue next,
) {
  final oldText = previous.text;
  final newText = next.text;
  final selection = previous.selection;
  if (!selection.isValid) return null;
  final oldLength = oldText.length;
  final newLength = newText.length;
  final removedLength = oldLength - newLength;
  int start;
  int oldEnd;
  int newEnd;

  if (!selection.isCollapsed) {
    start = selection.start.clamp(0, oldLength);
    oldEnd = selection.end.clamp(start, oldLength);
    final insertedLength = newLength - (oldLength - (oldEnd - start));
    if (insertedLength < 0) return null;
    newEnd = start + insertedLength;
  } else if (newLength > oldLength) {
    start = selection.extentOffset.clamp(0, oldLength);
    oldEnd = start;
    newEnd = start + newLength - oldLength;
  } else if (newLength < oldLength && next.selection.isValid) {
    final oldCaret = selection.extentOffset.clamp(0, oldLength);
    final newCaret = next.selection.extentOffset.clamp(0, newLength);
    if (newCaret < oldCaret) {
      start = newCaret;
      oldEnd = (start + removedLength).clamp(start, oldLength);
      newEnd = start;
    } else {
      start = oldCaret;
      oldEnd = (start + removedLength).clamp(start, oldLength);
      newEnd = start;
    }
  } else {
    return null;
  }
  if (newEnd < start || newEnd > newLength) return null;
  final inserted = newText.substring(start, newEnd);
  return oldText.replaceRange(start, oldEnd, inserted) == newText
      ? _DemoTextEdit(start: start, oldEnd: oldEnd, newEnd: newEnd)
      : null;
}

_DemoTextEdit _commonAffixEdit(String oldText, String newText) {
  final sharedLength = oldText.length < newText.length
      ? oldText.length
      : newText.length;
  var start = 0;
  while (start < sharedLength &&
      oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
    start++;
  }
  var sharedSuffix = 0;
  while (sharedSuffix < oldText.length - start &&
      sharedSuffix < newText.length - start &&
      oldText.codeUnitAt(oldText.length - 1 - sharedSuffix) ==
          newText.codeUnitAt(newText.length - 1 - sharedSuffix)) {
    sharedSuffix++;
  }
  return _DemoTextEdit(
    start: start,
    oldEnd: oldText.length - sharedSuffix,
    newEnd: newText.length - sharedSuffix,
  );
}

class _ExplicitRoleMention {
  _ExplicitRoleMention({
    required this.roleId,
    required this.name,
    required this.start,
    required this.end,
  });

  final String roleId;
  final String name;
  int start;
  int end;
}

class DemoRoleMentionInsertion {
  const DemoRoleMentionInsertion({
    required this.value,
    required this.tokenStart,
    required this.tokenEnd,
  });

  final TextEditingValue value;
  final int tokenStart;
  final int tokenEnd;
}

TextEditingValue insertDemoRoleMention(
  TextEditingValue value,
  String roleName,
) => buildDemoRoleMentionInsertion(value, roleName).value;

DemoRoleMentionInsertion buildDemoRoleMentionInsertion(
  TextEditingValue value,
  String roleName,
) {
  final name = roleName.trim();
  if (name.isEmpty) {
    return DemoRoleMentionInsertion(
      value: value,
      tokenStart: value.selection.extentOffset,
      tokenEnd: value.selection.extentOffset,
    );
  }
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  final caret = selection.extentOffset.clamp(0, value.text.length);
  var start = selection.start.clamp(0, value.text.length);
  final end = selection.end.clamp(start, value.text.length);

  // Replace the active @query. If the picker came from the toolbar, insert at
  // the current selection instead.
  if (selection.isCollapsed) {
    for (var index = caret - 1; index >= 0; index--) {
      final character = value.text[index];
      if (character == '@') {
        start = index;
        break;
      }
      if (_isMentionBoundary(character)) break;
    }
  }

  final leadingSpace = start > 0 && !_isMentionBoundary(value.text[start - 1])
      ? ' '
      : '';
  var trailingWhitespaceLength = 0;
  while (end + trailingWhitespaceLength < value.text.length &&
      value.text[end + trailingWhitespaceLength].trim().isEmpty) {
    trailingWhitespaceLength++;
  }
  final reusesTrailingWhitespace = trailingWhitespaceLength > 0;
  final mention = '$leadingSpace@$name${reusesTrailingWhitespace ? '' : ' '}';
  final text = value.text.replaceRange(start, end, mention);
  final tokenStart = start + leadingSpace.length;
  final tokenEnd = tokenStart + name.length + 1;
  return DemoRoleMentionInsertion(
    value: TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: start + mention.length + trailingWhitespaceLength,
      ),
    ),
    tokenStart: tokenStart,
    tokenEnd: tokenEnd,
  );
}

int demoRoleMentionCount(String draft, String roleName) {
  final name = roleName.trim();
  if (name.isEmpty) return 0;
  final token = '@$name';
  var count = 0;
  var offset = 0;
  while (offset < draft.length) {
    final start = draft.indexOf(token, offset);
    if (start < 0) break;
    final end = start + token.length;
    final validStart = start == 0 || _isMentionBoundary(draft[start - 1]);
    final validEnd = end == draft.length || _isMentionBoundary(draft[end]);
    if (validStart && validEnd) count++;
    offset = end;
  }
  return count;
}

bool _isMentionBoundary(String character) =>
    character.trim().isEmpty || '，。！？、,!.?;；:：()[]{}"\''.contains(character);

bool _isDemoRoleMentionAt(String draft, int start, int end, String token) =>
    draft.substring(start, end) == token &&
    (start == 0 || _isMentionBoundary(draft[start - 1])) &&
    (end == draft.length || _isMentionBoundary(draft[end]));
