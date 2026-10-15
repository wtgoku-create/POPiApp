import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_network_image.dart';
import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../role_guide/presentation/widgets/role_guide_summary.dart';
import '../../../role_guide/presentation/widgets/role_profile_sheet.dart';
import '../../domain/conversation_role_profile.dart';
import '../../domain/conversation_snapshot.dart';
import 'conversation_card.dart';

void _showRoleProfiles(
  BuildContext context,
  List<ConversationRoleProfile> roles,
) {
  AppSheet.show<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => RoleProfileSheet(
      key: const Key('conversation-role-profile'),
      roles: roles.map((role) => role.snapshotRole).toList(),
      useSnapshot: true,
    ),
  );
}

/// Groups the saved cast in one message while retaining each role's profile.
class ConversationCastCard extends StatelessWidget {
  const ConversationCastCard({required this.blocks, super.key});

  final List<ConversationBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();
    if (blocks.length == 1) return ConversationRoleCard(block: blocks.single);
    final roles = blocks.map(ConversationRoleProfile.fromBlock).toList();
    return LayoutBuilder(
      key: const Key('conversation-cast-summary'),
      builder: (context, constraints) => RoleCastSummary(
        cast: roles.map((role) => role.snapshotRole).toList(),
        avatarOffset: constraints.maxWidth < 320 ? 16 : 22,
        onViewProfiles: () => _showRoleProfiles(context, roles),
      ),
    );
  }
}

/// A compact role link backed by the saved profile version in the message.
class ConversationRoleCard extends StatelessWidget {
  const ConversationRoleCard({
    required this.block,
    this.framed = true,
    this.compact = false,
    super.key,
  });

  final ConversationBlock block;
  final bool framed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final role = ConversationRoleProfile.fromBlock(block);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final status = role.showProfileCard && !compact
        ? role.published
              ? l10n.chatRolePublished
              : role.updated
              ? l10n.chatRoleUpdated
              : l10n.chatRoleCreated
        : null;
    return SizedBox(
      key: Key(
        role.showProfileCard
            ? 'conversation-role-card'
            : 'conversation-role-summary',
      ),
      width: double.infinity,
      child: TextButton(
        key: const Key('conversation-role-view-profile'),
        onPressed: role.published
            ? () => context.push('/assets?section=roles')
            : () => _showRoleProfiles(context, [role]),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: framed ? (compact ? 12 : 16) : 0,
            vertical: compact ? 12 : 16,
          ),
          minimumSize: Size(0, compact ? 68 : 80),
          foregroundColor: colors.primary,
          backgroundColor: framed
              ? colors.primary.withValues(alpha: .05)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
        child: Row(
          children: [
            _RolePortrait(role: role, size: 44),
            SizedBox(width: compact ? 12 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          role.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ConversationCardTypography.title.copyWith(
                            fontSize: compact ? 14 : 16,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ConversationCardTypography.caption.copyWith(
                      fontWeight: FontWeight.w400,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: ConversationCardTypography.caption.copyWith(
                        fontWeight: FontWeight.w400,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePortrait extends StatelessWidget {
  const _RolePortrait({required this.role, required this.size});
  final ConversationRoleProfile role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: AppSvgIcon.asset('chat_role_draft', size: size),
    );
    final fit = role.updated ? BoxFit.contain : BoxFit.cover;
    final image = role.portrait.isEmpty
        ? fallback
        : role.portrait.startsWith('assets/')
        ? Image.asset(
            role.portrait,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback,
          )
        : AppNetworkImage(
            role.portrait,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback,
          );
    return SizedBox.square(
      key: const Key('conversation-role-portrait'),
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: image,
        ),
      ),
    );
  }
}
