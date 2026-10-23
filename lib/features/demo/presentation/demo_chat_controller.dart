import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';

/// Keeps simulated streaming and chat synchronization outside the widget tree.
class DemoChatController extends ChangeNotifier {
  DemoChatController(this.repository, this.sessionId) {
    _sync();
    repository.addListener(_sync);
  }
  final DemoRepository repository;
  final String sessionId;
  final chat.InMemoryChatController chatController =
      chat.InMemoryChatController();
  bool sending = false;
  bool _disposed = false;
  DemoSession get session => repository.session(sessionId);

  void _sync() {
    if (_disposed) return;
    chatController.setMessages(
      session.messages
          .map(
            (m) => chat.TextMessage(
              id: m.id,
              authorId: m.user ? 'demo-user' : 'popi',
              text: m.text,
              metadata: {'demo': m},
            ),
          )
          .toList(),
      animated: false,
    );
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
      await repository.addMessage(
        sessionId,
        DemoMessage(
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
        metadata: {'demo': DemoMessage(id: 'thinking', text: l.demoThinking)},
      );
      await chatController.insertMessage(temporary);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final preview = l.demoGenerating;
      for (var i = 1; i <= preview.length; i++) {
        if (_disposed) return true;
        final next = temporary.copyWith(
          text: preview.substring(0, i),
          metadata: {
            'demo': DemoMessage(id: 'thinking', text: preview.substring(0, i)),
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
    chatController.dispose();
    super.dispose();
  }
}
