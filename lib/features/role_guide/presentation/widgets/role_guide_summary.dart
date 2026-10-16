import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../assets/domain/library_role.dart';
import 'role_guide_controls.dart';

class RoleProjectSummary extends StatelessWidget {
  const RoleProjectSummary({
    required this.title,
    this.avatar = '',
    this.loading = false,
    this.showStatus = false,
    this.onViewProfile,
    super.key,
  });
  final String title;
  final String avatar;
  final bool loading;
  final bool showStatus;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFA0EB91).withValues(alpha: .15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        l10n.ipAccountNormalStatus,
        style: const TextStyle(fontSize: 16, color: Color(0xFF0F9E3F)),
      ),
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('role-guide-project-profile'),
        onTap: onViewProfile,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: AppColors.brand.withValues(alpha: .15),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 290 ||
                  MediaQuery.textScalerOf(context).scale(16) > 20;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (loading)
                    const AppSkeletonBox(width: 50, height: 50, radius: 10)
                  else
                    ClipRRect(
                      key: const Key('role-guide-account-avatar'),
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.square(
                        dimension: 50,
                        child: avatar.isEmpty
                            ? const AppSvgIcon.asset(
                                'project_default_avatar',
                                size: 50,
                              )
                            : avatar.startsWith('assets/')
                            ? Image.asset(avatar, fit: BoxFit.cover)
                            : AppNetworkImage(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const AppSvgIcon.asset(
                                      'project_default_avatar',
                                      size: 50,
                                    ),
                              ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (loading)
                          const AppSkeletonBox(height: 18)
                        else
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (showStatus && stacked) ...[
                          const SizedBox(height: 8),
                          status,
                        ],
                      ],
                    ),
                  ),
                  if (showStatus && !stacked) ...[
                    const SizedBox(width: 5),
                    status,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class RoleCastSummary extends StatelessWidget {
  const RoleCastSummary({
    required this.cast,
    required this.onViewProfiles,
    this.onEdit,
    this.avatarOffset = 16,
    super.key,
  });
  final List<LibraryRole> cast;
  final VoidCallback onViewProfiles;
  final VoidCallback? onEdit;
  final double avatarOffset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (cast.isEmpty) {
      return TextButton(
        key: const Key('role-guide-select-cast'),
        onPressed: onEdit,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          backgroundColor: roleGuideTint(context),
          minimumSize: const Size(0, 90),
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppSvgIcon.asset(
              'role_guide_add',
              size: 24,
              color: onEdit == null
                  ? Theme.of(context).disabledColor
                  : AppColors.brand,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n.roleCastTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: roleGuideTint(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('role-guide-view-profiles'),
        onTap: onViewProfiles,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 74 + (cast.length.clamp(1, 3) - 1) * avatarOffset,
                height: 70,
                child: Stack(
                  children: [
                    for (var i = cast.length.clamp(0, 3) - 1; i >= 0; i--)
                      Positioned(
                        left: 12 + i * avatarOffset,
                        top: 10,
                        child: Transform.rotate(
                          key: ValueKey('role-cast-fan-$i'),
                          angle: (i - (cast.length.clamp(1, 3) - 1) / 2) * .22,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: RoleGuideAvatar(role: cast[i], size: 44),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            l10n.roleCastCount(cast.length),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 7,
                          height: 14,
                          child: AppSvgIcon.asset(
                            'role_guide_chevron',
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      cast.map((role) => role.title).join('、'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  key: const Key('role-guide-edit-cast'),
                  tooltip: l10n.roleEditProjectRoles,
                  onPressed: onEdit,
                  // Figma exports this rotated frame in its local orientation.
                  icon: const RotatedBox(
                    quarterTurns: 1,
                    child: AppSvgIcon.asset(
                      'role_guide_edit',
                      size: 20,
                      color: AppColors.brand,
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
