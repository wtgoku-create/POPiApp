import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/markdown_message.dart';
import '../../../shared/widgets/app_svg_icon.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const currentUserId = 'user';
  static const agentUserId = 'agent';

  late final InMemoryChatController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController(
      messages: [
        TextMessage(
          id: 'welcome',
          authorId: agentUserId,
          createdAt: DateTime.now().toUtc(),
          text: '你好！我是你的 Agent。\n\n你可以发送问题，我会返回 **Markdown** 格式的答案。',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(14),
          child: AppSvgIcon.asset('agent'),
        ),
        title: const Text('AI Agent'),
      ),
      body: Chat(
        chatController: _chatController,
        currentUserId: currentUserId,
        backgroundColor: theme.scaffoldBackgroundColor,
        resolveUser: _resolveUser,
        builders: Builders(textMessageBuilder: _buildMarkdownMessage),
        onMessageSend: _handleMessageSend,
      ),
    );
  }

  Future<User?> _resolveUser(UserID id) async {
    return User(id: id, name: id == agentUserId ? 'Agent' : 'You');
  }

  Widget _buildMarkdownMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSentByMe
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: MarkdownMessage(data: message.text),
      ),
    );
  }

  void _handleMessageSend(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    _chatController.insertMessage(
      TextMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        authorId: currentUserId,
        createdAt: DateTime.now().toUtc(),
        text: trimmedText,
      ),
    );

    // Replace this local response with the SSE/WebSocket Agent repository.
    _chatController.insertMessage(
      TextMessage(
        id: 'agent-${DateTime.now().microsecondsSinceEpoch}',
        authorId: agentUserId,
        createdAt: DateTime.now().toUtc(),
        text: '已收到：`$trimmedText`\n\n这里接入后端 Agent 的流式响应。',
      ),
    );
  }
}
