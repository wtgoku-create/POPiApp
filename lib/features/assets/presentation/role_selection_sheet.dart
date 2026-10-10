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
  const RoleSelectionSheet({this.selected = const [], super.key});

  final List<LibraryRole> selected;

  static Future<List<LibraryRole>?> show({
    required BuildContext context,
    List<LibraryRole> selected = const [],
  }) => AppSheet.show<List<LibraryRole>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => RoleSelectionSheet(selected: selected),
  );

  @override
  State<RoleSelectionSheet> createState() => _RoleSelectionSheetState();
}

class _RoleSelectionSheetState extends State<RoleSelectionSheet> {
  late final _selected = widget.selected.take(RoleGuideDraft.maxRoles).toList();

  void _toggle(LibraryRole role) {
    final index = _selected.indexWhere((item) => item.id == role.id);
    if (index >= 0) {
      setState(() => _selected.removeAt(index));
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
          builder: (_, controller) => RoleGuidePicker(
            fullLibrary: true,
            scrollController: controller,
            selected: () => _selected,
            onToggle: _toggle,
            onDetails: (_) {},
            onCategoryChanged: (_) {},
          ),
          footer: RoleGuideAction(
            key: const Key('role-selection-confirm'),
            label: l10n.roleConfirmSelection,
            showArrow: false,
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(List<LibraryRole>.unmodifiable(_selected)),
          ),
        ),
      ),
    );
  }
}
