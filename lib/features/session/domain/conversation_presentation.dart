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
    final sourceMessages = _groupDrafts(snapshot);
    final ownerIds = {
      for (final message in sourceMessages)
        for (final block in message.blocks)
          if (message.role == 'assistant' && block.kind == 'text_draft')
            block: message.id,
    };
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
    for (final message in sourceMessages) {
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
      // Keep already visible candidates alongside a partially streamed reply.
      final preceding = projected.lastOrNull;
      if (message.transient &&
          message.presentation == 'reply' &&
          preceding != null &&
          preceding.runId == message.runId &&
          preceding.attempt == message.attempt &&
          preceding.blocks.isNotEmpty &&
          preceding.blocks.every(_isTopicDraft)) {
        final pending = preceding.blocks
            .where((b) => !blocks.contains(b))
            .toList();
        final last = blocks.lastIndexWhere(preceding.blocks.contains);
        blocks.insertAll(last < 0 ? blocks.length : last + 1, pending);
        claimed.addAll(pending);
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
    final anchors = <String, String>{};
    final usedAnchors = <String>{};
    for (final message in projected) {
      for (final owner in sourceMessages) {
        if (owner.id != message.id &&
            owner.seq <= message.seq &&
            owner.blocks.isNotEmpty &&
            owner.blocks.every(_isTopicDraft) &&
            owner.blocks.every(message.blocks.contains) &&
            usedAnchors.add(owner.id)) {
          anchors[message.id] = owner.id;
          break;
        }
      }
    }
    return [
      for (final message in projected)
        if ([
              for (final block in message.blocks)
                if (!(ownerIds[block] == message.id &&
                    (claimed.contains(block) ||
                        block.data['delivery'] == 'reply' &&
                            !_isTopicDraft(block) &&
                            active(origins[block]!))))
                  block,
            ]
            case final blocks when blocks.isNotEmpty)
          message.withBlocks(
            blocks,
            message.revision,
            presentationId: anchors[message.id],
          ),
    ];
  }

  static bool _isTopicDraft(ConversationBlock block) =>
      block.kind == 'text_draft' &&
      block.objectKind == 'topic' &&
      block.id.isNotEmpty &&
      block.data['delivery'] == 'reply';

  static List<ConversationMessage> _groupDrafts(ConversationSnapshot snapshot) {
    final grouped = <ConversationMessage>[];
    for (final message in snapshot.messages) {
      var index = grouped.length - 1;
      while (index >= 0 &&
          grouped[index].role == 'assistant' &&
          grouped[index].runId == message.runId &&
          grouped[index].attempt == message.attempt &&
          grouped[index].transient &&
          grouped[index].blocks.every((b) => b.type == 'text')) {
        index--;
      }
      final previous = index < 0 ? null : grouped[index];
      if (previous != null &&
          message.role == 'assistant' &&
          previous.role == message.role &&
          message.runId != null &&
          previous.runId == message.runId &&
          previous.attempt == message.attempt &&
          message.blocks.isNotEmpty &&
          previous.blocks.isNotEmpty &&
          message.blocks.every(_isTopicDraft) &&
          previous.blocks.every(_isTopicDraft) &&
          message.blocks.first.action == previous.blocks.last.action &&
          message.blocks.first.scopeId == previous.blocks.last.scopeId &&
          message.blocks.first.scopeKind == previous.blocks.last.scopeKind &&
          !message.blocks.any(
            (b) => previous.blocks.any((old) => old.id == b.id),
          )) {
        grouped[index] = previous.withBlocks(
          [...previous.blocks, ...message.blocks],
          message.revision > previous.revision
              ? message.revision
              : previous.revision,
        );
      } else {
        grouped.add(message);
      }
    }
    return grouped;
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
