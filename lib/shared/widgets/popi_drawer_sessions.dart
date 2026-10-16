import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../features/session/domain/conversation_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/session_provider.dart';
import '../providers/user_provider.dart';
import 'app_dialog.dart';
import 'app_menu.dart';
import 'app_skeleton.dart';
import 'app_svg_icon.dart';
import 'app_toast.dart';

/// Flat conversation history shared with the active Agent conversation.
class PopiDrawerSessions extends ConsumerStatefulWidget {
  const PopiDrawerSessions({
    required this.onOpenConversation,
    required this.header,
    this.activeSessionId,
    super.key,
  });

  final ValueChanged<ConversationSession> onOpenConversation;
  final Widget header;
  final String? activeSessionId;

  @override
  ConsumerState<PopiDrawerSessions> createState() => _PopiDrawerSessionsState();
}

class _PopiDrawerSessionsState extends ConsumerState<PopiDrawerSessions> {
  bool _loadMoreFailed = false;

  Future<void> _refresh() async {
    _loadMoreFailed = false;
    final userId = ref.read(userProvider)?.id;
    try {
      await ref.read(sessionsProvider.notifier).refresh();
    } catch (_) {
      if (mounted && ref.read(userProvider)?.id == userId) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.chatHistoryLoadFailed,
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadMoreFailed) return;
    final userId = ref.read(userProvider)?.id;
    try {
      await ref.read(sessionsProvider.notifier).loadMore();
    } catch (_) {
      if (!mounted || ref.read(userProvider)?.id != userId) return;
      _loadMoreFailed = true;
      AppToast.error(
        context,
        AppLocalizations.of(context)!.chatHistoryLoadFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(sessionsProvider);
    final controller = ref.read(sessionsProvider.notifier);
    ref.listen(userProvider.select((user) => user?.id), (_, _) {
      _loadMoreFailed = false;
    });
    // 切换账号时 AsyncValue 可能保留上一次的数据，加载期间不展示旧账号历史。
    final sessions = controller.initialLoading || history.hasError
        ? const <ConversationSession>[]
        : history.valueOrNull ?? const <ConversationSession>[];
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final mutedColor = Theme.of(context).brightness == Brightness.dark
        ? colors.onSurfaceVariant
        : AppColors.textTertiary;
    final sessionIndices = {
      for (var index = 0; index < sessions.length; index++)
        sessions[index].id: index,
    };
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _loadMoreFailed = false;
        }
        final movingDown =
            notification is ScrollUpdateNotification &&
                (notification.scrollDelta ?? 0) > 0 ||
            notification is OverscrollNotification &&
                notification.overscroll > 0;
        if (movingDown && notification.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: const Key('drawer-session-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: widget.header),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.drawerSessions,
                      style: TextStyle(fontSize: 14, color: mutedColor),
                    ),
                  ),
                ),
              ),
            ),
            if (sessions.isNotEmpty)
              SliverFixedExtentList(
                itemExtent: 40,
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final session = sessions[index];
                    return _SessionItem(
                      key: ValueKey(session.id),
                      session: session,
                      selected: session.id == widget.activeSessionId,
                      onTap: () => widget.onOpenConversation(session),
                    );
                  },
                  childCount: sessions.length,
                  findChildIndexCallback: (key) => key is ValueKey<String>
                      ? sessionIndices[key.value]
                      : null,
                ),
              )
            else if (controller.initialLoading)
              const SliverToBoxAdapter(
                child: _SessionSkeleton(key: Key('drawer-sessions-skeleton')),
              )
            else if (history.hasError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.chatHistoryLoadFailed)),
                      IconButton(
                        tooltip: l10n.retry,
                        onPressed: () => ref.invalidate(sessionsProvider),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.noHistory,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            if (sessions.isNotEmpty && controller.hasMore)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: controller.loadingMore
                      ? AppSkeleton(
                          key: const Key('drawer-sessions-more-skeleton'),
                          label: l10n.loadingProjectSessions,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 13,
                            ),
                            child: AppSkeletonBox(height: 14),
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionSkeleton extends StatelessWidget {
  const _SessionSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppSkeleton(
    label: AppLocalizations.of(context)!.loadingProjectSessions,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 5; index++)
          SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  const AppSkeletonBox(width: 30, height: 30, radius: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: index.isEven ? .65 : .45,
                        child: const AppSkeletonBox(height: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _SessionItem extends ConsumerWidget {
  const _SessionItem({
    required this.session,
    required this.onTap,
    required this.selected,
    super.key,
  });

  final ConversationSession session;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final pinned = session.pinnedAt != null;
    const bubbleIcons = [
      'drawer_conversation_pink',
      'drawer_conversation_blue',
      'drawer_conversation_purple',
    ];
    // Keep the color stable when conversations are renamed or reordered.
    final bubbleIndex =
        session.id.codeUnits.fold<int>(0, (total, unit) => total + unit) %
        bubbleIcons.length;
    Widget menuIcon(String name, double size) =>
        AppSvgIcon.asset(name, size: size, color: colors.onSurface);
    Widget label() => Row(
      children: [
        AppSvgIcon.asset(
          bubbleIcons[bubbleIndex],
          key: Key('drawer-session-avatar-${session.id}'),
          size: 30,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: selected ? colors.primary : colors.onSurface,
            ),
          ),
        ),
        if (pinned) ...[
          const SizedBox(width: 8),
          AppSvgIcon.asset(
            'menu_pin',
            size: 15,
            color: colors.onSurfaceVariant,
          ),
        ],
      ],
    );
    return AppContextMenu(
      enabled: userId != null,
      label: l10n.sessionItemOptions(session.title),
      preview: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: label(),
      ),
      entries: [
        AppMenuItem(
          label: pinned ? l10n.unpinSession : l10n.pinSession,
          icon: menuIcon('menu_pin', 17),
          onSelected: () async {
            if (ref.read(userProvider)?.id != userId) return;
            try {
              await ref
                  .read(sessionsProvider.notifier)
                  .setPinned(session.id, !pinned);
            } catch (_) {
              if (context.mounted && ref.read(userProvider)?.id == userId) {
                AppToast.error(context, l10n.chatRequestFailed);
              }
            }
          },
        ),
        AppMenuItem(
          label: l10n.renameProjectItem,
          icon: menuIcon('menu_rename', 17),
          onSelected: () {
            if (ref.read(userProvider)?.id != userId) return;
            AppDialog.show<void>(
              context: context,
              builder: (_) =>
                  _RenameSessionDialog(session: session, userId: userId!),
            );
          },
        ),
        const AppMenuDivider(),
        AppMenuItem(
          label: l10n.delete,
          icon: AppSvgIcon.asset(
            'menu_delete',
            size: 18,
            color: const Color(0xFFD63D43),
          ),
          destructive: true,
          foregroundColor: const Color(0xFFD63D43),
          onSelected: () async {
            if (ref.read(userProvider)?.id != userId) return;
            final confirmed = await AppDialog.confirm(
              context: context,
              title: l10n.delete,
              description: l10n.deleteSessionConfirm(session.title),
              cancelLabel: l10n.cancel,
              confirmLabel: l10n.delete,
              confirmKey: const Key('session-delete-confirm'),
              destructive: true,
            );
            if (!context.mounted ||
                confirmed != true ||
                ref.read(userProvider)?.id != userId) {
              return;
            }
            try {
              await ref.read(sessionsProvider.notifier).delete(session.id);
              if (context.mounted && ref.read(userProvider)?.id == userId) {
                AppToast.success(context, l10n.projectItemDeleted);
              }
            } catch (_) {
              if (context.mounted && ref.read(userProvider)?.id == userId) {
                AppToast.error(context, l10n.chatRequestFailed);
              }
            }
          },
        ),
      ],
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected
              ? colors.primary.withValues(alpha: .05)
              : colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: InkWell(
            key: Key('drawer-session-${session.id}'),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? colors.primary.withValues(alpha: .12)
                  : null,
            ),
            onTap: onTap,
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: label(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameSessionDialog extends ConsumerStatefulWidget {
  const _RenameSessionDialog({required this.session, required this.userId});
  final ConversationSession session;
  final String userId;

  @override
  ConsumerState<_RenameSessionDialog> createState() =>
      _RenameSessionDialogState();
}

class _RenameSessionDialogState extends ConsumerState<_RenameSessionDialog> {
  late final _name = TextEditingController(text: widget.session.title);
  bool _closing = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty ||
        _name.text.trim().runes.length > 200 ||
        ref.read(userProvider)?.id != widget.userId) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionsProvider.notifier)
          .rename(widget.session.id, _name.text);
      if (!mounted || ref.read(userProvider)?.id != widget.userId) return;
      AppToast.success(
        context,
        AppLocalizations.of(context)!.projectItemRenamed,
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.chatRequestFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    if (ref.watch(userProvider.select((user) => user?.id)) != widget.userId &&
        !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
    final valid =
        !_closing &&
        !_saving &&
        _name.text.trim().isNotEmpty &&
        _name.text.trim().runes.length <= 200;
    return AppDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.renameProjectItem,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 25),
          TextField(
            key: const Key('session-rename-input'),
            controller: _name,
            autofocus: true,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.projectItemName,
              counterText: '',
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onSurface,
                      backgroundColor: colors.primary.withValues(alpha: .05),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    key: const Key('session-rename-confirm'),
                    onPressed: valid ? _submit : null,
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: Text(l10n.confirm),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
