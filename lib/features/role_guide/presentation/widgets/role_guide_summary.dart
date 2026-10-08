import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../assets/domain/library_role.dart';
import 'role_guide_controls.dart';

class RoleProjectSummary extends StatelessWidget {
  const RoleProjectSummary({required this.roles, super.key});
  final List<LibraryRole> roles;

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
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoleGuideAvatar(role: roles.first),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.roleProjectName(roles.first.title),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.roleProjectCount(roles.length),
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (stacked) ...[const SizedBox(height: 8), status],
                  ],
                ),
              ),
              if (!stacked) ...[const SizedBox(width: 5), status],
            ],
          );
        },
      ),
    );
  }
}

class RoleCastSummary extends StatelessWidget {
  const RoleCastSummary({required this.cast, required this.onEdit, super.key});
  final List<LibraryRole> cast;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: roleGuideTint(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('role-guide-edit-cast'),
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 50 + (cast.length - 1) * 16,
                height: 50,
                child: Stack(
                  children: [
                    for (var i = cast.length - 1; i >= 0; i--)
                      Positioned(
                        left: i * 16,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: RoleGuideAvatar(role: cast[i], size: 44),
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
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
