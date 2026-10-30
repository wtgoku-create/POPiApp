import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_models.dart';

/// Keeps simulated streaming and chat synchronization outside the widget tree.
class V2ChatController extends ChangeNotifier {
  V2ChatController(this.repository, this.sessionId) {
    _sync();
    repository.addListener(_sync);
    repository.watchSession(sessionId);
  }
  final V2Repository repository;
  final String sessionId;
  final chat.InMemoryChatController chatController =
      chat.InMemoryChatController();
  bool sending = false;
  bool _disposed = false;
  V2Session get session => repository.session(sessionId);

  void _sync() {
    if (_disposed || !repository.sessions.any((s) => s.id == sessionId)) return;
    final messages = session.messages
        .map(
          (m) => chat.TextMessage(
            id: m.id,
            authorId: m.user ? 'demo-user' : 'popi',
            text: m.text,
            metadata: {'demo': m},
          ),
        )
        .toList();
    if (repository.isRemote &&
        session.running &&
        !session.messages.any((m) => m.question?.isPending ?? false)) {
      messages.add(
        chat.TextMessage(
          id: 'v2-pending:$sessionId',
          authorId: 'popi',
          text: '',
          metadata: {
            'demo': V2Message(
              id: 'v2-pending:$sessionId',
              text: '',
              status: 'running',
            ),
          },
        ),
      );
    }
    chatController.setMessages(messages, animated: false);
    notifyListeners();
  }

  Future<bool> send(
    String text,
    List<String> assets,
    AppLocalizations l,
  ) async {
    if (sending || (text.trim().isEmpty && assets.isEmpty)) return false;
    sending = true;
    notifyListeners();
    try {
      if (repository.isRemote) {
        await repository.sendMessage(sessionId, text, assets);
        return true;
      }
      await repository.addMessage(
        sessionId,
        V2Message(
          id: const Uuid().v4(),
          text: text.trim(),
          user: true,
          assetIds: assets,
        ),
      );
      if (_disposed) return true;
      var temporary = chat.TextMessage(
        id: const Uuid().v4(),
        authorId: 'popi',
        text: l.demoThinking,
        metadata: {'demo': V2Message(id: 'thinking', text: l.demoThinking)},
      );
      await chatController.insertMessage(temporary);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final preview = l.demoGenerating;
      for (var i = 1; i <= preview.length; i++) {
        if (_disposed) return true;
        final next = temporary.copyWith(
          text: preview.substring(0, i),
          metadata: {
            'demo': V2Message(id: 'thinking', text: preview.substring(0, i)),
          },
        );
        await chatController.updateMessage(temporary, next);
        temporary = next;
        await Future<void>.delayed(const Duration(milliseconds: 65));
      }
      if (_disposed) return true;
      await repository.reply(
        sessionId,
        text,
        text: l.demoReply,
        imageText: l.demoImageReply,
        scriptText: l.demoScriptReply,
        audioText: l.demoAudioReply,
        videoText: l.demoVideoReply,
      );
      return true;
    } finally {
      sending = false;
      if (!_disposed) _sync();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    repository.removeListener(_sync);
    repository.unwatchSession(sessionId);
    chatController.dispose();
    super.dispose();
  }
}
