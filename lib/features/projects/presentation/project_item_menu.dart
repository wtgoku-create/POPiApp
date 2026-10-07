import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/project_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../domain/project.dart';

const _menuDeleteColor = Color(0xFFCC4646);

/// Shares project and session actions between long-press and desktop menus.
class ProjectItemMenu extends ConsumerWidget {
  const ProjectItemMenu({
    required this.projectId,
    required this.title,
    required this.child,
    this.session,
    this.onSessionCreated,
    super.key,
  });

  final String projectId;
  final String title;
  final ProjectSession? session;
  final ValueChanged<ProjectSession>? onSessionCreated;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final busy = ref.watch(projectActionsProvider);
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final pinned = session?.pinnedAt != null;
    return AppContextMenu(
      label: l10n.projectItemOptions(title),
      enabled: !busy && userId != null,
      preview: Padding(
        padding: EdgeInsets.symmetric(horizontal: session == null ? 10 : 35),
        child: Row(
          children: [
            if (session == null) ...[
              AppSvgIcon.asset(
                'home_drawer_project',
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (pinned) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.push_pin,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
            if (session == null) const SizedBox(width: 25),
          ],
        ),
      ),
      entries: [
        if (session == null)
          AppMenuItem(
            label: l10n.newConversation,
            icon: const _ProjectMenuIcon('menu_new_conversation', size: 14),
            onSelected: () async {
              if (ref.read(userProvider)?.id != userId) return;
              try {
                final created = await ref
                    .read(projectActionsProvider.notifier)
                    .createSession(projectId, l10n.newSessionTitle);
                if (created != null &&
                    context.mounted &&
                    ref.read(userProvider)?.id == userId) {
                  onSessionCreated?.call(created);
                }
              } catch (error) {
                if (context.mounted && ref.read(userProvider)?.id == userId) {
                  AppToast.error(context, _errorMessage(error, l10n));
                }
              }
            },
          ),
        if (session != null)
          AppMenuItem(
            label: pinned ? l10n.unpinSession : l10n.pinSession,
            icon: const _ProjectMenuIcon('menu_pin', size: 15),
            onSelected: () async {
              if (ref.read(userProvider)?.id != userId) return;
              try {
                await ref
                    .read(projectActionsProvider.notifier)
                    .setSessionPinned(projectId, session!.id, !pinned);
              } catch (error) {
                if (context.mounted) {
                  AppToast.error(context, _errorMessage(error, l10n));
                }
              }
            },
          ),
        AppMenuItem(
          label: l10n.renameProjectItem,
          icon: const _ProjectMenuIcon('menu_rename'),
          onSelected: () => _showDialog(context, userId, false),
        ),
        const AppMenuDivider(),
        AppMenuItem(
          label: l10n.delete,
          icon: const _ProjectMenuIcon('menu_delete'),
          destructive: true,
          foregroundColor: _menuDeleteColor,
          onSelected: () => _showDialog(context, userId, true),
        ),
      ],
      child: child,
    );
  }

  void _showDialog(BuildContext context, String? userId, bool delete) {
    AppDialog.show<bool>(
      context: context,
      builder: (_) => _ProjectActionDialog(
        userId: userId,
        projectId: projectId,
        sessionId: session?.id,
        title: title,
        delete: delete,
      ),
    );
  }
}

class _ProjectMenuIcon extends StatelessWidget {
  const _ProjectMenuIcon(this.name, {this.size = 20});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: AppSvgIcon.asset(
      name,
      size: size,
      color: IconTheme.of(context).color,
    ),
  );
}

String _errorMessage(Object error, AppLocalizations l10n) =>
    error is ApiException && error.message?.isNotEmpty == true
    ? error.message!
    : l10n.networkRequestFailed;

class _ProjectActionDialog extends ConsumerStatefulWidget {
  const _ProjectActionDialog({
    required this.userId,
    required this.projectId,
    required this.sessionId,
    required this.title,
    required this.delete,
  });

  final String? userId;
  final String projectId;
  final String? sessionId;
  final String title;
  final bool delete;

  @override
  ConsumerState<_ProjectActionDialog> createState() =>
      _ProjectActionDialogState();
}

class _ProjectActionDialogState extends ConsumerState<_ProjectActionDialog> {
  late final _name = TextEditingController(text: widget.title);
  bool _pending = false;
  bool _closing = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _name.text.trim();
    if (_pending ||
        ref.read(userProvider)?.id != widget.userId ||
        (!widget.delete && (title.isEmpty || title.runes.length > 200))) {
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final actions = ref.read(projectActionsProvider.notifier);
      final sessionId = widget.sessionId;
      final success = await (widget.delete
          ? sessionId == null
                ? actions.deleteProject(widget.projectId)
                : actions.deleteSession(widget.projectId, sessionId)
          : sessionId == null
          ? actions.renameProject(widget.projectId, title)
          : actions.renameSession(widget.projectId, sessionId, title));
      if (!mounted || !success) return;
      AppToast.success(
        context,
        widget.delete ? l10n.projectItemDeleted : l10n.projectItemRenamed,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error, l10n));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final buttonTextStyle = Theme.of(
      context,
    ).textTheme.labelLarge!.copyWith(fontSize: 16);
    final currentUser = ref.watch(userProvider.select((user) => user?.id));
    // A confirmation from another account must never apply to the current one.
    if (currentUser != widget.userId && !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(false);
      });
    }
    final name = _name.text.trim();
    final enabled =
        !_pending &&
        !_closing &&
        (widget.delete || (name.isNotEmpty && name.runes.length <= 200));
    return PopScope(
      canPop: !_pending,
      child: AppDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.delete ? l10n.delete : l10n.renameProjectItem,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 25),
            if (widget.delete)
              Text(
                widget.sessionId == null
                    ? l10n.deleteProjectConfirm(widget.title)
                    : l10n.deleteSessionConfirm(widget.title),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 16,
                  height: 1.3,
                ),
              )
            else
              TextField(
                key: const Key('project-rename-input'),
                controller: _name,
                enabled: !_pending,
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.error, fontSize: 14),
              ),
            ],
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: TextButton(
                      onPressed: _pending
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.brand.withValues(alpha: .05),
                        foregroundColor: colors.onSurface,
                        shape: const StadiumBorder(),
                        textStyle: buttonTextStyle,
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
                      key: const Key('project-action-confirm'),
                      onPressed: enabled ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.delete
                            ? const Color(0xFFD63D43)
                            : colors.primary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        textStyle: buttonTextStyle,
                      ),
                      child: _pending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.delete ? l10n.delete : l10n.confirm),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
