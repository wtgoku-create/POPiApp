import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/type/bot_avatar_type.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/demo_fixtures.dart';
import '../data/demo_repository.dart';
import '../data/demo_website_character_catalog.dart';
import '../domain/demo_models.dart';
import 'demo_assistant_display.dart';
import 'demo_assets_page.dart';
import 'demo_diy_role_sheet.dart';
import 'demo_remote_media.dart';
import 'widgets/demo_content_role_avatar.dart';
import 'widgets/demo_widgets.dart';

const _contentPadding = EdgeInsets.symmetric(horizontal: 16);
const _cardRadius = 20.0;

class DemoSettingsPage extends StatefulWidget {
  const DemoSettingsPage({
    required this.repository,
    required this.sessionId,
    this.initialTab = 0,
    super.key,
  }) : assert(initialTab >= 0 && initialTab < 3);

  final DemoRepository repository;
  final String sessionId;
  final int initialTab;

  @override
  State<DemoSettingsPage> createState() => _DemoSettingsPageState();
}

/// Opens the same role picker used by settings from another demo surface.
Future<void> showDemoRoleSheet(
  BuildContext context,
  DemoRepository repository,
  String sessionId,
) async {
  await DemoSheet.show<void>(
    context: context,
    builder: (_) => _RoleSheet(
      repository: repository,
      session: repository.session(sessionId),
    ),
  );
}

