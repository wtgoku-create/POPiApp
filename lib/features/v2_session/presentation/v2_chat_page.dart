import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../../../shared/widgets/app_glass_app_bar.dart';
import '../../../shared/widgets/app_page_safe_area.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../assets/domain/library_work.dart';
import '../../session/presentation/widgets/conversation_timeline.dart'
    show MarkdownMessage;
import '../../session/presentation/widgets/popi_message_composer.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_models.dart';
import '../../v2_shared/presentation/widgets/v2_frosted_backdrop.dart';
import '../../v2_assets/presentation/v2_assets_page.dart';
import 'v2_chat_controller.dart';
import 'v2_settings_page.dart';
import 'widgets/v2_image_stack.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';

class _RoleOnboardingCard extends StatelessWidget {
  const _RoleOnboardingCard({required this.onLink, required this.onCreate});

  final VoidCallback onLink;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ClipRRect(
      key: const Key('v2-role-onboarding'),
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(20),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.surface),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.v2AddCreativeRole,
                style: const TextStyle(fontSize: 18, height: 26 / 18),
              ),
              const SizedBox(height: 6),
              Text(
                l.v2AddCreativeRoleDescription,
                style: const TextStyle(
                  fontSize: 14,
                  height: 22 / 14,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 42,
                child: FilledButton(
                  key: const Key('v2-link-role'),
                  onPressed: onLink,
                  child: Text(
                    l.demoLinkedRoles,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: TextButton.icon(
                  key: const Key('v2-create-diy-role'),
                  style: TextButton.styleFrom(
                    backgroundColor: v2Tint,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onCreate,
                  icon: const V2Icon('plus', size: 20),
                  label: Text(
                    l.v2CreateDiyRole,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  double _composerHeight = 0;
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

  void _handleComposerHeight(double height) {
    if (!mounted || (height - _composerHeight).abs() < .5) return;
    setState(() => _composerHeight = height);
  }

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
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: AppPageSafeArea.horizontalPaddingOf(
          context,
        ).copyWith(bottom: 12),
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
                  maxWidth: constraints.maxWidth * .72,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final safeArea = MediaQuery.paddingOf(context);
    final topContentPadding =
        safeArea.top + kToolbarHeight + AppGlassHeader.topSpacing;
    return ListenableBuilder(
      listenable: _conversation,
      builder: (context, _) {
        if (!widget.repository.sessions.any((s) => s.id == widget.sessionId)) {
          return const SizedBox.shrink();
        }
        final s = _conversation.session;
        return V2Scaffold(
          backgroundColor:
              s.messages.isEmpty &&
                  Theme.of(context).brightness == Brightness.light
              ? v2Background
              : null,
          extendBodyBehindAppBar: true,
          bottomSafeArea: safeArea.horizontal == 0,
          title: TextButton(
            onPressed: _settings,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
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
                        ? s.memberNames[s.members.first] ??
                              v2MemberName(l, s.members.first)
                        : '${l.demoPopi} · ${s.members.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
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
              icon: AppSvgIcon.asset(
                'v2_chat_settings',
                size: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                bottom: s.messages.isEmpty ? _composerHeight : 0,
                child: s.messages.isEmpty
                    ? CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: AppPageSafeArea.horizontalPaddingOf(
                              context,
                            ).copyWith(top: topContentPadding, bottom: 20),
                            sliver: SliverFillRemaining(
                              hasScrollBody: false,
                              child: Align(
                                alignment: const Alignment(0, .2),
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
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l.demoGreetingDetail,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    if (s.roles.isEmpty) ...[
                                      const SizedBox(height: 20),
                                      _RoleOnboardingCard(
                                        onLink: () => showV2RolesSheet(
                                          context: context,
                                          repository: widget.repository,
                                          session: s,
                                        ),
                                        onCreate: () => showV2RolesSheet(
                                          context: context,
                                          repository: widget.repository,
                                          session: s,
                                          createRole: true,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Chat(
                        currentUserId: 'demo-user',
                        resolveUser: (id) async =>
                            chat.User(id: id, name: l.demoPopi),
                        chatController: _conversation.chatController,
                        backgroundColor: Colors.transparent,
                        builders: chat.Builders(
                          composerBuilder: (_) => const SizedBox.shrink(),
                          scrollToBottomBuilder:
                              (context, animation, onPressed) => ScrollToBottom(
                                key: const Key('v2-chat-scroll-to-bottom'),
                                animation: animation,
                                onPressed: onPressed,
                                bottom: _composerHeight + 20,
                                useComposerHeightForBottomOffset: false,
                                handleSafeArea: false,
                              ),
                          chatAnimatedListBuilder: (context, itemBuilder) =>
                              ChatAnimatedList(
                                scrollController: _scroll,
                                initialScrollToEndMode:
                                    InitialScrollToEndMode.none,
                                handleSafeArea: false,
                                topPadding: topContentPadding + 10,
                                bottomPadding: _composerHeight + 10,
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(
                      top: -16,
                      child: IgnorePointer(
                        child: V2FrostedBackdrop(
                          key: Key('v2-chat-composer-backdrop'),
                          sigma: 8,
                          fadeExtent: 16,
                        ),
                      ),
                    ),
                    PopiMessageComposer(
                      conversationMode: true,
                      sessionLayout: true,
                      bottomPadding: 0,
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
                      onHeightChanged: _handleComposerHeight,
                      onSubmitted: _send,
                      sending: _conversation.sending,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
