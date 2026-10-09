import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme.dart';
import '../../../../core/network/agent_api_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_image_preview.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_video_preview.dart';
import '../../data/session_repository.dart';
import '../../domain/conversation_snapshot.dart';
import '../conversation_controller.dart';

const _conversationMessagePadding = EdgeInsets.fromLTRB(20, 6, 20, 6);
const _conversationBlockPadding = EdgeInsets.symmetric(vertical: 4);

String conversationErrorText(Object? error, AppLocalizations l10n) {
  if (error is AgentApiException &&
      ['INSUFFICIENT_POINTS', 'INSUFFICIENT_COINS'].contains(error.code)) {
    return l10n.chatInsufficientPoints;
  }
  if (error is ApiException && error.message?.isNotEmpty == true) {
    return error.message!;
  }
  return l10n.chatRequestFailed;
}

/// Keeps message identities stable while streaming through updateMessage.
class ConversationTimeline extends StatefulWidget {
  const ConversationTimeline({required this.controller, super.key});
  final ConversationController controller;
  @override
  State<ConversationTimeline> createState() => _ConversationTimelineState();
}

class _ConversationTimelineState extends State<ConversationTimeline> {
  final _chat = chat.InMemoryChatController();
  ConversationSnapshot? _lastSnapshot;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(ConversationTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _lastSnapshot = null;
      _sync();
    }
  }

  void _sync() {
    final snapshot = widget.controller.snapshot;
    if (snapshot == null || identical(snapshot, _lastSnapshot)) return;
    final messages = [
      for (final message in snapshot.messages)
        chat.TextMessage(
          id: message.id,
          authorId: message.role == 'user'
              ? widget.controller.userId
              : 'popi-agent',
          createdAt: message.createdAt,
          text: message.text,
          metadata: {'conversation': message},
        ),
    ];
    final previous = _chat.messages;
    if (_lastSnapshot?.session.id != snapshot.session.id ||
        previous.any(
          (item) => !messages.any((message) => message.id == item.id),
        )) {
      unawaited(_chat.setMessages(messages, animated: false));
    } else {
      for (var i = 0; i < messages.length; i++) {
        final old = _chat.messages
            .where((item) => item.id == messages[i].id)
            .firstOrNull;
        if (old == null) {
          unawaited(
            _chat.insertMessage(messages[i], index: i, animated: false),
          );
        } else {
          unawaited(_chat.updateMessage(old, messages[i]));
        }
      }
    }
    _lastSnapshot = snapshot;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      final controller = widget.controller;
      return Chat(
        currentUserId: controller.userId,
        resolveUser: (id) async =>
            chat.User(id: id, name: id == 'popi-agent' ? 'POPi' : null),
        chatController: _chat,
        backgroundColor: Colors.transparent,
        builders: chat.Builders(
          composerBuilder: (_) => const SizedBox.shrink(),
          emptyChatListBuilder: (_) => const SizedBox.shrink(),
          chatAnimatedListBuilder: (context, itemBuilder) => ChatAnimatedList(
            itemBuilder: itemBuilder,
            handleSafeArea: false,
            topPadding: 10,
            bottomPadding: 32,
            scrollToBottomAppearanceThreshold: 120,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            bottomSliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final block
                            in controller.snapshot?.legacyObjects ??
                                <ConversationBlock>[])
                          ConversationObjectView(
                            block: block,
                            controller: controller,
                          ),
                        if (controller.loading) const LinearProgressIndicator(),
                        if (controller.running &&
                            !(controller.snapshot?.messages.any(
                                  (message) => message.blocks.any(
                                    (block) =>
                                        block.kind == 'progress' &&
                                        [
                                          'pending',
                                          'running',
                                        ].contains(block.status),
                                  ),
                                ) ??
                                false))
                          _ConversationThinking(label: l10n.chatThinking),
                        if (controller.connection ==
                            ConversationConnection.reconnecting)
                          Text(
                            l10n.chatReconnecting,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        for (final run
                            in controller.snapshot?.runs ?? <ConversationRun>[])
                          if ([
                            'failed',
                            'interrupted',
                            'canceled',
                            'aborted',
                          ].contains(run.state))
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    run.error ??
                                        (run.state == 'failed'
                                            ? l10n.chatRunFailed
                                            : l10n.chatStopped),
                                  ),
                                ),
                                if (run.retryable &&
                                    [
                                      'failed',
                                      'interrupted',
                                    ].contains(run.state))
                                  IconButton(
                                    tooltip: l10n.retry,
                                    onPressed:
                                        controller.pending || controller.running
                                        ? null
                                        : () => controller.retry(run.id),
                                    icon: const Icon(Icons.refresh),
                                  ),
                              ],
                            ),
                        if (controller.error != null)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversationErrorText(controller.error, l10n),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.retry,
                                onPressed: controller.pending
                                    ? null
                                    : controller.refresh,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          chatMessageBuilder:
              (
                context,
                message,
                index,
                animation,
                child, {
                required isSentByMe,
                groupStatus,
                isRemoved,
              }) => Padding(
                padding: _conversationMessagePadding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: isSentByMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isSentByMe
                                ? constraints.maxWidth * .85
                                : constraints.maxWidth,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          textMessageBuilder:
              (context, message, index, {required isSentByMe, groupStatus}) {
                final item =
                    message.metadata!['conversation'] as ConversationMessage;
                final colors = Theme.of(context).colorScheme;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: isSentByMe ? colors.surface : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(26),
                      bottomLeft: Radius.circular(26),
                      bottomRight: Radius.circular(26),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isSentByMe ? 20 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final block in item.blocks)
                          if (block.type == 'text' && block.text.isNotEmpty)
                            MarkdownMessage(
                              text: block.text,
                              emphasized: isSentByMe,
                            )
                          else if (block.type == 'media' &&
                              block.mediaId != null)
                            ConversationMediaView(
                              id: block.mediaId!,
                              repository: controller.repository,
                            )
                          else if (block.type == 'object')
                            ConversationObjectView(
                              key: ValueKey(
                                '${item.id}:${block.kind}:${block.id}',
                              ),
                              block: block,
                              controller: controller,
                            ),
                      ],
                    ),
                  ),
                );
              },
        ),
      );
    },
  );
}

