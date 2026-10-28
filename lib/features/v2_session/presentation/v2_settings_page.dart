import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/type/bot_avatar_type.dart';
import '../../../shared/widgets/app_page_safe_area.dart';
import '../../v2_shared/data/v2_fixtures.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_models.dart';
import '../../v2_assets/presentation/v2_assets_page.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';

class V2SettingsPage extends StatefulWidget {
  const V2SettingsPage({
    required this.repository,
    required this.sessionId,
    super.key,
  });
  final V2Repository repository;
  final String sessionId;
  @override
  State<V2SettingsPage> createState() => _V2SettingsPageState();
}

class _V2SettingsPageState extends State<V2SettingsPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this)
    ..addListener(_updateTab);
  void _updateTab() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final s = widget.repository.session(widget.sessionId);
        return V2Scaffold(
          title: Text(l.demoSettings),
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppPageSafeArea.horizontalPaddingOf(
                    context,
                  ).copyWith(top: 10, bottom: 20),
                  child: _SettingsCard(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        V2Avatar(
                          members: s.members,
                          memberAvatars: s.memberAvatars,
                          memberColors: s.memberColors,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l.demoRename,
                          onPressed: () => v2EditText(
                            context,
                            title: l.demoRename,
                            value: s.title,
                            onSave: (v) => widget.repository.updateSession(
                              s.id,
                              (s) => s.copyWith(title: v),
                            ),
                          ),
                          icon: const RotatedBox(
                            quarterTurns: 1,
                            child: V2Icon('edit', size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: V2PinnedHeader(
                  height: 60,
                  child: Padding(
                    padding: AppPageSafeArea.horizontalPaddingOf(
                      context,
                    ).copyWith(bottom: 20),
                    child: V2Segments(
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
                _KeepTab(child: _info(context, s, l)),
                _KeepTab(child: _capabilities(context, s, l)),
                _KeepTab(
                  child: V2AssetsView(
                    repository: widget.repository,
                    sessionId: s.id,
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

  Widget _info(
    BuildContext context,
    V2Session s,
    AppLocalizations l,
  ) => ListView(
    key: const PageStorageKey('demo-settings-info'),
    padding: AppPageSafeArea.horizontalPaddingOf(
      context,
    ).copyWith(bottom: math.max(MediaQuery.paddingOf(context).bottom, 20.0)),
    children: [
      _SettingsCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l.demoLinkedRoles,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            s.roles.isEmpty ? l.demoNoRoles : l.demoRoleCount(s.roles.length),
            style: const TextStyle(color: AppColors.textTertiary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final role in s.roles.take(3))
                Align(
                  widthFactor: .65,
                  child: V2Avatar(image: v2Character(role).image, size: 50),
                ),
              const SizedBox(width: 12),
              const RotatedBox(
                quarterTurns: 3,
                child: V2Icon('back', size: 24, color: AppColors.textTertiary),
              ),
            ],
          ),
          onTap: () => _roles(context, s),
        ),
      ),
      const SizedBox(height: 20),
      _section(
        context,
        title: l.demoPreferences,
        onEdit: () => v2EditText(
          context,
          title: l.demoDirection,
          value: s.direction,
          multiline: true,
          onSave: (v) => widget.repository.updateSession(
            s.id,
            (s) => s.copyWith(direction: v),
          ),
        ),
        children: [
          _field(
            l.demoDirection,
            s.direction.isEmpty ? V2Fixtures.direction : s.direction,
          ),
          const Divider(height: 30),
          _field(l.demoFeeling, l.demoFeelingValue),
          const Divider(height: 30),
          _field(l.demoFormat, l.demoFormatValue),
          const Divider(height: 30),
          _field(l.demoAudience, l.demoAudienceValue),
        ],
      ),
      const SizedBox(height: 20),
      _section(
        context,
        title: l.demoPositioning,
        onEdit: () => v2EditText(
          context,
          title: l.demoPositioning,
          value: s.positioning.isEmpty ? V2Fixtures.positioning : s.positioning,
          multiline: true,
          onSave: (v) => widget.repository.updateSession(
            s.id,
            (s) => s.copyWith(positioning: v),
          ),
        ),
        children: [
          Text(
            s.positioning.isEmpty ? V2Fixtures.positioning : s.positioning,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    ],
  );

  Widget _capabilities(BuildContext context, V2Session s, AppLocalizations l) =>
      CustomScrollView(
        key: const PageStorageKey('demo-settings-skills'),
        slivers: [
          SliverPadding(
            padding: AppPageSafeArea.horizontalPaddingOf(context).copyWith(
              bottom: math.max(MediaQuery.paddingOf(context).bottom, 20.0),
            ),
            sliver: SliverToBoxAdapter(
              child: _SettingsCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    for (final id in s.members) ...[
                      InkWell(
                        onTap: () => V2Sheet.show<void>(
                          context: context,
                          builder: (_) => _EditMemberSheet(
                            repository: widget.repository,
                            sessionId: s.id,
                            memberId: id,
                          ),
                        ),
                        child: SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              _memberAvatar(s, id, 50),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s.memberNames[id] ?? v2MemberName(l, id),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const RotatedBox(
                                quarterTurns: 3,
                                child: V2Icon(
                                  'back',
                                  size: 24,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: v2Tint,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _members(context, s),
                        icon: const V2Icon(
                          'plus',
                          size: 18,
                          color: AppColors.brand,
                        ),
                        label: Text(l.demoAddMembers),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: AppPageSafeArea.horizontalPaddingOf(
              context,
            ).copyWith(bottom: 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.demoEnabledItems,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    l.demoEnabledHere,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: AppPageSafeArea.horizontalPaddingOf(
              context,
            ).copyWith(bottom: 20),
            sliver: SliverToBoxAdapter(
              child: _SettingsCard(
                child: Column(
                  children: [
                    for (final entry in _skillLabels(l).entries)
                      _CapabilityRow(
                        title: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _skillDescription(l, entry.key),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        value: s.capabilities.contains(entry.key),
                        onChanged: (value) => v2Perform(
                          context,
                          () => widget.repository.updateSession(
                            s.id,
                            (s) => s.copyWith(
                              capabilities: value
                                  ? [...s.capabilities, entry.key]
                                  : s.capabilities
                                        .where((k) => k != entry.key)
                                        .toList(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Future<void> _members(BuildContext context, V2Session session) =>
      V2Sheet.show<void>(
        context: context,
        builder: (_) =>
            _MemberSheet(repository: widget.repository, session: session),
      );
  Future<void> _roles(BuildContext context, V2Session session) =>
      V2Sheet.show<void>(
        context: context,
        builder: (_) =>
            _RoleSheet(repository: widget.repository, session: session),
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

Map<String, String> _skillLabels(AppLocalizations l) => {
  'character': l.demoCharacterSkill,
  'script': l.demoScriptSkill,
  'image': l.demoImageSkill,
  'video': l.demoVideoSkill,
  'audio': l.demoAudioSkill,
};
String _skillDescription(AppLocalizations l, String id) => switch (id) {
  'character' => l.demoCharacterDetail,
  'script' => l.demoScriptDetail,
  'image' => l.demoImageDetail,
  'video' => l.demoVideoDetail,
  _ => l.demoAudioDetail,
};

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final Widget title;
  final Widget subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 5), subtitle],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            activeTrackColor: const Color(0xFFCAB9FB),
            inactiveTrackColor: const Color(0xFFE4E2E6),
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

Widget _field(String label, String value) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 10),
    Text(value, style: const TextStyle(fontSize: 16, height: 1.45)),
  ],
);
Widget _section(
  BuildContext context, {
  required String title,
  required VoidCallback onEdit,
  required List<Widget> children,
}) => _SettingsCard(
  padding: const EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: title,
            onPressed: onEdit,
            icon: const RotatedBox(
              quarterTurns: 1,
              child: V2Icon('edit', size: 18),
            ),
          ),
        ],
      ),
      const Divider(height: 30),
      ...children,
    ],
  ),
);

/// Clips the glass to the card while keeping its content and ink effects sharp.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  static final _blur = ImageFilter.blur(sigmaX: 25, sigmaY: 25);
  static const _radius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: _radius,
      child: BackdropFilter(
        filter: _blur,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: _radius,
            color: dark
                ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: .65)
                : Colors.white.withValues(alpha: .5),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: _radius,
            border: Border.all(
              color: dark ? Colors.white.withValues(alpha: .22) : Colors.white,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

V2Character v2Character(String id) =>
    V2Fixtures.characters.where((r) => r.id == id).firstOrNull ??
    V2Character(
      id,
      id.startsWith('custom:') ? id.substring(7) : id,
      'assets/images/demo_role_1.png',
    );

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({required this.repository, required this.session});
  final V2Repository repository;
  final V2Session session;
  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late final _selected = widget.session.members.toSet();
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final members = V2Fixtures.memberImages.keys.toList();
    return V2SheetBody(
      title: l.demoAddMembers,
      footer: V2PrimaryButton(
        label: l.confirm,
        busy: _busy,
        onPressed: _selected.isEmpty
            ? null
            : () async {
                setState(() => _busy = true);
                final ok = await v2Perform(
                  context,
                  () => widget.repository.updateSession(
                    widget.session.id,
                    (s) => s.copyWith(members: _selected.toList()),
                  ),
                );
                if (!context.mounted) return;
                if (ok) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _busy = false);
                }
              },
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.demoSelectMembers, style: const TextStyle(fontSize: 16)),
              Text(
                l.demoSelectedCount(_selected.length, members.length),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 110),
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final id = members[i];
                final selected = _selected.contains(id);
                return Semantics(
                  selected: selected,
                  child: Material(
                    key: ValueKey(id),
                    color: selected ? v2Tint : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _busy
                          ? null
                          : () => setState(() {
                              selected
                                  ? _selected.remove(id)
                                  : _selected.add(id);
                            }),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                _memberAvatar(widget.session, id, 70),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.session.memberNames[id] ??
                                              v2MemberName(l, id),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          v2MemberDescription(l, id),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: V2SelectionMark(selected: selected),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _memberAvatar(V2Session session, String id, double size) => V2Avatar(
  members: [id],
  size: size,
  memberAvatars: session.memberAvatars,
  memberColors: session.memberColors,
);

class _RoleSheet extends StatefulWidget {
  const _RoleSheet({required this.repository, required this.session});
  final V2Repository repository;
  final V2Session session;
  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late final _selected = widget.session.roles.toSet();
  late final _custom = widget.repository.sessions
      .expand((s) => s.roles)
      .where((r) => r.startsWith('custom:'))
      .toSet()
      .map(v2Character)
      .toList();
  int _tab = 0;
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final roles = _tab == 0 ? V2Fixtures.characters : _custom;
    return V2SheetBody(
      title: l.demoLinkedRoles,
      footer: V2PrimaryButton(
        label: l.demoJoin,
        busy: _busy,
        onPressed: () async {
          setState(() => _busy = true);
          final ok = await v2Perform(
            context,
            () => widget.repository.updateSession(
              widget.session.id,
              (s) => s.copyWith(roles: _selected.toList()),
            ),
          );
          if (!context.mounted) return;
          if (ok) {
            Navigator.of(context).pop();
          } else {
            setState(() => _busy = false);
          }
        },
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Flexible(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: _tab == i ? v2Tint : Colors.transparent,
                      foregroundColor: _tab == i
                          ? Theme.of(context).colorScheme.onSurface
                          : AppColors.textTertiary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => setState(() => _tab = i),
                    child: Text(i == 0 ? l.demoOfficialRoles : l.demoMyRoles),
                  ),
                ),
              const SizedBox(width: 10),
              Flexible(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: v2Tint,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => v2EditText(
                    context,
                    title: l.demoCreateRole,
                    label: l.demoName,
                    value: '',
                    onSave: (name) async {
                      final id = 'custom:$name';
                      setState(() {
                        if (!_custom.any((r) => r.id == id)) {
                          _custom.add(v2Character(id));
                        }
                        _selected.add(id);
                        _tab = 1;
                      });
                    },
                  ),
                  icon: const V2Icon('plus', size: 18, color: AppColors.brand),
                  label: Text(l.demoCreateRole),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: roles.isEmpty
                ? Center(child: Text(l.demoNoRoles))
                : LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      padding: const EdgeInsets.only(bottom: 110),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: (constraints.maxWidth - 20) / 3 + 30,
                      ),
                      itemCount: roles.length,
                      itemBuilder: (context, i) {
                        final role = roles[i];
                        final selected = _selected.contains(role.id);
                        return Material(
                          key: ValueKey(role.id),
                          color: selected ? v2Tint : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _busy
                                ? null
                                : () => setState(() {
                                    selected
                                        ? _selected.remove(role.id)
                                        : _selected.add(role.id);
                                  }),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Image.asset(
                                            role.image,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              role.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () =>
                                                _profile(context, role, l),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 3,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    l.demoProfileLink,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: 10,
                                                    height: 14,
                                                    child: RotatedBox(
                                                      quarterTurns: 3,
                                                      child: V2Icon(
                                                        'back',
                                                        size: 14,
                                                        color: AppColors
                                                            .textTertiary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: V2SelectionMark(
                                    selected: selected,
                                    number: selected
                                        ? _selected.toList().indexOf(role.id) +
                                              1
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

  void _profile(BuildContext context, V2Character role, AppLocalizations l) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => V2Scaffold(
            title: Text(l.demoRoleProfile),
            child: ListView(
              padding: AppPageSafeArea.horizontalPaddingOf(context).copyWith(
                top: 20,
                bottom: math.max(MediaQuery.paddingOf(context).bottom, 20.0),
              ),
              children: [
                Image.asset(role.image, height: 300, fit: BoxFit.contain),
                const SizedBox(height: 20),
                Text(
                  role.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l.demoRoleBio,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EditMemberSheet extends StatefulWidget {
  const _EditMemberSheet({
    required this.repository,
    required this.sessionId,
    required this.memberId,
  });
  final V2Repository repository;
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
  late String _image =
      _session.memberAvatars[widget.memberId] ??
      (widget.memberId == 'popi'
          ? BotAvatarCharacter.tiger.stillAsset
          : V2Fixtures.memberImages[widget.memberId]!);
  late int _color = _session.memberColors[widget.memberId] ?? 0xFFFFDFEF;
  bool _initialized = false;
  bool _busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _name.text =
          _session.memberNames[widget.memberId] ??
          v2MemberName(AppLocalizations.of(context)!, widget.memberId);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return V2SheetBody(
      title: l.demoEditMember,
      footer: V2PrimaryButton(
        label: l.confirm,
        busy: _busy,
        onPressed: _name.text.trim().isEmpty
            ? null
            : () async {
                setState(() => _busy = true);
                final ok = await v2Perform(
                  context,
                  () => widget.repository.updateSession(
                    widget.sessionId,
                    (s) => s.copyWith(
                      memberNames: {
                        ...s.memberNames,
                        widget.memberId: _name.text.trim(),
                      },
                      memberAvatars: {
                        ...s.memberAvatars,
                        widget.memberId: _image,
                      },
                      memberColors: {
                        ...s.memberColors,
                        widget.memberId: _color,
                      },
                    ),
                  ),
                );
                if (!context.mounted) return;
                if (ok) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _busy = false);
                }
              },
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                Center(
                  child: V2Avatar(
                    image: _image,
                    size: 100,
                    background: Color(_color),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  v2MemberName(l, widget.memberId),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  v2MemberDescription(l, widget.memberId),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  l.demoMyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  maxLength: 10,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: v2Tint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          '${_name.text.characters.length}/10',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      l.demoMyAppearance,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              const characters = BotAvatarCharacter.values;
                              final current = characters.indexWhere(
                                (character) => character.stillAsset == _image,
                              );
                              _image =
                                  characters[(current + 1) % characters.length]
                                      .stillAsset;
                            }),
                      child: Text(
                        l.demoRandomAppearance,
                        style: const TextStyle(color: AppColors.textTertiary),
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
              childAspectRatio: 1,
            ),
            itemCount: BotAvatarCharacter.values.length,
            itemBuilder: (context, i) {
              final character = BotAvatarCharacter.values[i];
              final path = character.stillAsset;
              return Semantics(
                key: ValueKey('demo-avatar-${character.name}'),
                label: l.demoAvatarNumber(i + 1),
                selected: _image == path,
                button: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _busy ? null : () => setState(() => _image = path),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _image == path
                            ? const Color(0xFFE9E3F8)
                            : Colors.transparent,
                        width: 5,
                      ),
                    ),
                    child: Image.asset(path, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  l.demoBackgroundColor,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final color in _colors)
                      Semantics(
                        label: l.demoBackgroundColor,
                        selected: _color == color,
                        button: true,
                        child: InkWell(
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
                                    child: V2Icon(
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
                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
