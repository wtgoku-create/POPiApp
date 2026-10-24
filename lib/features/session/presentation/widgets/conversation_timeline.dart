import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/app_network_image.dart';
import '../../../../app/theme.dart';
import '../../../../core/network/agent_api_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_image_preview.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/generation_credit_notice.dart';
import '../../../../shared/widgets/app_video_preview.dart';
import '../../../../shared/widgets/app_video_player.dart';
import '../../../role_guide/presentation/widgets/role_storyboard_body.dart';
import '../../data/session_repository.dart';
import '../../domain/conversation_snapshot.dart';
import '../conversation_controller.dart';
import '../conversation_error_text.dart';
import 'conversation_role_card.dart';
import 'conversation_selected_topic_card.dart';
import 'conversation_card.dart';
import 'conversation_style.dart';
import 'conversation_selection_scope.dart';
import 'conversation_card_content.dart';
import 'conversation_generation_card.dart';
import 'conversation_task_card.dart';
import 'conversation_progress.dart';

const _conversationMessageSpacing = 30.0;
const _conversationCardSpacing = 10.0;

bool _isCardBlock(ConversationBlock block) =>
    block.type == 'object' || block.type == 'media';

bool _isCandidateBlock(ConversationBlock block) =>
    block.type == 'object' &&
    (block.kind == 'topic' && block.action != 'selected' ||
        block.kind == 'text_draft');

double _messageSpacing(
  ConversationMessage previous,
  ConversationMessage current,
) {
  // Progress and its reply can arrive in separate protocol messages.
  if (previous.role != 'user' &&
      current.role != 'user' &&
      previous.blocks.isNotEmpty &&
      current.blocks.isNotEmpty &&
      _isCardBlock(previous.blocks.last) &&
      (_isCardBlock(current.blocks.first) ||
          previous.blocks.last.kind == 'progress' &&
              current.blocks.first.type == 'text' &&
              previous.runId == current.runId)) {
    return _conversationCardSpacing;
  }
  return _conversationMessageSpacing;
}

const _userBubbleRadius = BorderRadius.only(
  topLeft: Radius.circular(26),
  bottomLeft: Radius.circular(26),
  bottomRight: Radius.circular(26),
);

bool _hasFullWidthObjects(ConversationMessage message) => message.blocks.any(
  (block) =>
      block.type == 'object' &&
      (block.kind == 'role' ||
          block.kind == 'topic' && block.action == 'selected'),
);

// Progress uses the event suffix "started" while runs use the state "running".
bool _progressRunning(ConversationBlock block) =>
    ['pending', 'started', 'running'].contains(block.status);

String conversationErrorText(Object? error, AppLocalizations l10n) {
  if (error is AgentApiException) {
    return conversationTaskErrorText(
      l10n,
      code: error.code,
      message: error.message,
      fallback: l10n.chatRequestFailed,
    );
  }
  if (error is ApiException && error.message?.isNotEmpty == true) {
    return error.message!;
  }
  return l10n.chatRequestFailed;
}

/// Keeps message identities stable while streaming through updateMessage.
class ConversationTimeline extends StatefulWidget {
  const ConversationTimeline({
    required this.controller,
    this.onRevise,
    this.topPadding = 10,
    super.key,
  });
  final ConversationController controller;
  final ValueChanged<ConversationBlock>? onRevise;
  final double topPadding;
  @override
  State<ConversationTimeline> createState() => _ConversationTimelineState();
}

