import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../assets/domain/library_role.dart';
import '../../../assets/presentation/role_detail_page.dart';
import 'role_guide_sheet.dart';

/// Uses the archive page layout while browsing roles in selection order.
class RoleProfileSheet extends StatefulWidget {
  const RoleProfileSheet({required this.roles, super.key});

  final List<LibraryRole> roles;

  @override
  State<RoleProfileSheet> createState() => _RoleProfileSheetState();
}

class _RoleProfileSheetState extends State<RoleProfileSheet> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = widget.roles[_index];
    final hasMultipleRoles = widget.roles.length > 1;
    final title = hasMultipleRoles
        ? l10n.roleProfilePage(_index + 1, widget.roles.length)
        : l10n.roleArchive;
    return RoleGuideSheet(
      key: const Key('role-guide-profile-sheet'),
      title: title,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: .9),
      initialSize: .875,
      header: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            if (hasMultipleRoles) ...[
              const SizedBox(width: 5),
              _navigationButton(
                previous: true,
                tooltip: l10n.rolePreviousProfile,
                onPressed: _index == 0 ? null : () => setState(() => _index--),
              ),
              _navigationButton(
                previous: false,
                tooltip: l10n.roleNextProfile,
                onPressed: _index == widget.roles.length - 1
                    ? null
                    : () => setState(() => _index++),
              ),
            ],
          ],
        ),
      ),
      builder: (context, controller) => RoleDetailPage.sheet(
        key: ValueKey(role.id),
        role: role,
        category: role.canEdit ? 'personal' : 'official',
        scrollController: controller,
      ),
    );
  }

  Widget _navigationButton({
    required bool previous,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => SizedBox.square(
    dimension: 40,
    child: IconButton(
      key: Key(previous ? 'role-profile-previous' : 'role-profile-next'),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: RotatedBox(
        quarterTurns: previous ? 2 : 0,
        child: SizedBox(
          width: 6,
          height: 12,
          child: AppSvgIcon.asset(
            'role_profile_arrow',
            color: onPressed == null
                ? Theme.of(context).disabledColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ),
  );
}

class RoleGuideTextSection extends StatelessWidget {
  const RoleGuideTextSection({
    required this.title,
    required this.text,
    super.key,
  });
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