class _DemoSettingsPageState extends State<DemoSettingsPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 3,
    initialIndex: widget.initialTab,
    vsync: this,
  )..addListener(_updateTab);
  DemoCapabilityCatalog? _capabilityCatalog;
  Object? _capabilityError;
  bool _capabilityLoading = true;
  bool _capabilityStatusConfirmed = false;
  bool _capabilityErrorShown = false;
  int _capabilityRequest = 0;
  late String _lastCapabilitySignature;

  @override
  void initState() {
    super.initState();
    _lastCapabilitySignature = _capabilitySignature(
      widget.repository.session(widget.sessionId),
    );
    widget.repository.addListener(_handleRepositoryChange);
    unawaited(_loadCapabilityCatalog());
  }

  void _handleRepositoryChange() {
    if (!mounted) return;
    final signature = _capabilitySignature(
      widget.repository.session(widget.sessionId),
    );
    if (signature == _lastCapabilitySignature) return;
    _lastCapabilitySignature = signature;
    unawaited(_loadCapabilityCatalog());
  }

  Future<void> _loadCapabilityCatalog() async {
    final request = ++_capabilityRequest;
    _capabilityErrorShown = false;
    if (_capabilityCatalog == null) {
      _capabilityLoading = true;
    } else if (mounted) {
      setState(() {
        _capabilityError = null;
        _capabilityStatusConfirmed = false;
      });
    }
    try {
      final catalog = await widget.repository.loadCapabilityCatalog(
        sessionId: widget.sessionId,
      );
      if (!mounted || request != _capabilityRequest) return;
      setState(() {
        _capabilityCatalog = catalog;
        _capabilityError = null;
        _capabilityLoading = false;
        _capabilityStatusConfirmed = true;
      });
    } catch (error) {
      if (!mounted || request != _capabilityRequest) return;
      setState(() {
        _capabilityError = error;
        _capabilityLoading = false;
      });
    }
  }

  void _updateTab() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_handleRepositoryChange);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final session = widget.repository.session(widget.sessionId);
        return DemoScaffold(
          title: Text(l.demoSettings),
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(child: _identityCard(context, session, l)),
              SliverPersistentHeader(
                pinned: true,
                delegate: DemoPinnedHeader(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: DemoSegments(
                      labels: [l.demoInfo, l.demoCapabilities, l.demoOutputs],
                      selected: _tabs.index,
                      onChanged: _tabs.animateTo,
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _KeepTab(child: _info(context, session, l)),
                _KeepTab(child: _capabilities(context, session, l)),
                _KeepTab(
                  child: DemoAssetsView(
                    repository: widget.repository,
                    sessionId: session.id,
                    compactHeader: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _identityCard(
    BuildContext context,
    DemoSession session,
    AppLocalizations l,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: demoSurface(context),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Row(
        children: [
          DemoAvatar(
            members: session.members,
            size: 60,
            memberAvatars: session.memberAvatars,
            memberColors: session.memberColors,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  demoSessionDisplayName(l, session),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (session.members.length > 1) ...[
                  const SizedBox(height: 3),
                  Text(
                    session.members
                        .take(2)
                        .map((id) => demoSessionMemberName(l, session, id))
                        .join(' × '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: const Key('demo-settings-rename'),
            tooltip: l.demoRename,
            onPressed: () => demoEditText(
              context,
              title: l.demoRename,
              value: demoSessionDisplayName(l, session),
              onSave: (value) => widget.repository.updateSession(
                session.id,
                (session) => session.copyWith(title: value),
              ),
            ),
            icon: const RotatedBox(
              quarterTurns: 1,
              child: DemoIcon('edit', size: 18),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _info(
    BuildContext context,
    DemoSession session,
    AppLocalizations l,
  ) => ListView(
    key: const PageStorageKey('demo-settings-info'),
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
    children: [
      Material(
        color: demoSurface(context),
        borderRadius: BorderRadius.circular(_cardRadius),
        child: InkWell(
          key: const Key('demo-settings-roles'),
          borderRadius: BorderRadius.circular(_cardRadius),
          onTap: () => _roles(context, session),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.demoLinkedRoles,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.demoContextRolesHint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          session.roles.isEmpty
                              ? l.demoNoRoles
                              : '${l.demoRoleCount(session.roles.length)} · '
                                    '${session.roles.every((id) => _roleIsConfigured(session.roleProfiles[id])) ? l.demoRoleConfigured : l.demoRolePending}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final role in session.roles.take(4))
                    Align(
                      widthFactor: .62,
                      child: DemoContentRoleAvatar(
                        repository: widget.repository,
                        session: session,
                        roleId: role,
                        size: 44,
                      ),
                    ),
                  if (session.roles.length > 4)
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: demoTint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '+${session.roles.length - 4}',
                        style: const TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                  const SizedBox(width: 8),
                  const RotatedBox(
                    quarterTurns: 3,
                    child: DemoIcon(
                      'back',
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (session.roles.isNotEmpty) ...[
        const SizedBox(height: 12),
        Material(
          color: demoSurface(context),
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Column(
            children: [
              for (var index = 0; index < session.roles.length; index++) ...[
                _RoleProfileRow(
                  repository: widget.repository,
                  session: session,
                  roleId: session.roles[index],
                  onTap: () => _editRoleProfile(
                    context,
                    session.id,
                    session.roles[index],
                  ),
                ),
                if (index != session.roles.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      _section(
        context,
        title: l.demoPreferences,
        subtitle: l.demoContextPreferencesHint,
        onEdit: () => _editPreferences(context, session),
        children: [
          _field(l.demoDirection, _configuredValue(l, session.direction)),
          const Divider(height: 24),
          _field(l.demoPositioning, _configuredValue(l, session.positioning)),
          const Divider(height: 24),
          _field(
            l.demoFeeling,
            _configuredValue(l, session.accountPreferences['feeling'] ?? ''),
          ),
          const Divider(height: 24),
          _field(
            l.demoFormat,
            _configuredValue(l, session.accountPreferences['format'] ?? ''),
          ),
          const Divider(height: 24),
          _field(
            l.demoAudience,
            _configuredValue(l, session.accountPreferences['audience'] ?? ''),
          ),
        ],
      ),
    ],
  );

  Widget _capabilities(
    BuildContext context,
    DemoSession session,
    AppLocalizations l,
  ) => CustomScrollView(
    key: const PageStorageKey('demo-settings-skills'),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: demoSurface(context),
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.demoGlobalCapabilities,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.demoDshCapabilitiesHint,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (session.mediaJobs.any((job) => job.isPending)) ...[
                  const Divider(height: 20),
                  Text(
                    l.demoCurrentTaskConfigNotice,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: demoSurface(context),
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            child: Column(
              children: [
                for (var i = 0; i < session.members.length; i++) ...[
                  _MemberRow(
                    key: ValueKey('demo-member-${session.members[i]}'),
                    session: session,
                    memberId: session.members[i],
                    onEdit: () =>
                        _editMember(context, session.id, session.members[i]),
                  ),
                  if (i != session.members.length - 1)
                    const SizedBox(height: 8),
                ],
                if (session.members.isNotEmpty) const SizedBox(height: 12),
                Tooltip(
                  message: l.demoSingleAssistantNotice,
                  child: _TintButton(
                    key: const Key('demo-add-members'),
                    label: l.demoAddMembers,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: _contentPadding,
        sliver: SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              if (_capabilityLoading && _capabilityCatalog == null) {
                return AppSkeleton(
                  label: l.demoCapabilities,
                  child: const Column(
                    children: [
                      AppSkeletonBox(height: 88, radius: _cardRadius),
                      SizedBox(height: 12),
                      AppSkeletonBox(height: 88, radius: _cardRadius),
                      SizedBox(height: 12),
                      AppSkeletonBox(height: 88, radius: _cardRadius),
                    ],
                  ),
                );
              }
              if (_capabilityError != null) {
                _showCapabilityError(context, l);
              }
              final catalog = _capabilityCatalog;
              if (catalog == null) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  _CapabilityCatalogSection(
                    title: l.demoDshTools,
                    items: catalog.tools,
                    emptyText: _capabilityStatusConfirmed
                        ? l.demoDshNotConnected
                        : l.demoDshUnconfirmed,
                    sectionKey: 'tools',
                    statusConfirmed: _capabilityStatusConfirmed,
                  ),
                  const SizedBox(height: 12),
                  _CapabilityCatalogSection(
                    title: l.demoDshSkills,
                    items: catalog.skills,
                    emptyText: _capabilityStatusConfirmed
                        ? l.demoDshNotConnected
                        : l.demoDshUnconfirmed,
                    sectionKey: 'skills',
                    statusConfirmed: _capabilityStatusConfirmed,
                  ),
                  const SizedBox(height: 12),
                  _CapabilityCatalogSection(
                    title: l.demoDshMcp,
                    items: catalog.mcp,
                    emptyText: _capabilityStatusConfirmed
                        ? l.demoDshNotConnected
                        : l.demoDshUnconfirmed,
                    sectionKey: 'mcp',
                    statusConfirmed: _capabilityStatusConfirmed,
                  ),
                ],
              );
            },
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        sliver: SliverToBoxAdapter(
          child: Material(
            color: demoSurface(context),
            borderRadius: BorderRadius.circular(_cardRadius),
            child: InkWell(
              key: const Key('demo-work-mode'),
              borderRadius: BorderRadius.circular(_cardRadius),
              onTap: () => _workMode(context, session),
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.demoWorkMode,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Text(
                        _workModeLabel(l, session.workMode),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const RotatedBox(
                        quarterTurns: 3,
                        child: DemoIcon(
                          'back',
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  void _showCapabilityError(BuildContext context, AppLocalizations l) {
    if (_capabilityErrorShown) return;
    _capabilityErrorShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppToast.error(context, l.demoStorageError);
    });
  }

  Future<void> _workMode(BuildContext context, DemoSession session) async {
    await DemoSheet.show<void>(
      context: context,
      builder: (_) =>
          _WorkModeSheet(repository: widget.repository, session: session),
    );
  }

  Future<void> _roles(BuildContext context, DemoSession session) async {
    await DemoSheet.show<void>(
      context: context,
      builder: (_) =>
          _RoleSheet(repository: widget.repository, session: session),
    );
  }

  Future<void> _editMember(
    BuildContext context,
    String sessionId,
    String memberId,
  ) async {
    await DemoSheet.show<void>(
      context: context,
      builder: (_) => _EditMemberSheet(
        repository: widget.repository,
        sessionId: sessionId,
        memberId: memberId,
      ),
    );
  }

  Future<void> _editRoleProfile(
    BuildContext context,
    String sessionId,
    String roleId,
  ) => DemoSheet.show<void>(
    context: context,
    builder: (_) => _RoleProfileSheet(
      repository: widget.repository,
      sessionId: sessionId,
      roleId: roleId,
    ),
  );

  Future<void> _editPreferences(BuildContext context, DemoSession session) =>
      DemoSheet.show<void>(
        context: context,
        builder: (_) => _PreferencesSheet(
          repository: widget.repository,
          sessionId: session.id,
        ),
      );
}

class _KeepTab extends StatefulWidget {
  const _KeepTab({required this.child});

  final Widget child;

  @override
  State<_KeepTab> createState() => _KeepTabState();
}

class _KeepTabState extends State<_KeepTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

bool _roleIsConfigured(DemoRoleProfile? profile) => profile?.isReady ?? false;

class _RoleProfileRow extends StatelessWidget {
  const _RoleProfileRow({
    required this.repository,
    required this.session,
    required this.roleId,
    required this.onTap,
  });

  final DemoRepository repository;
  final DemoSession session;
  final String roleId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final profile = session.roleProfiles[roleId];
    final role = demoCharacter(roleId);
    final configured = _roleIsConfigured(profile);
    final referenceAssets =
        profile?.referenceAssetIds
            .map(
              (id) => repository.assets
                  .where((asset) => asset.id == id)
                  .firstOrNull,
            )
            .whereType<DemoAsset>()
            .take(2)
            .toList() ??
        const <DemoAsset>[];
    return InkWell(
      key: ValueKey('demo-role-profile-$roleId'),
      borderRadius: BorderRadius.circular(_cardRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            DemoContentRoleAvatar(
              repository: repository,
              session: session,
              roleId: roleId,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.name.trim().isNotEmpty == true
                        ? profile!.name
                        : role.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    configured ? l.demoRoleConfigured : l.demoRolePending,
                    style: TextStyle(
                      fontSize: 12,
                      color: configured
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            for (final asset in referenceAssets)
              Align(
                widthFactor: .7,
                child: ClipOval(
                  child: DemoAssetImage(
                    asset: asset,
                    width: 34,
                    height: 34,
                    cacheWidth: 102,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const RotatedBox(
              quarterTurns: 3,
              child: DemoIcon('back', size: 18, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.session,
    required this.memberId,
    required this.onEdit,
    super.key,
  });

  final DemoSession session;
  final String memberId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              Semantics(
                label: l.demoEditMember,
                button: true,
                child: InkWell(
                  key: ValueKey('demo-edit-member-$memberId'),
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: _memberAvatar(session, memberId, 46),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      demoSessionMemberName(l, session, memberId),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              InkWell(
                key: ValueKey('demo-open-member-$memberId'),
                customBorder: const CircleBorder(),
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: DemoIcon(
                      'back',
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
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

class _TintButton extends StatelessWidget {
  const _TintButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final disabledColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: enabled
              ? demoTint
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: enabled ? AppColors.brand : disabledColor,
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          disabledForegroundColor: disabledColor,
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        icon: DemoIcon(
          'plus',
          size: 16,
          color: enabled ? AppColors.brand : disabledColor,
        ),
        label: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

String _workModeLabel(AppLocalizations l, String mode) => switch (mode) {
  'automatic' => l.demoWorkModeAutomatic,
  'manual' => l.demoWorkModeManual,
  _ => l.demoWorkModeOnDemand,
};

String _capabilitySignature(DemoSession session) {
  final memberCapabilities = session.memberCapabilities.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [
    session.workMode,
    session.activeMemberId,
    session.members.join(','),
    session.capabilities.join(','),
    for (final entry in memberCapabilities)
      '${entry.key}:${entry.value.join(',')}',
  ].join('|');
}

class _CapabilityCatalogSection extends StatelessWidget {
  const _CapabilityCatalogSection({
    required this.title,
    required this.items,
    required this.emptyText,
    required this.sectionKey,
    required this.statusConfirmed,
  });

  final String title;
  final List<DemoRuntimeCapability> items;
  final String emptyText;
  final String sectionKey;
  final bool statusConfirmed;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('demo-dsh-$sectionKey'),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    decoration: BoxDecoration(
      color: demoSurface(context),
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              emptyText,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
          )
        else
          for (final item in items)
            _RuntimeCapabilityRow(
              item: item,
              sectionKey: sectionKey,
              statusConfirmed: statusConfirmed,
            ),
      ],
    ),
  );
}

class _RuntimeCapabilityRow extends StatelessWidget {
  const _RuntimeCapabilityRow({
    required this.item,
    required this.sectionKey,
    required this.statusConfirmed,
  });

  final DemoRuntimeCapability item;
  final String sectionKey;
  final bool statusConfirmed;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('demo-dsh-$sectionKey-${item.id}'),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(fontSize: 15)),
              if (item.description.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
              if (item.source.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.source,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                _runtimeCapabilityStatus(
                  AppLocalizations.of(context)!,
                  item,
                  statusConfirmed: statusConfirmed,
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: statusConfirmed && item.available
                      ? AppColors.success
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          statusConfirmed
              ? item.available
                    ? Icons.check_circle
                    : Icons.remove_circle_outline
              : Icons.help_outline,
          size: 20,
          color: statusConfirmed && item.available
              ? AppColors.success
              : AppColors.textTertiary,
        ),
      ],
    ),
  );
}

String _runtimeCapabilityStatus(
  AppLocalizations l,
  DemoRuntimeCapability item, {
  required bool statusConfirmed,
}) {
  if (!statusConfirmed) return l.demoDshUnconfirmed;
  if (item.available) return l.demoEnabledHere;
  if (!item.bound) return l.demoDshNotConnected;
  if (!item.granted) return l.demoDshNotGranted;
  return l.demoDshUnavailable;
}

Widget _field(String label, String value) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 6),
    Text(value, style: const TextStyle(fontSize: 14, height: 1.45)),
  ],
);

String _configuredValue(AppLocalizations l, String value) =>
    value.trim().isEmpty ? l.demoNotConfigured : value.trim();

Widget _section(
  BuildContext context, {
  required String title,
  String? subtitle,
  required VoidCallback onEdit,
  required List<Widget> children,
}) => Container(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
  decoration: BoxDecoration(
    color: demoSurface(context),
    borderRadius: BorderRadius.circular(_cardRadius),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: title,
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const RotatedBox(
              quarterTurns: 1,
              child: DemoIcon('edit', size: 18),
            ),
          ),
        ],
      ),
      if (subtitle != null) ...[
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
      ],
      const Divider(height: 12),
      ...children,
    ],
  ),
);

DemoCharacter demoCharacter(String id) =>
    DemoFixtures.characters.where((role) => role.id == id).firstOrNull ??
    DemoCharacter(
      id,
      id.startsWith('custom:') ? id.substring(7) : id,
      'assets/images/demo_role_1.png',
    );

Widget _memberAvatar(DemoSession session, String id, double size) => DemoAvatar(
  members: [id],
  size: size,
  memberAvatars: session.memberAvatars,
  memberColors: session.memberColors,
);

class _RoleSheet extends StatefulWidget {
  const _RoleSheet({required this.repository, required this.session});

  final DemoRepository repository;
  final DemoSession session;

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  static const _limit = 5;
  late final List<String> _selected = [...widget.session.roles];
  int _tab = 0;
  bool _busy = false;

  List<String> get _customRoleIds => widget.repository.sessions
      .expand((session) => session.roles)
      .where((id) => id.startsWith('custom:'))
      .toSet()
      .toList();

  DemoSession _sourceSession(String roleId) =>
      widget.repository.sessions
          .where((session) => session.roleProfiles.containsKey(roleId))
          .firstOrNull ??
      widget.repository.session(widget.session.id);

  DemoRoleProfile? _sourceProfile(String roleId) =>
      _sourceSession(roleId).roleProfiles[roleId] ??
      DemoWebsiteCharacterCatalog.profile(roleId);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final roleIds = _tab == 0
        ? DemoFixtures.characters.map((role) => role.id).toList()
        : _customRoleIds;
    return DemoSheetBody(
      title: l.demoLinkedRoles,
      footer: PopScope(
        canPop: !_busy,
        child: DemoPrimaryButton(
          key: const Key('demo-roles-confirm'),
          label: l.demoJoin,
          busy: _busy,
          onPressed: _save,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DemoSegments(
                  labels: [l.demoOfficialRoles, l.demoMyRoles],
                  selected: _tab,
                  onChanged: (value) => setState(() => _tab = value),
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                key: const Key('demo-create-role'),
                style: TextButton.styleFrom(
                  backgroundColor: demoTint,
                  shape: const StadiumBorder(),
                ),
                onPressed: _busy ? null : _createRole,
                icon: const DemoIcon('plus', size: 16, color: AppColors.brand),
                label: Text(
                  l.demoCreateRole,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: roleIds.isEmpty
                ? Center(child: Text(l.demoNoRoles))
                : LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      key: ValueKey('demo-role-grid-$_tab'),
                      padding: const EdgeInsets.only(bottom: 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        mainAxisExtent: (constraints.maxWidth - 16) / 3 + 30,
                      ),
                      itemCount: roleIds.length,
                      itemBuilder: (context, index) {
                        final roleId = roleIds[index];
                        final role = demoCharacter(roleId);
                        final profile = _sourceProfile(roleId);
                        final selected = _selected.contains(roleId);
                        return Material(
                          key: ValueKey('demo-role-option-$roleId'),
                          color: selected ? demoTint : Colors.transparent,
                          borderRadius: BorderRadius.circular(_cardRadius),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(_cardRadius),
                            onTap: _busy ? null : () => _toggle(roleId),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, avatarBox) =>
                                                Center(
                                                  child: DemoContentRoleAvatar(
                                                    repository:
                                                        widget.repository,
                                                    session: _sourceSession(
                                                      roleId,
                                                    ),
                                                    roleId: roleId,
                                                    size: avatarBox
                                                        .biggest
                                                        .shortestSide,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              profile?.name.trim().isNotEmpty ==
                                                      true
                                                  ? profile!.name
                                                  : role.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            key: ValueKey(
                                              'demo-role-profile-link-$roleId',
                                            ),
                                            onTap: () => _profile(
                                              context,
                                              role,
                                              profile ??
                                                  DemoWebsiteCharacterCatalog.profile(
                                                    roleId,
                                                  ),
                                              l,
                                            ),
                                            child: Text(
                                              '${l.demoProfileLink} ›',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: DemoSelectionMark(
                                    selected: selected,
                                    number: selected
                                        ? _selected.indexOf(roleId) + 1
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _toggle(String id) {
    final selected = _selected.contains(id);
    if (!selected && _selected.length >= _limit) return;
    setState(() {
      selected ? _selected.remove(id) : _selected.add(id);
    });
  }

  Future<void> _createRole() async {
    final roleId = await showDemoDiyRoleSheet(
      context,
      widget.repository,
      widget.session.id,
    );
    if (!mounted || roleId == null) return;
    final latest = widget.repository.session(widget.session.id);
    setState(() {
      _selected
        ..clear()
        ..addAll(latest.roles);
      _tab = 1;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final saved = await demoPerform(
      context,
      () => widget.repository.updateSession(
        widget.session.id,
        (session) => session.copyWith(
          roles: [..._selected],
          roleProfiles: {
            for (final roleId in _selected)
              roleId:
                  session.roleProfiles[roleId] ??
                  _sourceProfile(roleId) ??
                  DemoRoleProfile(name: demoCharacter(roleId).name),
          },
        ),
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  void _profile(
    BuildContext context,
    DemoCharacter role,
    DemoRoleProfile? profile,
    AppLocalizations l,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DemoScaffold(
        title: Text(l.demoRoleProfile),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Image.asset(role.image, height: 300, fit: BoxFit.contain),
            const SizedBox(height: 20),
            Text(
              profile?.name.trim().isNotEmpty == true
                  ? profile!.name
                  : role.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Text(
              profile?.instructions.trim().isNotEmpty == true
                  ? profile!.instructions
                  : l.demoRoleBio,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoleProfileSheet extends StatefulWidget {
  const _RoleProfileSheet({
    required this.repository,
    required this.sessionId,
    required this.roleId,
  });

  final DemoRepository repository;
  final String sessionId;
  final String roleId;

  @override
  State<_RoleProfileSheet> createState() => _RoleProfileSheetState();
}

class _RoleProfileSheetState extends State<_RoleProfileSheet> {
  late final DemoRoleProfile _original =
      widget.repository.session(widget.sessionId).roleProfiles[widget.roleId] ??
      DemoWebsiteCharacterCatalog.profile(widget.roleId) ??
      DemoRoleProfile(name: demoCharacter(widget.roleId).name);
  late final TextEditingController _name = TextEditingController(
    text: _original.name.isNotEmpty
        ? _original.name
        : demoCharacter(widget.roleId).name,
  );
  late final TextEditingController _instructions = TextEditingController(
    text: _original.instructions,
  );
  late final TextEditingController _referenceUrls = TextEditingController(
    text: _original.referenceImageUrls.join('\n'),
  );
  late final List<String> _referenceAssetIds = [..._original.referenceAssetIds];
  bool _busy = false;

  List<String> get _parsedUrls => _referenceUrls.text
      .split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  bool get _urlsAreValid =>
      _parsedUrls.length <= 5 &&
      _parsedUrls.every((value) {
        final uri = Uri.tryParse(value);
        return uri != null &&
            uri.hasAuthority &&
            (uri.scheme == 'https' || uri.scheme == 'http');
      });

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      (_instructions.text.trim().isNotEmpty ||
          _referenceAssetIds.isNotEmpty ||
          _parsedUrls.isNotEmpty) &&
      _urlsAreValid;

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    _referenceUrls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: DemoSheetBody(
        title: l.demoRoleProfile,
        footer: DemoPrimaryButton(
          key: const Key('demo-role-profile-confirm'),
          label: l.confirm,
          busy: _busy,
          onPressed: _canSave && !_busy ? _save : null,
        ),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Text(l.demoName, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('demo-role-profile-name'),
              controller: _name,
              enabled: !_busy,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: _profileInputDecoration(),
            ),
            const SizedBox(height: 14),
            Text(l.demoRoleInstructions, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('demo-role-profile-instructions'),
              controller: _instructions,
              enabled: !_busy,
              minLines: 6,
              maxLines: 12,
              maxLength: 12000,
              onChanged: (_) => setState(() {}),
              decoration: _profileInputDecoration(
                hintText: l.demoRoleInstructionsHint,
              ),
            ),
            const SizedBox(height: 14),
            Text(l.demoReferenceImages, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              l.demoReferenceImagesHint,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 10),
            if (_referenceAssetIds.isNotEmpty)
              Wrap(
                key: const Key('demo-role-reference-assets'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in _referenceAssetIds)
                    _ReferenceAssetChip(
                      asset: widget.repository.assets
                          .where((asset) => asset.id == id)
                          .firstOrNull,
                      assetId: id,
                      onRemove: _busy
                          ? null
                          : () => setState(() => _referenceAssetIds.remove(id)),
                    ),
                ],
              ),
            if (_referenceAssetIds.isNotEmpty) const SizedBox(height: 10),
            _TintButton(
              key: const Key('demo-add-reference-image'),
              label: l.demoAddReferenceImage,
              onPressed: _busy || _referenceAssetIds.length >= 5
                  ? null
                  : _selectReferenceAsset,
            ),
            const SizedBox(height: 14),
            Text(
              l.demoReferenceImageUrls,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('demo-role-reference-urls'),
              controller: _referenceUrls,
              enabled: !_busy,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration:
                  _profileInputDecoration(
                    hintText: l.demoReferenceImageUrlsHint,
                  ).copyWith(
                    errorText: _urlsAreValid
                        ? null
                        : l.demoReferenceImageUrlsHint,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _profileInputDecoration({String? hintText}) =>
      InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: demoTint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      );

  Future<void> _save() async {
    if (!_canSave || _busy) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final instructions = _instructions.text.trim();
    final referenceAssetIds = [..._referenceAssetIds];
    final referenceImageUrls = [..._parsedUrls];
    final changed =
        name != _original.name ||
        instructions != _original.instructions ||
        !_sameStrings(referenceAssetIds, _original.referenceAssetIds) ||
        !_sameStrings(referenceImageUrls, _original.referenceImageUrls);
    final revision = changed || _original.revision.isEmpty
        ? 'ui-${DateTime.now().microsecondsSinceEpoch}'
        : _original.revision;
    final saved = await demoPerform(
      context,
      () => widget.repository.updateSession(
        widget.sessionId,
        (session) => session.copyWith(
          roleProfiles: {
            ...session.roleProfiles,
            widget.roleId: _original.copyWith(
              name: name,
              instructions: instructions,
              revision: revision,
              referenceAssetIds: referenceAssetIds,
              referenceImageUrls: referenceImageUrls,
            ),
          },
        ),
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _selectReferenceAsset() async {
    final selected = await DemoSheet.show<DemoAsset>(
      context: context,
      builder: (_) => _ReferenceAssetSheet(
        repository: widget.repository,
        excludedIds: _referenceAssetIds.toSet(),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _referenceAssetIds.add(selected.id));
  }
}

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

class _ReferenceAssetChip extends StatelessWidget {
  const _ReferenceAssetChip({
    required this.asset,
    required this.assetId,
    required this.onRemove,
  });

  final DemoAsset? asset;
  final String assetId;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: asset == null
            ? Container(
                width: 72,
                height: 72,
                color: demoTint,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported_outlined),
              )
            : DemoAssetImage(
                asset: asset!,
                width: 72,
                height: 72,
                cacheWidth: 216,
                fit: BoxFit.cover,
              ),
      ),
      Positioned(
        right: 2,
        top: 2,
        child: IconButton(
          key: ValueKey('demo-remove-reference-$assetId'),
          tooltip: AppLocalizations.of(context)!.cancel,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            foregroundColor: Colors.white,
            fixedSize: const Size.square(24),
            minimumSize: const Size.square(24),
            maximumSize: const Size.square(24),
            padding: EdgeInsets.zero,
          ),
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 15),
        ),
      ),
    ],
  );
}

class _ReferenceAssetSheet extends StatelessWidget {
  const _ReferenceAssetSheet({
    required this.repository,
    required this.excludedIds,
  });

  final DemoRepository repository;
  final Set<String> excludedIds;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final assets = repository.assets
        .where(
          (asset) =>
              asset.kind == DemoAssetKind.image &&
              !excludedIds.contains(asset.id),
        )
        .toList();
    return DemoSheetBody(
      title: l.demoReferenceImages,
      child: assets.isEmpty
          ? Center(child: Text(l.demoNoResults))
          : GridView.builder(
              key: const Key('demo-reference-asset-grid'),
              padding: const EdgeInsets.only(bottom: 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .88,
              ),
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final asset = assets[index];
                return Material(
                  color: demoSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('demo-reference-asset-${asset.id}'),
                    onTap: () => Navigator.of(context).pop(asset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DemoAssetImage(
                            asset: asset,
                            width: double.infinity,
                            height: double.infinity,
                            cacheWidth: 480,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            asset.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.repository, required this.sessionId});

  final DemoRepository repository;
  final String sessionId;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late final DemoSession _original = widget.repository.session(
    widget.sessionId,
  );
  late final TextEditingController _direction = TextEditingController(
    text: _original.direction,
  );
  late final TextEditingController _positioning = TextEditingController(
    text: _original.positioning,
  );
  late final TextEditingController _feeling = TextEditingController(
    text: _original.accountPreferences['feeling'] ?? '',
  );
  late final TextEditingController _format = TextEditingController(
    text: _original.accountPreferences['format'] ?? '',
  );
  late final TextEditingController _audience = TextEditingController(
    text: _original.accountPreferences['audience'] ?? '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _direction.dispose();
    _positioning.dispose();
    _feeling.dispose();
    _format.dispose();
    _audience.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: DemoSheetBody(
        title: l.demoPreferences,
        footer: DemoPrimaryButton(
          key: const Key('demo-preferences-confirm'),
          label: l.confirm,
          busy: _busy,
          onPressed: _busy ? null : _save,
        ),
        child: ListView(
          key: const Key('demo-preferences-form'),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Text(
              l.demoContextPreferencesHint,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            _PreferenceInput(
              fieldKey: const Key('demo-preference-direction'),
              label: l.demoDirection,
              controller: _direction,
              enabled: !_busy,
            ),
            _PreferenceInput(
              fieldKey: const Key('demo-preference-positioning'),
              label: l.demoPositioning,
              controller: _positioning,
              enabled: !_busy,
            ),
            _PreferenceInput(
              fieldKey: const Key('demo-preference-feeling'),
              label: l.demoFeeling,
              controller: _feeling,
              enabled: !_busy,
            ),
            _PreferenceInput(
              fieldKey: const Key('demo-preference-format'),
              label: l.demoFormat,
              controller: _format,
              enabled: !_busy,
            ),
            _PreferenceInput(
              fieldKey: const Key('demo-preference-audience'),
              label: l.demoAudience,
              controller: _audience,
              enabled: !_busy,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final saved = await demoPerform(
      context,
      () => widget.repository.updateSession(
        widget.sessionId,
        (session) => session.copyWith(
          direction: _direction.text.trim(),
          positioning: _positioning.text.trim(),
          accountPreferences: {
            ...session.accountPreferences,
            'feeling': _feeling.text.trim(),
            'format': _format.text.trim(),
            'audience': _audience.text.trim(),
          },
        ),
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }
}

class _PreferenceInput extends StatelessWidget {
  const _PreferenceInput({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.demoNotConfigured,
            filled: true,
            fillColor: demoTint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );
}

class _WorkModeSheet extends StatefulWidget {
  const _WorkModeSheet({required this.repository, required this.session});

  final DemoRepository repository;
  final DemoSession session;

  @override
  State<_WorkModeSheet> createState() => _WorkModeSheetState();
}

class _WorkModeSheetState extends State<_WorkModeSheet> {
  late String _selected = widget.session.workMode;
  late String _activeMemberId =
      widget.session.members.contains(widget.session.activeMemberId)
      ? widget.session.activeMemberId
      : widget.session.members.first;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const modes = ['automatic', 'manual', 'onDemand'];
    return DemoSheetBody(
      title: l.demoEditWorkMode,
      footer: PopScope(
        canPop: !_busy,
        child: DemoPrimaryButton(
          key: const Key('demo-work-mode-confirm'),
          label: l.confirm,
          busy: _busy,
          onPressed: _save,
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: modes.length + (_selected == 'manual' ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == modes.length) {
            return Container(
              key: const Key('demo-active-member-picker'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: demoSurface(context),
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.demoActiveMember,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final memberId in widget.session.members)
                    InkWell(
                      key: ValueKey('demo-active-member-$memberId'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: _busy
                          ? null
                          : () => setState(() => _activeMemberId = memberId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            _memberAvatar(widget.session, memberId, 36),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                demoSessionMemberName(
                                  l,
                                  widget.session,
                                  memberId,
                                ),
                              ),
                            ),
                            DemoSelectionMark(
                              selected: _activeMemberId == memberId,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
          final mode = modes[index];
          final selected = mode == _selected;
          return Material(
            color: selected ? demoTint : Colors.transparent,
            borderRadius: BorderRadius.circular(_cardRadius),
            child: InkWell(
              key: ValueKey('demo-work-mode-$mode'),
              borderRadius: BorderRadius.circular(_cardRadius),
              onTap: _busy ? null : () => setState(() => _selected = mode),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _workModeLabel(l, mode),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    DemoSelectionMark(selected: selected),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final saved = await demoPerform(
      context,
      () => widget.repository.updateSession(
        widget.session.id,
        (session) => session.copyWith(
          workMode: _selected,
          activeMemberId: _selected == 'manual'
              ? _activeMemberId
              : session.activeMemberId,
        ),
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }
}

class _EditMemberSheet extends StatefulWidget {
  const _EditMemberSheet({
    required this.repository,
    required this.sessionId,
    required this.memberId,
  });

  final DemoRepository repository;
  final String sessionId;
  final String memberId;

  @override
  State<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<_EditMemberSheet> {
  static const _colors = [
    0xFFFFFFFF,
    0xFFE4DCFE,
    0xFFD6E8FF,
    0xFFCFF4F6,
    0xFFD6F5E1,
    0xFFFCDCCE,
    0xFFFFDFEF,
    0xFFDCE4FB,
  ];

  late final _name = TextEditingController();
  late final _session = widget.repository.session(widget.sessionId);
  late String _image = DemoFixtures.memberImage(
    widget.memberId,
    savedImage: _session.memberAvatars[widget.memberId],
  );
  late int _color = _session.memberColors[widget.memberId] ?? 0xFFFFDFEF;
  bool _initialized = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _name.text = demoSessionMemberName(
      AppLocalizations.of(context)!,
      _session,
      widget.memberId,
    );
    _initialized = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DemoSheetBody(
      title: l.demoEditMember,
      footer: PopScope(
        canPop: !_busy,
        child: DemoPrimaryButton(
          key: const Key('demo-member-edit-confirm'),
          label: l.confirm,
          busy: _busy,
          onPressed: _name.text.trim().isEmpty ? null : _save,
        ),
      ),
      child: CustomScrollView(
        key: const Key('demo-edit-member-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: DemoAvatar(
                    image: _image,
                    size: 80,
                    background: Color(_color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  demoSessionMemberName(l, _session, widget.memberId),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  demoMemberDescription(l, widget.memberId),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l.demoMyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('demo-member-name'),
                  controller: _name,
                  maxLength: 10,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: demoTint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    suffixIcon: Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Text(
                          '${_name.text.characters.length}/10',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      l.demoMyAppearance,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _busy ? null : _randomizeAvatar,
                      child: Text(
                        l.demoRandomAppearance,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 60,
            ),
            itemCount: BotAvatarCharacter.values.length,
            itemBuilder: (context, index) {
              final character = BotAvatarCharacter.values[index];
              return Semantics(
                key: ValueKey('demo-avatar-${character.name}'),
                label: l.demoAvatarNumber(index + 1),
                selected: _image == character.stillAsset,
                button: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _busy
                      ? null
                      : () => setState(() => _image = character.stillAsset),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _image == character.stillAsset
                            ? const Color(0xFFE9E3F8)
                            : Colors.transparent,
                        width: 4,
                      ),
                    ),
                    child: Image.asset(
                      character.stillAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  l.demoBackgroundColor,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final color in _colors)
                      Semantics(
                        label: l.demoBackgroundColor,
                        selected: _color == color,
                        button: true,
                        child: InkWell(
                          key: ValueKey('demo-member-color-$color'),
                          customBorder: const CircleBorder(),
                          onTap: _busy
                              ? null
                              : () => setState(() => _color = color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: color == 0xFFFFFFFF
                                  ? Border.all(color: const Color(0xFFE5E5E5))
                                  : null,
                            ),
                            child: _color == color
                                ? const Center(
                                    child: DemoIcon(
                                      'check',
                                      size: 18,
                                      color: AppColors.brand,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _randomizeAvatar() {
    const characters = BotAvatarCharacter.values;
    final current = characters.indexWhere(
      (character) => character.stillAsset == _image,
    );
    setState(() {
      _image = characters[(current + 1) % characters.length].stillAsset;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final saved = await demoPerform(
      context,
      () => widget.repository.updateSession(
        widget.sessionId,
        (session) => session.copyWith(
          memberNames: {
            ...session.memberNames,
            widget.memberId: _name.text.trim(),
          },
          memberAvatars: {...session.memberAvatars, widget.memberId: _image},
          memberColors: {...session.memberColors, widget.memberId: _color},
        ),
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }
}