class _ConversationTimelineState extends State<ConversationTimeline> {
  final _chat = chat.InMemoryChatController();
  final _scroll = ScrollController();
  ConversationSnapshot? _lastSnapshot;
  bool _initialHistoryPending = false;
  bool _initialScrollScheduled = false;
  bool _latestMessageBuilt = false;
  bool _followTail = true;
  bool _tailScrollScheduled = false;
  bool _adjustingTail = false;

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
      _initialHistoryPending = false;
      _latestMessageBuilt = false;
      _followTail = true;
      _sync();
    }
  }

  void _sync() {
    final snapshot = widget.controller.snapshot;
    if (snapshot == null || identical(snapshot, _lastSnapshot)) return;
    final previousIds = _chat.messages.map((message) => message.id).toSet();
    if (_lastSnapshot?.session.id != snapshot.session.id) {
      _initialHistoryPending = snapshot.presentationMessages.isNotEmpty;
      _latestMessageBuilt = false;
      _followTail = true;
    } else if (snapshot.presentationMessages.any(
      (message) => message.role == 'user' && !previousIds.contains(message.id),
    )) {
      _followTail = true;
    }
    final messages = [
      for (final message in snapshot.presentationMessages)
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
    if (_lastSnapshot?.session.id != snapshot.session.id) {
      unawaited(_chat.setMessages(messages, animated: false));
    } else {
      // Emit removals and updates separately so retained cards receive new metadata.
      final ids = messages.map((message) => message.id).toSet();
      for (final old in previous.reversed.toList()) {
        if (!ids.contains(old.id)) {
          unawaited(_chat.removeMessage(old, animated: false));
        }
      }
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
    _scheduleInitialScroll();
    _scheduleTailScroll();
  }

  void _scheduleTailScroll() {
    if (!_followTail || _initialHistoryPending || _tailScrollScheduled) return;
    _tailScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tailScrollScheduled = false;
      if (!mounted ||
          !_followTail ||
          _initialHistoryPending ||
          !_scroll.hasClients) {
        return;
      }
      final position = _scroll.position;
      if (position.isScrollingNotifier.value) return;
      if ((position.maxScrollExtent - position.pixels).abs() > 1) {
        _adjustingTail = true;
        try {
          _scroll.jumpTo(position.maxScrollExtent);
        } finally {
          _adjustingTail = false;
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.forward) {
      _initialHistoryPending = false;
      _followTail = false;
    } else if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      if (notification is ScrollUpdateNotification &&
          !_adjustingTail &&
          !_initialHistoryPending &&
          (notification.scrollDelta ?? 0) < 0) {
        // Focus and ensureVisible can reveal history without a drag gesture.
        _followTail = false;
      }
      if (notification.metrics.extentAfter <= 1) _followTail = true;
      if (notification is ScrollEndNotification) _scheduleTailScroll();
    }
    return false;
  }

  void _scheduleInitialScroll() {
    if (!_initialHistoryPending || _initialScrollScheduled) return;
    _initialScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialScrollScheduled = false;
      if (!mounted || !_initialHistoryPending || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (_latestMessageBuilt &&
          (position.pixels - position.maxScrollExtent).abs() <= 1 &&
          !position.isScrollingNotifier.value) {
        setState(() => _initialHistoryPending = false);
        return;
      }
      // Lazy items refine the estimated extent until the actual last message is laid out.
      _scroll.jumpTo(position.maxScrollExtent);
      _scheduleInitialScroll();
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  List<Widget> _messageBlockViews(
    ConversationMessage message,
    ConversationController controller,
    bool isSentByMe,
  ) {
    final children = <Widget>[];
    final objectOccurrences = <(String?, String), int>{};
    var topicGroup = 0;
    var castGroup = 0;
    for (var index = 0; index < message.blocks.length; index++) {
      final block = message.blocks[index];
      if (block.type == 'object' &&
          block.kind == 'role' &&
          block.action == 'cast') {
        final cast = [block];
        while (index + 1 < message.blocks.length) {
          final next = message.blocks[index + 1];
          if (next.type != 'object' ||
              next.kind != 'role' ||
              next.action != 'cast' ||
              next.scopeId != block.scopeId ||
              next.scopeKind != block.scopeKind) {
            break;
          }
          cast.add(next);
          index++;
        }
        children.add(
          ConversationCastCard(
            key: ValueKey((message.id, 'cast', castGroup++)),
            blocks: cast,
          ),
        );
      } else if (_isCandidateBlock(block) && !isSentByMe) {
        final topics = [block];
        // Keep separate batches and intervening text/media in their original order.
        while (index + 1 < message.blocks.length) {
          final next = message.blocks[index + 1];
          if (!_isCandidateBlock(next) ||
              next.kind != block.kind ||
              block.kind == 'text_draft' &&
                  next.objectKind != block.objectKind ||
              next.action != block.action ||
              next.scopeId != block.scopeId ||
              next.scopeKind != block.scopeKind) {
            break;
          }
          topics.add(next);
          index++;
        }
        children.add(
          _ConversationTopics(
            key: ValueKey((message.id, 'topics', topicGroup++)),
            topics: topics,
            message: message,
            controller: controller,
          ),
        );
      } else if (block.type == 'text' && block.text.trim().isNotEmpty) {
        final text = MarkdownMessage(text: block.text, emphasized: isSentByMe);
        children.add(
          isSentByMe && _hasFullWidthObjects(message)
              ? LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * .85,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ConversationStyle.userBubbleColor(context),
                          borderRadius: _userBubbleRadius,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: text,
                        ),
                      ),
                    ),
                  ),
                )
              : text,
        );
      } else if (block.type == 'media' && block.mediaId != null) {
        children.add(
          ConversationMediaView(
            id: block.mediaId!,
            repository: controller.repository,
          ),
        );
      } else if (block.type == 'object') {
        children.add(
          ConversationObjectView(
            key: ValueKey((
              message.id,
              block.kind,
              block.id,
              objectOccurrences.update(
                (block.kind, block.id),
                (count) => count + 1,
                ifAbsent: () => 0,
              ),
            )),
            block: block,
            controller: controller,
            onRevise: widget.onRevise,
          ),
        );
      }
    }
    return children;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _chat.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      final controller = widget.controller;
      final positioning =
          controller.loading && controller.snapshot == null ||
          _initialHistoryPending;
      final legacyObjects = controller.snapshot?.legacyObjects ?? [];
      final showThinking =
          controller.running &&
          !(controller.snapshot?.messages.any(
                (message) => message.blocks.any(
                  (block) =>
                      block.kind == 'progress' && _progressRunning(block),
                ),
              ) ??
              false);
      final reconnecting =
          controller.connection == ConversationConnection.reconnecting;
      final failedRuns =
          controller.snapshot?.runs
              .where(
                (run) => [
                  'failed',
                  'interrupted',
                  'canceled',
                  'aborted',
                ].contains(run.state),
              )
              .toList() ??
          <ConversationRun>[];
      final hasFooter =
          legacyObjects.isNotEmpty ||
          showThinking ||
          reconnecting ||
          failedRuns.isNotEmpty;
      final lastMessage = controller.snapshot?.presentationMessages.lastOrNull;
      final footerSpacing = lastMessage == null || !hasFooter
          ? 0.0
          : legacyObjects.isNotEmpty &&
                lastMessage.role != 'user' &&
                lastMessage.blocks.isNotEmpty &&
                _isCardBlock(lastMessage.blocks.last)
          ? _conversationCardSpacing
          : _conversationMessageSpacing;
      final timeline = Chat(
        currentUserId: controller.userId,
        resolveUser: (id) async =>
            chat.User(id: id, name: id == 'popi-agent' ? 'POPi' : null),
        chatController: _chat,
        backgroundColor: Colors.transparent,
        builders: chat.Builders(
          composerBuilder: (_) => const SizedBox.shrink(),
          emptyChatListBuilder: (_) => const SizedBox.shrink(),
          chatAnimatedListBuilder: (context, itemBuilder) =>
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  // Streaming, media loads and composer resizing change extents
                  // without inserting a message into the chat controller.
                  if (notification.depth == 0) _scheduleTailScroll();
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScroll,
                  child: ChatAnimatedList(
                    // Short conversations start at the top; long histories open at the end.
                    scrollController: _scroll,
                    initialScrollToEndMode: InitialScrollToEndMode.none,
                    shouldScrollToEndWhenAtBottom: false,
                    shouldScrollToEndWhenSendingMessage: false,
                    scrollToEndAnimationDuration: Duration.zero,
                    itemBuilder: itemBuilder,
                    handleSafeArea: false,
                    topPadding: widget.topPadding,
                    bottomPadding: 32,
                    scrollToBottomAppearanceThreshold: 120,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    bottomSliver: SliverToBoxAdapter(
                      child: ConversationSelectionScope(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            footerSpacing,
                            20,
                            0,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: _conversationCardSpacing,
                                children: [
                                  for (final block in legacyObjects)
                                    ConversationObjectView(
                                      block: block,
                                      controller: controller,
                                    ),
                                  if (showThinking)
                                    _ConversationProgressHeader(
                                      label: l10n.chatThinking,
                                      running: true,
                                    ),
                                  if (reconnecting)
                                    Text(
                                      l10n.chatReconnecting,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  for (final run in failedRuns)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conversationTaskErrorText(
                                              l10n,
                                              code: run.errorCode,
                                              message: run.error,
                                              fallback: run.state == 'failed'
                                                  ? l10n.chatRunFailed
                                                  : l10n.chatStopped,
                                            ),
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
                                                controller.pending ||
                                                    controller.running
                                                ? null
                                                : () =>
                                                      controller.retry(run.id),
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
              }) {
                final item =
                    message.metadata!['conversation'] as ConversationMessage;
                if (item.id ==
                    _lastSnapshot?.presentationMessages.lastOrNull?.id) {
                  _latestMessageBuilt = true;
                }
                final userBubble = isSentByMe && !_hasFullWidthObjects(item);
                return ConversationSelectionScope(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      index == 0
                          ? 0
                          : _messageSpacing(
                              _chat
                                      .messages[index - 1]
                                      .metadata!['conversation']
                                  as ConversationMessage,
                              item,
                            ),
                      20,
                      0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: LayoutBuilder(
                          builder: (context, constraints) => Align(
                            alignment: userBubble
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: userBubble
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
                );
              },
          textMessageBuilder:
              (context, message, index, {required isSentByMe, groupStatus}) {
                final item =
                    message.metadata!['conversation'] as ConversationMessage;
                final userBubble = isSentByMe && !_hasFullWidthObjects(item);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: userBubble
                        ? ConversationStyle.userBubbleColor(context)
                        : Colors.transparent,
                    borderRadius: _userBubbleRadius,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(userBubble ? 20 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: _conversationCardSpacing,
                      children: _messageBlockViews(
                        item,
                        controller,
                        isSentByMe,
                      ),
                    ),
                  ),
                );
              },
        ),
      );
      // Keep lazy history laid out, but reveal it only at its final scroll offset.
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: positioning,
            child: ExcludeSemantics(
              excluding: positioning,
              child: Opacity(opacity: positioning ? 0 : 1, child: timeline),
            ),
          ),
          if (positioning)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _ConversationSkeleton(
                    label: l10n.loadingProjectSessions,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ConversationSkeleton extends StatelessWidget {
  const _ConversationSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => AppSkeleton(
    label: label,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0) const SizedBox(height: 28),
            if (index.isOdd)
              const Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: .48,
                  child: AppSkeletonBox(height: 16),
                ),
              )
            else
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FractionallySizedBox(
                    widthFactor: .82,
                    child: AppSkeletonBox(height: 16),
                  ),
                  SizedBox(height: 10),
                  AppSkeletonBox(height: 16),
                  SizedBox(height: 10),
                  FractionallySizedBox(
                    widthFactor: .55,
                    child: AppSkeletonBox(height: 16),
                  ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
}

class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({
    required this.text,
    this.emphasized = false,
    this.compact = false,
    this.softLineBreak = false,
    this.style,
    super.key,
  });
  final String text;
  final bool emphasized;
  final bool compact;
  final bool softLineBreak;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final body =
        style ??
        (compact
                ? ConversationCardTypography.body
                : emphasized
                ? ConversationStyle.userMessage
                : ConversationStyle.message)
            .copyWith(
              color: colors.onSurface,
              fontWeight: emphasized || !compact
                  ? FontWeight.w600
                  : FontWeight.w400,
            );
    final heading = compact
        ? ConversationCardTypography.title.copyWith(color: body.color)
        : body.copyWith(fontSize: 20, fontWeight: FontWeight.w600);
    final markdown = MarkdownBody(
      data: text,
      selectable: false,
      softLineBreak: softLineBreak,
      builders: {'pre': _WrappedPromptBuilder(style: body)},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        tableBody: body,
        blockquote: body,
        listBullet: body,
        blockSpacing: 12,
        codeblockDecoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(8),
        ),
        h1: heading,
        h2: heading,
        h3: heading,
        h4: heading,
        h5: heading,
        h6: heading,
      ),
      onTapLink: (_, href, __) {
        if (href != null) _openUrl(href);
      },
    );
    // Join the reply's scroll-aware selection; standalone previews still
    // share one selection across their paragraphs, lists and fenced prompts.
    return SelectionContainer.maybeOf(context) == null
        ? SelectionArea(child: markdown)
        : markdown;
  }
}

