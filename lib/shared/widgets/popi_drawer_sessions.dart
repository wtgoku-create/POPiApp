import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../features/session/domain/conversation_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/session_provider.dart';
import '../providers/user_provider.dart';
import 'app_dialog.dart';
import 'app_menu.dart';
import 'app_svg_icon.dart';
import 'app_toast.dart';

/// Flat conversation history backed by the temporary session repository.
class PopiDrawerSessions extends ConsumerWidget {
  const PopiDrawerSessions({required this.onOpenConversation, super.key});

  final ValueChanged<ConversationSession> onOpenConversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.drawerSessions,
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('drawer-session-list'),
            padding: EdgeInsets.zero,
            children: [
              if (sessions.isEmpty)
                Padding(
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
              for (final session in sessions)
                _SessionItem(
                  key: ValueKey(session.id),
                  session: session,
                  onTap: () => onOpenConversation(session),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionItem extends ConsumerWidget {
  const _SessionItem({required this.session, required this.onTap, super.key});

  final ConversationSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final pinned = session.pinnedAt != null;
    Widget menuIcon(String name, double size) =>
        AppSvgIcon.asset(name, size: size, color: colors.onSurface);
    Widget label() => Row(
      children: [
        AppSvgIcon.asset(
          session.avatarIcon ?? 'home_drawer_session_neutral',
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
              color: colors.onSurface,
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
          icon: menuIcon('menu_pin', 15),
          onSelected: () {
            if (ref.read(userProvider)?.id != userId) return;
            ref.read(sessionsProvider.notifier).setPinned(session.id, !pinned);
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
            ref.read(sessionsProvider.notifier).delete(session.id);
            AppToast.success(context, l10n.projectItemDeleted);
          },
        ),
      ],
      child: Material(
        color: colors.surface,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: label(),
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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty ||
        _name.text.trim().runes.length > 200 ||
        ref.read(userProvider)?.id != widget.userId) {
      return;
    }
    ref.read(sessionsProvider.notifier).rename(widget.session.id, _name.text);
    AppToast.success(context, AppLocalizations.of(context)!.projectItemRenamed);
    Navigator.of(context).pop();
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
