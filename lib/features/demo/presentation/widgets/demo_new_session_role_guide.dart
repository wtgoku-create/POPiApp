import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/demo_fixtures.dart';
import '../../data/demo_repository.dart';
import '../../domain/demo_models.dart';
import 'demo_content_role_avatar.dart';
import 'demo_widgets.dart';

/// A lightweight first-session prompt that keeps the composer available.
class DemoNewSessionRoleGuide extends StatefulWidget {
  const DemoNewSessionRoleGuide({
    required this.repository,
    required this.session,
    required this.onLinkRole,
    required this.onUploadDiyRole,
    required this.onCompleteRole,
    required this.onStartCreating,
    super.key,
  });

  final DemoRepository repository;
  final DemoSession session;
  final Future<void> Function() onLinkRole;
  final Future<void> Function() onUploadDiyRole;
  final VoidCallback onCompleteRole;
  final VoidCallback onStartCreating;

  @override
  State<DemoNewSessionRoleGuide> createState() =>
      _DemoNewSessionRoleGuideState();
}

class _DemoNewSessionRoleGuideState extends State<DemoNewSessionRoleGuide> {
  bool _openingPicker = false;

  Future<void> _open(Future<void> Function() action) async {
    if (_openingPicker) return;
    setState(() => _openingPicker = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _openingPicker = false);
    }
  }

  String _roleName(String roleId) {
    final configured = widget.session.roleProfiles[roleId]?.name.trim() ?? '';
    if (configured.isNotEmpty) return configured;
    final fixture = DemoFixtures.characters
        .where((role) => role.id == roleId)
        .firstOrNull;
    return fixture?.name ??
        (roleId.startsWith('custom:') ? roleId.substring(7) : roleId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final linkedRoleId = widget.session.roles.firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 480;
        return SingleChildScrollView(
          key: const Key('demo-new-session-role-guide'),
          padding: EdgeInsets.fromLTRB(20, compact ? 10 : 20, 20, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - (compact ? 26 : 40)).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/demo_welcome.png',
                      width: compact ? 72 : 96,
                      height: compact ? 72 : 96,
                      cacheWidth: 288,
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Text(
                      l.demoGreeting,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 20 : 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.demoGreetingDetail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                    SizedBox(height: compact ? 12 : 18),
                    if (linkedRoleId == null)
                      _UnlinkedRoleCard(
                        openingPicker: _openingPicker,
                        onLinkRole: () => _open(widget.onLinkRole),
                        onUploadDiyRole: () => _open(widget.onUploadDiyRole),
                      )
                    else
                      _LinkedRoleCard(
                        repository: widget.repository,
                        session: widget.session,
                        roleId: linkedRoleId,
                        roleName: _roleName(linkedRoleId),
                        roleReady:
                            widget
                                .session
                                .roleProfiles[linkedRoleId]
                                ?.isReady ==
                            true,
                        onCompleteRole: widget.onCompleteRole,
                        onStartCreating: widget.onStartCreating,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnlinkedRoleCard extends StatelessWidget {
  const _UnlinkedRoleCard({
    required this.openingPicker,
    required this.onLinkRole,
    required this.onUploadDiyRole,
  });

  final bool openingPicker;
  final VoidCallback onLinkRole;
  final VoidCallback onUploadDiyRole;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      key: const Key('demo-new-session-role-empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: demoSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.demoNewSessionRoleTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            l.demoNewSessionRoleHint,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 360;
              final buttons = [
                OutlinedButton.icon(
                  key: const Key('demo-link-content-role'),
                  onPressed: openingPicker ? null : onLinkRole,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(l.demoLinkContentRole),
                ),
                FilledButton.tonalIcon(
                  key: const Key('demo-upload-diy-role'),
                  onPressed: openingPicker ? null : onUploadDiyRole,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: Text(l.demoUploadDiyRole),
                ),
              ];
              if (!horizontal) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      buttons[index],
                      if (index == 0) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 10),
                  Expanded(child: buttons[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LinkedRoleCard extends StatelessWidget {
  const _LinkedRoleCard({
    required this.repository,
    required this.session,
    required this.roleId,
    required this.roleName,
    required this.roleReady,
    required this.onCompleteRole,
    required this.onStartCreating,
  });

  final DemoRepository repository;
  final DemoSession session;
  final String roleId;
  final String roleName;
  final bool roleReady;
  final VoidCallback onCompleteRole;
  final VoidCallback onStartCreating;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      key: Key(
        roleReady
            ? 'demo-new-session-role-ready'
            : 'demo-new-session-role-pending',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: demoSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              DemoContentRoleAvatar(
                repository: repository,
                session: session,
                roleId: roleId,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      roleReady ? l.demoRoleContextReady : l.demoRolePending,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                roleReady
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 21,
                color: roleReady ? AppColors.success : AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: roleReady
                ? FilledButton(
                    key: const Key('demo-start-creating'),
                    onPressed: onStartCreating,
                    child: Text(l.demoStartCreating),
                  )
                : OutlinedButton.icon(
                    key: const Key('demo-complete-role-context'),
                    onPressed: onCompleteRole,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(l.demoRoleProfile),
                  ),
          ),
        ],
      ),
    );
  }
}
