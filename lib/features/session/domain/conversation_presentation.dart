import 'conversation_snapshot.dart';

/// A deterministic display projection. Raw messages and event cursors stay intact.
class ConversationPresentation {
  ConversationPresentation(ConversationSnapshot snapshot) {
    final projected = _embedDrafts(snapshot);
    final outputs = [
      for (final message in snapshot.messages)
        for (final block in message.blocks)
          if (block.kind == 'task' && block.action == 'generation')
            ...conversationMaps(block.data['outputs']),
    ];
    final visible = <ConversationMessage>[];
    for (final message in projected) {
      // Tool-use messages also contain user-facing text; keep it in the timeline.
      final blocks = [
        for (final block in message.blocks)
          if (message.role != 'assistant' || !_generationOutput(block, outputs))
            block,
      ];
      if (blocks.isNotEmpty) {
        visible.add(
          blocks.length == message.blocks.length
              ? message
              : message.withBlocks(blocks, message.revision),
        );
      }
    }
    messages = List.unmodifiable(visible);
  }

  late final List<ConversationMessage> messages;

  static final _reference = RegExp(r'\[\[text_draft:([^\]\r\n]+)\]\]');

  static String _withoutPartialReference(String text) {
    final start = text.lastIndexOf('[[');
    if (start < 0) return text;
    final tail = text.substring(start);
    return '[[text_draft:'.startsWith(tail) ||
            tail.startsWith('[[text_draft:') && !tail.contains(']]')
        ? text.substring(0, start)
        : text;
  }

  static List<ConversationMessage> _embedDrafts(ConversationSnapshot snapshot) {
    final drafts =
        <(String?, String), List<(ConversationMessage, ConversationBlock)>>{};
    final origins = <ConversationBlock, ConversationMessage>{};
    for (final message in snapshot.messages.where(
      (m) => m.role == 'assistant',
    )) {
      for (final block in message.blocks) {
        if (block.kind == 'text_draft' && block.id.isNotEmpty) {
          (drafts[(message.runId, block.id)] ??= []).add((message, block));
          origins[block] = message;
        }
      }
    }
    final claimed = <ConversationBlock>{};
    final occurrences = <(String, String)>{};
    final projected = <ConversationMessage>[];
    for (final message in snapshot.messages) {
      if (message.role != 'assistant') {
        projected.add(message);
        continue;
      }
      final blocks = <ConversationBlock>[];
      void addText(String text) {
        if (text.trim().isNotEmpty) blocks.add(ConversationBlock.text(text));
      }

      for (final block in message.blocks) {
        if (block.type != 'text') {
          blocks.add(block);
          continue;
        }
        final matches = _reference.allMatches(block.text).toList();
        if (matches.isEmpty) {
          final text = _withoutPartialReference(block.text);
          if (text == block.text) {
            blocks.add(block);
          } else {
            addText(text.trimRight());
          }
          continue;
        }
        var cursor = 0;
        for (final match in matches) {
          addText(block.text.substring(cursor, match.start).trim());
          final id = match.group(1)!;
          final candidates = drafts[(message.runId, id)]?.where(
            (entry) =>
                message.attempt == null ||
                entry.$1.attempt == null ||
                message.attempt == entry.$1.attempt,
          );
          final draft =
              candidates
                  ?.where((entry) => entry.$1.seq <= message.seq)
                  .lastOrNull ??
              candidates?.firstOrNull;
          if (draft != null && occurrences.add((message.id, id))) {
            blocks.add(draft.$2);
            claimed.add(draft.$2);
          }
          cursor = match.end;
        }
        addText(_withoutPartialReference(block.text.substring(cursor)).trim());
      }
      projected.add(message.withBlocks(blocks, message.revision));
    }

    final activeRuns = {
      for (final run in snapshot.runs)
        if (['pending', 'running'].contains(run.state)) run.id: run,
    };
    bool active(ConversationMessage message) {
      final run = activeRuns[message.runId];
      return run != null &&
          (message.attempt == null ||
              run.attempt == null ||
              message.attempt == run.attempt);
    }

    // Deliver omitted references at the final reply; failed runs retain their saved drafts.
    for (final entries in drafts.values) {
      for (final (source, draft) in entries) {
        if (claimed.contains(draft) ||
            active(source) ||
            draft.data['delivery'] != 'reply') {
          continue;
        }
        final index = projected.lastIndexWhere(
          (reply) =>
              reply.role == 'assistant' &&
              reply.runId == source.runId &&
              source.runId != null &&
              reply.presentation == 'reply' &&
              reply.seq > source.seq &&
              (source.attempt == null ||
                  reply.attempt == null ||
                  source.attempt == reply.attempt),
        );
        if (index < 0) continue;
        final reply = projected[index];
        final saved = draft.body.replaceAll(RegExp(r'\s'), '');
        final repeated =
            saved.isNotEmpty &&
            reply.text.replaceAll(RegExp(r'\s'), '').contains(saved);
        if (!repeated) {
          projected[index] = reply.withBlocks([
            ...reply.blocks,
            draft,
          ], reply.revision);
        }
        claimed.add(draft);
      }
    }
    return [
      for (final message in projected)
        if ([
              for (final block in message.blocks)
                if (!(origins[block]?.id == message.id &&
                    (claimed.contains(block) ||
                        block.data['delivery'] == 'reply' &&
                            active(origins[block]!))))
                  block,
            ]
            case final blocks when blocks.isNotEmpty)
          message.withBlocks(blocks, message.revision),
    ];
  }

  static bool _generationOutput(
    ConversationBlock block,
    List<Map<String, Object?>> outputs,
  ) =>
      block.kind == 'content' &&
      block.action == 'generated' &&
      outputs.any(
        (ref) =>
            conversationReferenceMatches(ref, block.reference) ||
            ref['kind'] == 'media' &&
                block.mediaIds.contains(ref['id']?.toString()),
      );
}
