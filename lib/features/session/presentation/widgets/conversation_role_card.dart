import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_network_image.dart';
import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/conversation_role_profile.dart';
import '../../domain/conversation_snapshot.dart';

/// A compact role link backed by the saved profile version in the message.
class ConversationRoleCard extends StatelessWidget {
  const ConversationRoleCard({
    required this.block,
    this.framed = true,
    super.key,
  });

  final ConversationBlock block;
  final bool framed;

  void _preview(BuildContext context, ConversationRoleProfile role) {
    AppSheet.showDraggable<void>(
      context: context,
      initialChildSize: .8,
      minChildSize: .5,
      builder: (context, controller) {
        final l10n = AppLocalizations.of(context)!;
        return ListView(
          key: const Key('conversation-role-profile'),
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              l10n.roleArchive,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _RolePortrait(role: role, size: 80),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    role.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            for (final (label, value) in [...role.overview, ...role.fullFields])
              if (value.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  _fieldLabel(label, l10n),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  value,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ConversationRoleProfile.fromBlock(block);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final status = role.showProfileCard
        ? role.published
              ? l10n.chatRolePublished
              : role.updated
              ? l10n.chatRoleUpdated
              : l10n.chatRoleCreated
        : null;
    return Container(
      key: Key(
        role.showProfileCard
            ? 'conversation-role-card'
            : 'conversation-role-summary',
      ),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: TextButton(
        key: const Key('conversation-role-view-profile'),
        onPressed: role.published
            ? () => context.push('/assets?section=roles')
            : () => _preview(context, role),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: framed ? 16 : 0,
            vertical: 16,
          ),
          minimumSize: const Size(0, 80),
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
            const SizedBox(width: 18),
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
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
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
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
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

String _fieldLabel(String label, AppLocalizations l10n) => switch (label) {
  'title' => l10n.chatRoleName,
  'description' => l10n.roleDescription,
  'expressionStyle' => l10n.roleStyle,
  'targetAudience' => l10n.roleAudience,
  'contentTags' => l10n.roleTags,
  _ => label,
};