class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({
    required this.text,
    this.emphasized = false,
    this.compact = false,
    super.key,
  });
  final String text;
  final bool emphasized;
  final bool compact;
  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: text,
    selectable: true,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: compact ? 16 : 18,
        height: compact ? 1.5 : 1.6,
        fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
      ),
      blockSpacing: 12,
      h1: const TextStyle(
        fontSize: 22,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      h2: const TextStyle(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      h3: const TextStyle(
        fontSize: 18,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
    ),
    onTapLink: (_, href, __) {
      if (href != null) _openUrl(href);
    },
  );
}

/// Only displays the real run state; backend stages are not inferred locally.
class _ConversationThinking extends StatelessWidget {
  const _ConversationThinking({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: _conversationBlockPadding,
      child: Row(
        children: [
          const AppSvgIcon.asset('chat_thinking', size: 25),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              // A static indicator respects the system's reduced-motion setting.
              value: MediaQuery.disableAnimationsOf(context) ? .75 : null,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openUrl(String value) async {
  final uri = Uri.tryParse(value);
  if (uri != null && ['https', 'http'].contains(uri.scheme)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class ConversationMediaView extends StatefulWidget {
  const ConversationMediaView({
    required this.id,
    required this.repository,
    super.key,
  });
  final String id;
  final SessionRepository repository;
  @override
  State<ConversationMediaView> createState() => _ConversationMediaViewState();
}

class _ConversationMediaViewState extends State<ConversationMediaView> {
  late Future<ConversationMedia> _media = widget.repository.media(widget.id);
  @override
  void didUpdateWidget(ConversationMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.repository != widget.repository) {
      _media = widget.repository.media(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ConversationMedia>(
    future: _media,
    builder: (context, snapshot) {
      final l10n = AppLocalizations.of(context)!;
      if (snapshot.hasError) {
        return _MediaFrame(
          child: Center(
            child: IconButton(
              tooltip: l10n.retry,
              onPressed: () =>
                  setState(() => _media = widget.repository.media(widget.id)),
              icon: const Icon(Icons.refresh),
            ),
          ),
        );
      }
      final media = snapshot.data;
      if (media == null) {
        return const _MediaFrame(
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (media.kind == 'image') {
        return Semantics(
          button: true,
          label: l10n.chatPreviewImage,
          child: GestureDetector(
            onTap: () => AppImagePreview.show(
              context: context,
              image: NetworkImage(media.url),
              heroTag: 'conversation-media-${media.id}',
            ),
            child: _MediaFrame(
              child: Image.network(
                media.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                errorBuilder: (_, __, ___) => Center(
                  child: IconButton(
                    tooltip: l10n.retry,
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      NetworkImage(media.url).evict();
                      setState(
                        () => _media = widget.repository.media(widget.id),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return TextButton.icon(
        onPressed: () => media.kind == 'video'
            ? AppVideoPreview.show(context: context, url: Uri.parse(media.url))
            : _openUrl(media.url),
        icon: const Icon(Icons.play_arrow),
        label: Text(
          media.kind == 'video' ? l10n.chatPlayVideo : l10n.chatPlayAudio,
        ),
      );
    },
  );
}

/// Media keeps the same footprint while its URL and image bytes load.
class _MediaFrame extends StatelessWidget {
  const _MediaFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: _conversationBlockPadding,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.child, this.framed = true});
  final Widget child;
  final bool framed;

  @override
  Widget build(BuildContext context) => Container(
    margin: _conversationBlockPadding,
    padding: framed ? const EdgeInsets.all(20) : EdgeInsets.zero,
    width: double.infinity,
    decoration: framed
        ? BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white.withValues(alpha: .6)
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.card),
          )
        : null,
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class ConversationObjectView extends StatefulWidget {
  const ConversationObjectView({
    required this.block,
    required this.controller,
    this.framed = true,
    super.key,
  });
  final ConversationBlock block;
  final ConversationController controller;
  final bool framed;
  @override
  State<ConversationObjectView> createState() => _ConversationObjectViewState();
}

class _ConversationObjectViewState extends State<ConversationObjectView> {
  Timer? _expiryTimer;
  bool _expanded = false;
  bool _progressExpanded = true;
  @override
  void initState() {
    super.initState();
    if (widget.block.expiresAt != null) {
      _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final controller = widget.controller;
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final statusLabel = block.kind == 'role'
        ? switch (block.action) {
            'published' => l10n.chatRolePublished,
            'edited' => l10n.chatRoleUpdated,
            'created' => l10n.chatRoleCreated,
            _ => _statusLabel(block.status, l10n),
          }
        : _statusLabel(block.status, l10n);
    final details = block.details;
    final disabled =
        controller.pending || controller.running || controller.loading;
    if (block.kind == 'progress') {
      return Padding(
        padding: _conversationBlockPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppSvgIcon.asset('chat_thinking', size: 25),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    ['pending', 'running'].contains(block.status)
                        ? l10n.chatThinking
                        : statusLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _progressExpanded
                      ? l10n.chatCollapseProgress
                      : l10n.chatExpandProgress,
                  onPressed: () =>
                      setState(() => _progressExpanded = !_progressExpanded),
                  icon: Icon(
                    _progressExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                  ),
                ),
              ],
            ),
            if (_progressExpanded)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.white.withValues(alpha: .5)
                      : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Render only backend-provided steps; never manufacture progress.
                    for (final (key, state) in block.progressSteps)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (['running', 'waiting'].contains(state))
                              SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: MediaQuery.disableAnimationsOf(context)
                                      ? .75
                                      : null,
                                ),
                              )
                            else
                              Icon(
                                state == 'completed'
                                    ? Icons.check
                                    : state == 'failed'
                                    ? Icons.error_outline
                                    : state == 'skipped'
                                    ? Icons.remove
                                    : Icons.circle_outlined,
                                size: 18,
                                color: state == 'failed'
                                    ? colors.error
                                    : colors.primary,
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _progressLabel(key, l10n),
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (block.kind == 'question' && block.status == 'pending') {
      return _ConversationQuestion(
        key: ValueKey('${block.id}:${block.revision}'),
        block: block,
        controller: controller,
      );
    }
    return _ConversationCard(
      framed: widget.framed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (statusLabel.isNotEmpty) ...[
            Row(
              children: [
                if ([
                  'pending',
                  'running',
                  'submitting',
                ].contains(block.status)) ...[
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: MediaQuery.disableAnimationsOf(context)
                          ? .75
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: block.status == 'failed'
                          ? colors.error
                          : colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (block.title.isNotEmpty || block.avatar != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (block.avatar != null || details.isNotEmpty) ...[
                  SizedBox.square(
                    dimension: 70,
                    child: block.avatar == null
                        ? const AppSvgIcon.asset('chat_role_draft', size: 70)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              block.avatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const AppSvgIcon.asset(
                                    'chat_role_draft',
                                    size: 70,
                                  ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    block.title,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          if (block.body.isNotEmpty &&
              !details.any((detail) => detail.$2 == block.body))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: MarkdownMessage(text: block.body, compact: true),
            ),
          // Keep long profiles compact in the timeline; expansion retains the
          // same object identity while SSE updates refresh its contents.
          for (final (label, value) in _expanded ? details : details.take(3))
            _ConversationDetail(label: _detailLabel(label, l10n), value: value),
          if (details.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  backgroundColor: colors.primary.withValues(alpha: .05),
                  minimumSize: const Size(0, 50),
                  shape: const StadiumBorder(),
                ),
                iconAlignment: IconAlignment.end,
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.chevron_right,
                  size: 20,
                ),
                label: Text(
                  _expanded ? l10n.chatCollapseProfile : l10n.roleFullProfile,
                ),
              ),
            ),
          for (final prompt in block.planPrompts)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MarkdownMessage(text: prompt, compact: true),
            ),
          for (final (label, value) in block.answeredFields)
            _ConversationDetail(label: label, value: value),
          for (final result in block.results)
            ConversationObjectView(
              key: ValueKey(result.id),
              block: result,
              controller: controller,
              framed: false,
            ),
          for (final id in block.mediaIds)
            ConversationMediaView(id: id, repository: controller.repository),
          if (block.estimatedPoints != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                l10n.chatEstimatedPoints(block.estimatedPoints!.toString()),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          if (block.kind == 'plan' && block.confirmationAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (block.allowedActions.contains('cancel'))
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(112, 50),
                        shape: const StadiumBorder(),
                        foregroundColor: colors.onSurfaceVariant,
                        side: BorderSide(color: colors.onSurfaceVariant),
                      ),
                      onPressed: disabled
                          ? null
                          : () => controller.confirm(block, 'cancel'),
                      child: Text(l10n.cancel),
                    ),
                  if (block.allowedActions.contains('confirm'))
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(126, 50),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: disabled
                          ? null
                          : () async {
                              final confirmed = await AppDialog.confirm(
                                context: context,
                                title: block.title,
                                description: block.estimatedPoints == null
                                    ? block.body
                                    : l10n.chatEstimatedPoints(
                                        block.estimatedPoints!.toString(),
                                      ),
                                cancelLabel: l10n.cancel,
                                confirmLabel: l10n.confirm,
                              );
                              if (confirmed == true && context.mounted) {
                                await controller.confirm(block, 'confirm');
                              }
                            },
                      child: Text(l10n.chatConfirmGeneration),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationDetail extends StatelessWidget {
  const _ConversationDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 16, height: 1.5)),
      ],
    ),
  );
}

String _detailLabel(String label, AppLocalizations l10n) => switch (label) {
  'name' || 'title' => l10n.chatRoleName,
  'description' || 'brief' => l10n.roleDescription,
  'style' || 'expressionStyle' => l10n.roleStyle,
  'audience' || 'targetAudience' => l10n.roleAudience,
  'tags' || 'contentTags' => l10n.roleTags,
  'appearance' => l10n.roleAppearance,
  'positioning' => l10n.rolePositioning,
  'boundaries' => l10n.roleBoundaries,
  _ => label,
};

String _progressLabel(String key, AppLocalizations l10n) => switch (key) {
  'script.run.preparing' => l10n.chatPreparing,
  'script.run.generatingReply' => l10n.chatGeneratingReply,
  'script.run.savingArtifact' => l10n.chatSavingArtifact,
  'script.run.planningGeneration' => l10n.chatPlanningGeneration,
  'pages.studio.progress.readRole' => l10n.chatReadRole,
  'pages.studio.progress.readContext' => l10n.chatReadContext,
  'pages.studio.progress.topics' => l10n.chatTopics,
  'pages.studio.progress.prepareRole' => l10n.chatPrepareRole,
  'pages.studio.progress.askUser' => l10n.chatAskUser,
  'pages.studio.progress.saveRole' => l10n.chatSaveRole,
  'pages.studio.progress.publishRole' => l10n.chatPublishRole,
  'pages.studio.state.completed' => l10n.chatCompleted,
  _ => l10n.chatProcessing,
};

String _statusLabel(String status, AppLocalizations l10n) => switch (status) {
  'pending' || 'running' || 'submitting' => l10n.chatThinking,
  'ready' || 'waiting_user' => l10n.chatAwaitingConfirmation,
  'confirmed' ||
  'answered' ||
  'completed' ||
  'published' ||
  'active' => l10n.chatCompleted,
  'canceled' || 'interrupted' || 'aborted' => l10n.chatStopped,
  'expired' || 'stale' => l10n.chatExpired,
  'failed' => l10n.chatRunFailed,
  _ => '',
};

class _ConversationQuestion extends StatefulWidget {
  const _ConversationQuestion({
    required this.block,
    required this.controller,
    super.key,
  });
  final ConversationBlock block;
  final ConversationController controller;
  @override
  State<_ConversationQuestion> createState() => _ConversationQuestionState();
}

class _ConversationQuestionState extends State<_ConversationQuestion> {
  final _answers = <String, Object?>{};
  final _custom = <String, String>{};
  final _customControllers = <String, TextEditingController>{};
  bool _submitted = false;
  @override
  void dispose() {
    for (final controller in _customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> get _values => {
    for (final field in widget.block.fields)
      if (_answers[field.id] != null ||
          (_custom[field.id]?.trim().isNotEmpty ?? false))
        field.id: field.multiple
            ? [
                ...?_answers[field.id] as List<String>?,
                if (_custom[field.id]?.trim().isNotEmpty ?? false)
                  _custom[field.id]!.trim(),
              ]
            : (_custom[field.id]?.trim().isNotEmpty ?? false)
            ? _custom[field.id]!.trim()
            : _answers[field.id],
  };
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disabled =
        _submitted ||
        widget.controller.pending ||
        widget.controller.running ||
        widget.controller.loading;
    final valid = widget.block.fields.every(
      (field) =>
          !field.required ||
          (field.multiple
              ? (_values[field.id] as List?)?.isNotEmpty == true
              : (_values[field.id] as String?)?.isNotEmpty == true),
    );
    return _ConversationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.block.title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final field in widget.block.fields) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 6),
              child: Text(
                field.label,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (field.multiple)
              for (final option in field.options)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: const StadiumBorder(),
                  selected: (_answers[field.id] as List<String>? ?? [])
                      .contains(option),
                  selectedTileColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .05),
                  title: Text(option),
                  value: (_answers[field.id] as List<String>? ?? []).contains(
                    option,
                  ),
                  onChanged: disabled
                      ? null
                      : (checked) => setState(() {
                          final selected = [
                            ...?_answers[field.id] as List<String>?,
                          ];
                          checked == true
                              ? selected.add(option)
                              : selected.remove(option);
                          _answers[field.id] = selected;
                        }),
                ),
            if (!field.multiple)
              RadioGroup<String>(
                groupValue: _answers[field.id] as String?,
                onChanged: (value) => setState(() {
                  _answers[field.id] = value;
                  _custom.remove(field.id);
                  _customControllers[field.id]?.clear();
                }),
                child: Column(
                  children: [
                    for (final option in field.options)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        shape: const StadiumBorder(),
                        selected: _answers[field.id] == option,
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .05),
                        title: Text(option),
                        value: option,
                        enabled: !disabled,
                      ),
                  ],
                ),
              ),
            TextFormField(
              controller: _customControllers.putIfAbsent(
                field.id,
                TextEditingController.new,
              ),
              enabled: !disabled,
              maxLength: 8000,
              decoration: InputDecoration(
                hintText: l10n.chatCustomAnswer,
                counterText: '',
              ),
              onChanged: (value) => setState(() {
                _custom[field.id] = value;
                if (!field.multiple && value.trim().isNotEmpty) {
                  _answers.remove(field.id);
                }
              }),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(112, 50),
                  shape: const StadiumBorder(),
                ),
                onPressed: disabled ? null : () => _respond('cancel'),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(112, 50),
                  shape: const StadiumBorder(),
                ),
                onPressed: disabled || !valid ? null : () => _respond('submit'),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respond(String action) async {
    final success = await widget.controller.answer(
      widget.block,
      action,
      _values,
    );
    if (success && mounted) setState(() => _submitted = true);
  }
}