/// Agent prompts in fenced blocks wrap within the card's reading viewport.
class _WrappedPromptBuilder extends MarkdownElementBuilder {
  _WrappedPromptBuilder({this.style});

  final TextStyle? style;

  @override
  Widget visitText(md.Text text, TextStyle? preferredStyle) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text.text.replaceFirst(RegExp(r'\n$'), ''),
        style: style ?? const TextStyle(fontSize: 14, height: 1.6),
      ),
    );
  }
}

/// Only displays the real run state; backend stages are not inferred locally.
class _ConversationProgressHeader extends StatelessWidget {
  const _ConversationProgressHeader({
    required this.label,
    required this.running,
    this.expanded = false,
    this.onToggle,
  });
  final String label;
  final bool running;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: running,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppSvgIcon.asset('chat_thinking', size: 25),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: ConversationStyle.progressTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        if (onToggle != null)
          SizedBox.square(
            dimension: 25,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: expanded
                  ? AppLocalizations.of(context)!.chatCollapseProgress
                  : AppLocalizations.of(context)!.chatExpandProgress,
              onPressed: onToggle,
              icon: Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                size: 20,
              ),
            ),
          ),
      ],
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
    this.thumbnailSize,
    this.result = false,
    super.key,
  });
  final String id;
  final SessionRepository repository;
  final double? thumbnailSize;
  final bool result;
  @override
  State<ConversationMediaView> createState() => _ConversationMediaViewState();
}

