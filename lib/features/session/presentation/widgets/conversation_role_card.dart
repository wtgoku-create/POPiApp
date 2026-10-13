import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/conversation_role_profile.dart';
import '../../domain/conversation_snapshot.dart';

/// Mirrors Web role cards while retaining the role version saved in the message.
class ConversationRoleCard extends StatefulWidget {
  const ConversationRoleCard({
    required this.block,
    this.framed = true,
    super.key,
  });
  final ConversationBlock block;
  final bool framed;

  @override
  State<ConversationRoleCard> createState() => _ConversationRoleCardState();
}

class _ConversationRoleCardState extends State<ConversationRoleCard> {
  bool _expanded = true;

  void _preview(ConversationRoleProfile role) {
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
                _RolePortrait(role: role),
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
    final role = ConversationRoleProfile.fromBlock(widget.block);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final buttonTextStyle = Theme.of(context).textTheme.labelLarge!;
    if (!role.showProfileCard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final label in [
                l10n.chatCastRole,
                widget.block.status == 'active'
                    ? l10n.chatRoleActive
                    : l10n.chatRoleDraft,
              ])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: colors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const Key('conversation-role-summary'),
              width: 188,
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: widget.framed
                  ? const EdgeInsets.all(10)
                  : EdgeInsets.zero,
              decoration: widget.framed
                  ? BoxDecoration(
                      color: colors.primary.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RolePortrait(role: role, size: 168),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          role.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('conversation-role-view-profile'),
                        onPressed: () => _preview(role),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 28),
                          textStyle: buttonTextStyle.copyWith(fontSize: 12),
                        ),
                        child: Text(l10n.roleArchive),
                      ),
                    ],
                  ),
                  Text(
                    role.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    final title = role.published
        ? l10n.chatRolePublished
        : role.updated
        ? l10n.chatRoleUpdated
        : l10n.chatRoleCreated;
    return Container(
      key: const Key('conversation-role-card'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: widget.framed
          ? const EdgeInsets.all(20)
          : EdgeInsets.symmetric(vertical: 12),
      decoration: widget.framed
          ? BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.white.withValues(alpha: .5)
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            key: const Key('conversation-role-toggle'),
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: buttonTextStyle.copyWith(
                fontSize: 14,
                height: 20 / 14,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: Text(title)),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    MediaQuery.sizeOf(context).width > 600 &&
                    constraints.maxWidth >= 440 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 20;
                final fields = _RoleFields(
                  role: role,
                  labelWidth: wide ? 96 : 80,
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RolePortrait(role: role),
                          const SizedBox(width: 20),
                          Expanded(child: fields),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RolePortrait(role: role),
                          const SizedBox(height: 16),
                          fields,
                        ],
                      );
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('conversation-role-view-profile'),
                onPressed: role.published
                    ? () => context.push('/assets?section=roles')
                    : () => _preview(role),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right, size: 16),
                label: Text(
                  role.published
                      ? l10n.chatViewRoleLibrary
                      : l10n.chatViewRoleProfile,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  backgroundColor: colors.primary.withValues(alpha: .05),
                  minimumSize: const Size(167, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  textStyle: buttonTextStyle.copyWith(
                    fontSize: 14,
                    height: 20 / 14,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RolePortrait extends StatelessWidget {
  const _RolePortrait({required this.role, this.size = 80});
  final ConversationRoleProfile role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSvgIcon.asset('chat_role_draft', size: size),
        const SizedBox(height: 5),
        Text(
          AppLocalizations.of(context)!.roleFieldPending,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .3),
          ),
        ),
      ],
    );
    if (role.portrait.isEmpty) return fallback;
    final fit = role.updated ? BoxFit.contain : BoxFit.cover;
    final image = role.portrait.startsWith('assets/')
        ? Image.asset(
            role.portrait,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback,
          )
        : Image.network(
            role.portrait,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback,
          );
    return ClipRRect(
      key: const Key('conversation-role-portrait'),
      borderRadius: BorderRadius.circular(role.updated ? 10 : 20),
      child: ColoredBox(
        color: AppColors.brand.withValues(alpha: .05),
        child: image,
      ),
    );
  }
}

class _RoleFields extends StatelessWidget {
  const _RoleFields({required this.role, required this.labelWidth});
  final ConversationRoleProfile role;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Column(
      key: const Key('conversation-role-fields'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < role.fields.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: stacked ? null : labelWidth,
                child: Text(
                  _fieldLabel(
                    role.fields[index].$1,
                    AppLocalizations.of(context)!,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (stacked) const SizedBox(height: 4),
              Flexible(
                flex: stacked ? 0 : 1,
                fit: stacked ? FlexFit.loose : FlexFit.tight,
                child: Text(
                  role.fields[index].$2,
                  style: const TextStyle(fontSize: 14, height: 20 / 14),
                ),
              ),
            ],
          ),
        ],
      ],
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
