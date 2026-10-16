import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../role_guide/domain/role_guide_draft.dart';
import '../../role_guide/presentation/widgets/role_guide_controls.dart';
import '../../role_guide/presentation/widgets/role_guide_picker.dart';
import '../../role_guide/presentation/widgets/role_guide_sheet.dart';
import '../domain/library_role.dart';

/// Confirms an ordered role selection without starting a creation project.
class RoleSelectionSheet extends StatefulWidget {
  const RoleSelectionSheet({
    this.selected = const [],
    this.conversationMode = false,
    this.creatorMode = false,
    this.onConfirm,
    this.onCreate,
    this.status,
    this.enabled,
    super.key,
  });

  final List<LibraryRole> selected;
  final bool conversationMode;
  final bool creatorMode;
  final Future<bool> Function(List<LibraryRole>)? onConfirm;
  final VoidCallback? onCreate;
  final Listenable? status;
  final bool Function()? enabled;

  static Future<List<LibraryRole>?> show({
    required BuildContext context,
    List<LibraryRole> selected = const [],
    bool conversationMode = false,
    bool creatorMode = false,
    Future<bool> Function(List<LibraryRole>)? onConfirm,
    VoidCallback? onCreate,
    Listenable? status,
    bool Function()? enabled,
  }) => AppSheet.show<List<LibraryRole>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => RoleSelectionSheet(
      selected: selected,
      conversationMode: conversationMode,
      creatorMode: creatorMode,
      onConfirm: onConfirm,
      onCreate: onCreate,
      status: status,
      enabled: enabled,
    ),
  );

  @override
  State<RoleSelectionSheet> createState() => _RoleSelectionSheetState();
}

class _RoleSelectionSheetState extends State<RoleSelectionSheet> {
  late final _selected = widget.selected.take(RoleGuideDraft.maxRoles).toList();
  bool _submitting = false;
  bool get _busy => _submitting || !(widget.enabled?.call() ?? true);

  @override
  void initState() {
    super.initState();
    widget.status?.addListener(_statusChanged);
  }

  void _statusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.status?.removeListener(_statusChanged);
    super.dispose();
  }

  bool _selectable(LibraryRole role) =>
      !widget.conversationMode ||
      role.canRead &&
          (widget.creatorMode ||
              role.profileVersion != null ||
              (role.profileVersionId?.isNotEmpty ?? false));

  void _toggle(LibraryRole role) {
    if (_busy) return;
    final index = _selected.indexWhere((item) => item.id == role.id);
    if (index >= 0) {
      setState(() => _selected.removeAt(index));
    } else if (!_selectable(role)) {
      AppToast.info(
        context,
        AppLocalizations.of(context)!.chatCastRoleUnavailable,
      );
    } else if (_selected.length < RoleGuideDraft.maxRoles) {
      setState(() => _selected.add(role));
    } else {
      AppToast.info(
        context,
        AppLocalizations.of(
          context,
        )!.roleSelectionLimit(RoleGuideDraft.maxRoles),
      );
    }
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final roles = List<LibraryRole>.unmodifiable(_selected);
    if (widget.onConfirm == null) {
      Navigator.of(context).pop(roles);
      return;
    }
    setState(() => _submitting = true);
    try {
      final success = await widget.onConfirm!(roles);
      if (mounted && success) Navigator.of(context).pop(roles);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: RoleGuideSheet(
          key: const Key('role-selection-sheet'),
          title: l10n.roleLibrary,
          initialSize: AppSheet.maxHeightFactor,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: .9),
          header: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              l10n.roleLibrary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          builder: (_, controller) => AbsorbPointer(
            absorbing: _busy,
            child: RoleGuidePicker(
              fullLibrary: true,
              scrollController: controller,
              selected: () => _selected,
              onToggle: _toggle,
              onDetails: (_) {},
              onCategoryChanged: (_) {},
              onCreate: widget.onCreate,
            ),
          ),
          footer: Stack(
            alignment: Alignment.centerRight,
            children: [
              RoleGuideAction(
                key: const Key('role-selection-confirm'),
                label: widget.conversationMode
                    ? l10n.chatConfirmCast
                    : l10n.roleConfirmSelection,
                showArrow: false,
                onPressed:
                    _busy ||
                        (!widget.conversationMode && _selected.isEmpty) ||
                        !_selected.every(_selectable)
                    ? null
                    : _confirm,
              ),
              if (_submitting)
                const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