class _ConversationMediaViewState extends State<ConversationMediaView> {
  late Future<ConversationMedia> _media = _load();

  Future<ConversationMedia> _load() async {
    final id = widget.id;
    final repository = widget.repository;
    try {
      return await repository.media(id);
    } catch (error) {
      if (mounted &&
          widget.id == id &&
          identical(widget.repository, repository)) {
        AppToast.error(
          context,
          conversationErrorText(error, AppLocalizations.of(context)!),
        );
      }
      rethrow;
    }
  }

  @override
  void didUpdateWidget(ConversationMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.repository != widget.repository) {
      _media = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ConversationMedia>(
    future: _media,
    builder: (context, snapshot) {
      final l10n = AppLocalizations.of(context)!;
      if (snapshot.hasError) {
        return _MediaFrame(
          result: widget.result,
          thumbnailSize: widget.thumbnailSize,
          child: Center(
            child: Tooltip(
              message: l10n.chatUnavailable,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        );
      }
      final media = snapshot.data;
      if (media == null) {
        return _MediaFrame(
          result: widget.result,
          thumbnailSize: widget.thumbnailSize,
          child: const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (media.kind == 'image') {
        final preview = Semantics(
          button: true,
          label: l10n.chatPreviewImage,
          child: GestureDetector(
            onTap: () => AppImagePreview.show(
              context: context,
              image: AppImageCache.provider(media.url),
              heroTag: 'conversation-media-${media.id}',
            ),
            child: _MediaFrame(
              result: widget.result,
              thumbnailSize: widget.thumbnailSize,
              child: AppNetworkImage(
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
                  child: Tooltip(
                    message: l10n.chatUnavailable,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        );
        return preview;
      }
      if (media.kind == 'video' && widget.thumbnailSize == null) {
        return _MediaFrame(
          result: true,
          child: ColoredBox(
            color: Colors.black,
            child: AppVideoPlayer(
              url: Uri.parse(media.url),
              aspectRatio: 16 / 9,
              controlsKeyPrefix: 'conversation-video-${media.id}',
              onFullscreen: (url) =>
                  AppVideoPreview.show(context: context, url: url),
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
  const _MediaFrame({
    required this.child,
    this.thumbnailSize,
    this.result = false,
  });
  final Widget child;
  final double? thumbnailSize;
  final bool result;

  @override
  Widget build(BuildContext context) {
    if (thumbnailSize case final size?) {
      return SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: child,
          ),
        ),
      );
    }
    if (result) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: child,
          ),
        ),
      );
    }
    return ConstrainedBox(
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
    );
  }
}

class _ConversationTopics extends StatefulWidget {
  const _ConversationTopics({
    required this.topics,
    required this.controller,
    required this.message,
    super.key,
  });
  final List<ConversationBlock> topics;
  final ConversationController controller;
  final ConversationMessage message;

  @override
  State<_ConversationTopics> createState() => _ConversationTopicsState();
}

class _ConversationTopicsState extends State<_ConversationTopics>
    with AutomaticKeepAliveClientMixin {
  int _index = 0;
  bool _selected = false;
  bool _refreshed = false;
  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(_ConversationTopics oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedId = oldWidget.topics[_index].referenceId;
    final wasUnique =
        selectedId.isNotEmpty &&
        oldWidget.topics
                .where((topic) => topic.referenceId == selectedId)
                .length ==
            1;
    final matches = [
      for (final (index, topic) in widget.topics.indexed)
        if (topic.referenceId == selectedId) index,
    ];
    // Older snapshots can omit IDs or repeat one ID for several candidates.
    _index = wasUnique && matches.length == 1
        ? matches.single
        : _index.clamp(0, widget.topics.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final topic = widget.topics[_index];
    final controller = widget.controller;
    final locked =
        topic.kind != 'topic' ||
        _selected ||
        _refreshed ||
        controller.snapshot?.topicLocked(widget.message, topic) != false;
    final disabled =
        controller.pending || controller.running || controller.loading;
    final selected =
        topic.kind == 'topic' &&
        (_selected ||
            controller.snapshot?.selectedTopicId(widget.message, topic) ==
                    topic.referenceId &&
                topic.referenceId.isNotEmpty);
    return ConversationObjectView(
      key: ValueKey(
        topic.referenceId.isNotEmpty &&
                widget.topics
                        .where((item) => item.referenceId == topic.referenceId)
                        .length ==
                    1
            ? topic.referenceId
            : _index,
      ),
      block: topic,
      controller: widget.controller,
      headerTrailing: widget.topics.length > 1
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.roleStoryPosition(_index + 1, widget.topics.length),
                  key: const Key('conversation-topic-position'),
                  style: ConversationCardTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                _arrow(context, l10n.rolePreviousStory, -1),
                _arrow(context, l10n.roleNextStory, 1),
              ],
            )
          : null,
      footer: locked && !selected
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!locked && topic.referenceId.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      IconButton(
                        key: const Key('conversation-topic-refresh'),
                        tooltip: l10n.roleRefreshStories,
                        onPressed: disabled
                            ? null
                            : () async {
                                if (await controller.topicAction(
                                      widget.message,
                                      topic,
                                      refreshTopics: true,
                                    ) &&
                                    mounted) {
                                  setState(() => _refreshed = true);
                                }
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                      FilledButton(
                        key: const Key('conversation-topic-select'),
                        onPressed: disabled
                            ? null
                            : () async {
                                if (await controller.topicAction(
                                      widget.message,
                                      topic,
                                    ) &&
                                    mounted) {
                                  setState(() => _selected = true);
                                }
                              },
                        child: Text(l10n.roleChooseStory),
                      ),
                    ],
                  ),
                if (selected) Text(l10n.chatTopicSelected),
              ],
            ),
    );
  }

  Widget _arrow(BuildContext context, String tooltip, int direction) {
    final target = _index + direction;
    final enabled = target >= 0 && target < widget.topics.length;
    return SizedBox(
      width: 24,
      height: 32,
      child: IconButton(
        key: Key(
          direction < 0
              ? 'conversation-topic-previous'
              : 'conversation-topic-next',
        ),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: enabled ? () => setState(() => _index = target) : null,
        icon: RotatedBox(
          quarterTurns: direction < 0 ? 2 : 0,
          child: SizedBox(
            width: 6,
            height: 12,
            child: AppSvgIcon.asset(
              'role_guide_chevron',
              color: enabled
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).disabledColor,
            ),
          ),
        ),
      ),
    );
  }
}

class ConversationObjectView extends StatefulWidget {
  const ConversationObjectView({
    required this.block,
    required this.controller,
    this.framed = true,
    this.mediaSpacing = 0,
    this.headerTrailing,
    this.footer,
    this.onRevise,
    super.key,
  });
  final ConversationBlock block;
  final ConversationController controller;
  final bool framed;
  final double mediaSpacing;
  final Widget? headerTrailing;
  final Widget? footer;
  final ValueChanged<ConversationBlock>? onRevise;
  @override
  State<ConversationObjectView> createState() => _ConversationObjectViewState();
}

class _ConversationObjectViewState extends State<ConversationObjectView>
    with AutomaticKeepAliveClientMixin {
  Timer? _expiryTimer;
  bool _expanded = false;
  bool _progressExpanded = true;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _progressExpanded = widget.block.status != 'completed';
    if (widget.block.expiresAt != null) {
      _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(ConversationObjectView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final block = widget.block;
    if (block.data['runId'] != oldWidget.block.data['runId'] ||
        block.data['attempt'] != oldWidget.block.data['attempt']) {
      _progressExpanded = block.status != 'completed';
    } else if (block.status == 'completed' &&
        oldWidget.block.status != 'completed') {
      _progressExpanded = false;
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final block = widget.block;
    if (block.kind == 'role') return ConversationRoleCard(block: block);
    if (block.kind == 'topic' && block.action == 'selected') {
      return ConversationSelectedTopicCard(
        key: ValueKey((block.referenceId, block.scopeId)),
        block: block,
        framed: widget.framed,
      );
    }
    final controller = widget.controller;
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    if (block.kind == 'generation_decision') {
      return Text(
        block.action == 'confirm'
            ? l10n.chatGenerationConfirmed
            : l10n.chatGenerationCanceled,
      );
    }
    if (block.kind == 'plan' && block.objectKind == 'generation') {
      return ConversationGenerationCard(
        key: ValueKey(block.id),
        block: block,
        controller: controller,
      );
    }
    if (block.kind == 'task') {
      return ConversationTaskCard(
        key: ValueKey(block.id),
        block: block,
        controller: controller,
      );
    }
    final statusLabel = block.action == 'selected'
        ? l10n.chatTopicSelected
        : _statusLabel(block.status, l10n);
    final details = block.details;
    final disabled =
        controller.pending || controller.running || controller.loading;
    if (block.kind == 'progress') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          _ConversationProgressHeader(
            label: conversationProgressTitle(block, l10n),
            running: _progressRunning(block),
            expanded: _progressExpanded,
            onToggle: () =>
                setState(() => _progressExpanded = !_progressExpanded),
          ),
          if (_progressExpanded)
            Container(
              key: const Key('conversation-progress-details'),
              width: 238,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: ConversationStyle.cardColor(context),
                borderRadius: BorderRadius.circular(
                  ConversationStyle.cardRadius,
                ),
              ),
              child: ConversationCardContent(
                key: ValueKey((
                  'progress-content',
                  block.data['runId'] ?? block.id,
                  block.data['attempt'] ?? 1,
                )),
                storageId:
                    'progress:${block.data['runId'] ?? block.id}:${block.data['attempt'] ?? 1}',
                maxViewportHeight: 360,
                followTail: true,
                child: ConversationProgressSteps(
                  steps: block.progressDetails,
                  showStatusLabels: false,
                  singleLine: true,
                ),
              ),
            ),
        ],
      );
    }
    if (block.kind == 'question' && block.status == 'pending') {
      return _ConversationQuestion(
        key: ValueKey('${block.id}:${block.revision}'),
        block: block,
        controller: controller,
      );
    }
    return ConversationCard(
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
                    style: ConversationCardTypography.caption.copyWith(
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
          if (block.title.isNotEmpty ||
              block.isStoryboard ||
              block.avatar != null ||
              widget.headerTrailing != null)
            Row(
              crossAxisAlignment: widget.headerTrailing == null
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (block.avatar != null || details.isNotEmpty) ...[
                  SizedBox.square(
                    dimension: 70,
                    child: block.avatar == null
                        ? const AppSvgIcon.asset('chat_role_draft', size: 70)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AppNetworkImage(
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
                    block.isStoryboard
                        ? l10n.roleStoryboardContent
                        : block.title,
                    style: ConversationCardTypography.title,
                  ),
                ),
                if (widget.headerTrailing != null) ...[
                  const SizedBox(width: 8),
                  widget.headerTrailing!,
                ],
                if (block.editableContent && widget.onRevise != null)
                  IconButton(
                    tooltip: l10n.chatReviseContent,
                    onPressed: disabled ? null : () => widget.onRevise!(block),
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
          ConversationCardContent(
            storageId: 'object:${block.kind}:${block.id}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (block.body.isNotEmpty &&
                    !details.any((detail) => detail.$2 == block.body))
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: block.isStoryboard
                        ? RoleStoryboardBody(
                            body: block.body,
                            style: ConversationCardTypography.body,
                          )
                        : MarkdownMessage(text: block.body, compact: true),
                  ),
                if (block.kind == 'topic' &&
                    block.hook.isNotEmpty &&
                    !block.body.contains(block.hook))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: MarkdownMessage(text: block.hook, compact: true),
                  ),
                if (block.kind == 'plan')
                  if (block.previewRole case final role?)
                    ConversationRoleCard(block: role, framed: false),
                for (final (label, before, after) in block.profileChanges) ...[
                  _ConversationDetail(
                    label:
                        '${_detailLabel(label, l10n)} · ${l10n.chatBeforeChange}',
                    value: before.isEmpty ? l10n.chatUnavailable : before,
                  ),
                  _ConversationDetail(
                    label:
                        '${_detailLabel(label, l10n)} · ${l10n.chatAfterChange}',
                    value: after,
                  ),
                ],
                // Keep long profiles compact in the timeline; expansion retains the
                // same object identity while SSE updates refresh its contents.
                for (final (label, value)
                    in _expanded ? details : details.take(3))
                  _ConversationDetail(
                    label: _detailLabel(label, l10n),
                    value: value,
                  ),
                for (final prompt in block.planPrompts)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MarkdownMessage(text: prompt, compact: true),
                  ),
                for (final (label, value) in block.answeredFields)
                  _ConversationDetail(label: label, value: value),
              ],
            ),
          ),
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
          for (final result in block.results)
            ConversationObjectView(
              key: ValueKey(result.id),
              block: result,
              controller: controller,
              framed: false,
            ),
          for (final id in block.mediaIds)
            Padding(
              padding: EdgeInsets.only(top: widget.mediaSpacing),
              child: ConversationMediaView(
                id: id,
                repository: controller.repository,
              ),
            ),
          if (block.estimatedPoints != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                l10n.chatEstimatedPoints(block.estimatedPoints!.toString()),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          if (block.kind == 'plan' &&
              block.confirmationAvailable &&
              block.allowedActions.contains('confirm') &&
              block.estimatedPoints != null)
            const GenerationCreditNotice(),
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
                                    : '${l10n.chatEstimatedPoints(block.estimatedPoints!.toString())}\n\n${l10n.generationCreditNotice}',
                                cancelLabel: l10n.cancel,
                                confirmLabel: l10n.confirm,
                              );
                              if (confirmed == true && context.mounted) {
                                await controller.confirm(block, 'confirm');
                              }
                            },
                      child: Text(switch (block.objectKind) {
                        'role_creation' => l10n.chatCompleteRole,
                        'profile_update' => l10n.chatConfirmProfileUpdate,
                        'publish' => l10n.chatPublishRole,
                        _ => l10n.confirm,
                      }),
                    ),
                ],
              ),
            ),
          if (widget.footer != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: widget.footer,
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
          style: ConversationCardTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(value, style: ConversationCardTypography.body),
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

String _statusLabel(String status, AppLocalizations l10n) =>
    conversationStatusLabel(status, l10n);

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

class _ConversationQuestionState extends State<_ConversationQuestion>
    with AutomaticKeepAliveClientMixin {
  final _answers = <String, Object?>{};
  final _custom = <String, String>{};
  final _customControllers = <String, TextEditingController>{};
  bool _submitted = false;
  @override
  bool get wantKeepAlive => true;
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
    super.build(context);
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
    return ConversationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.block.title, style: ConversationCardTypography.title),
          for (final field in widget.block.fields) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 6),
              child: Text(
                field.label,
                style: ConversationCardTypography.body.copyWith(
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
                  title: Text(option, style: ConversationCardTypography.body),
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
                        title: Text(
                          option,
                          style: ConversationCardTypography.body,
                        ),
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
