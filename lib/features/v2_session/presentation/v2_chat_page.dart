import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../../assets/domain/library_work.dart';
import '../../session/presentation/widgets/conversation_timeline.dart'
    show MarkdownMessage;
import '../../session/presentation/widgets/popi_message_composer.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_models.dart';
import '../../v2_assets/presentation/v2_assets_page.dart';
import 'v2_chat_controller.dart';
import 'v2_settings_page.dart';
import 'widgets/v2_image_stack.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';

class V2ChatPage extends StatefulWidget {
  const V2ChatPage({
    required this.repository,
    required this.sessionId,
    super.key,
  });
  final V2Repository repository;
  final String sessionId;
  @override
  State<V2ChatPage> createState() => _V2ChatPageState();
}

class _V2ChatPageState extends State<V2ChatPage> {
  late final _conversation = V2ChatController(
    widget.repository,
    widget.sessionId,
  );
  final _composer = PopiMessageComposerController();
  final _scroll = ScrollController();
  final List<String> _attachments = [];
  final Map<String, int> _imagePages = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _conversation.session.unread > 0) {
        v2Perform(
          context,
          () => widget.repository.updateSession(
            widget.sessionId,
            (s) => s.copyWith(unread: 0),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _conversation.dispose();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _settings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => V2SettingsPage(
        repository: widget.repository,
        sessionId: widget.sessionId,
      ),
    ),
  );

  Future<void> _send([String? prompt]) async {
    final input = prompt ?? _composer.markdown;
    if (_conversation.sending) return;
    final l = AppLocalizations.of(context)!;
    final sent = await v2Perform(context, () async {
      final ok = await _conversation.send(input, List.of(_attachments), l);
      if (mounted && ok) {
        await _composer.setText('');
        setState(_attachments.clear);
      }
    });
    if (sent && mounted && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _attach() => V2Sheet.show<void>(
    context: context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.demoAttachments,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: V2AssetsView(
              repository: widget.repository,
              onSelect: (asset) {
                if (!_attachments.contains(asset.id)) {
                  setState(() => _attachments.add(asset.id));
                }
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _message(BuildContext context, V2Message message) {
    final media = message.assetIds
        .map(
          (id) => widget.repository.assets.where((a) => a.id == id).firstOrNull,
        )
        .whereType<V2Asset>()
        .toList();
    final batch =
        media.length > 1 && media.every((a) => a.kind == V2AssetKind.image);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.user
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.user) ...[
            V2Avatar(
              members: _conversation.session.members.take(1).toList(),
              memberAvatars: _conversation.session.memberAvatars,
              memberColors: _conversation.session.memberColors,
              size: 32,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .72,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.text.isNotEmpty)
                    Semantics(
                      liveRegion: message.id == 'thinking',
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: message.user ? v2Tint : v2Surface(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: MarkdownMessage(
                          text: message.text,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    if (batch)
                      V2ImageStack(
                        key: ValueKey('demo-image-stack-${message.id}'),
                        images: media,
                        messageId: message.id,
                        initialIndex: _imagePages[message.id] ?? 0,
                        onChanged: (index) => _imagePages[message.id] = index,
                      )
                    else
                      for (final asset in media)
                        SizedBox(
                          width: 245,
                          height:
                              asset.kind == V2AssetKind.audio ||
                                  asset.kind == V2AssetKind.script
                              ? 327
                              : 310,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: V2AssetCard(
                              asset: asset,
                              onTap: () => asset.kind == V2AssetKind.image
                                  ? AppImagePreview.show(
                                      context: context,
                                      image: AssetImage(asset.cover),
                                      heroTag:
                                          'message-${message.id}-${asset.id}',
                                      label: asset.title,
                                    )
                                  : openV2Asset(context, asset),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final topContentPadding =
        MediaQuery.paddingOf(context).top + kToolbarHeight;
    return ListenableBuilder(
      listenable: _conversation,
      builder: (context, _) {
        final s = _conversation.session;
        return V2Scaffold(
          extendBodyBehindAppBar: true,
          title: TextButton(
            onPressed: _settings,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: v2Surface(context),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                V2Avatar(
                  members: s.members,
                  size: 34,
                  memberAvatars: s.memberAvatars,
                  memberColors: s.memberColors,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    s.members.length == 1
                        ? v2MemberName(l, s.members.first)
                        : '${l.demoPopi} · ${s.members.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              key: const Key('demo-settings'),
              tooltip: l.demoSettings,
              onPressed: _settings,
              icon: const V2Icon('profile', size: 24),
            ),
          ],
          child: Column(
            children: [
              Expanded(
                child: s.messages.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(top: topContentPadding),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/demo_welcome.png',
                                width: 150,
                                height: 150,
                                cacheWidth: 450,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                l.demoGreeting,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l.demoGreetingDetail,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Chat(
                        currentUserId: 'demo-user',
                        resolveUser: (id) async =>
                            chat.User(id: id, name: l.demoPopi),
                        chatController: _conversation.chatController,
                        backgroundColor: Colors.transparent,
                        builders: chat.Builders(
                          composerBuilder: (_) => const SizedBox.shrink(),
                          chatAnimatedListBuilder: (context, itemBuilder) =>
                              ChatAnimatedList(
                                scrollController: _scroll,
                                initialScrollToEndMode:
                                    InitialScrollToEndMode.none,
                                handleSafeArea: false,
                                topPadding: topContentPadding + 10,
                                bottomPadding: 10,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemBuilder: itemBuilder,
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
                              }) => _message(
                                context,
                                message.metadata!['demo'] as V2Message,
                              ),
                        ),
                      ),
              ),
              PopiMessageComposer(
                conversationMode: true,
                sessionLayout: true,
                bottomPadding: 4,
                controller: _composer,
                selectedImages: const [],
                selectedAssets: [
                  for (final id in _attachments)
                    for (final asset in widget.repository.assets)
                      if (asset.id == id)
                        LibraryWork(
                          id: asset.id,
                          previewUrl: asset.cover,
                          isVideo: asset.kind == V2AssetKind.video,
                          createdAt: null,
                        ),
                ],
                onAttachment: () {
                  if (!_conversation.sending) _attach();
                },
                onRemoveImage: (_) {},
                onRemoveAsset: (index) =>
                    setState(() => _attachments.removeAt(index)),
                onHeightChanged: (_) {},
                onSubmitted: _send,
                sending: _conversation.sending,
              ),
            ],
          ),
        );
      },
    );
  }
}
