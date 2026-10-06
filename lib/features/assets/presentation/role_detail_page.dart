import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../home/presentation/home_page.dart';
import '../data/role_library_repository.dart';
import '../domain/library_role.dart';

class RoleDetailPage extends ConsumerStatefulWidget {
  const RoleDetailPage({super.key, required this.role, required this.category});
  final LibraryRole role;
  final String category;

  @override
  ConsumerState<RoleDetailPage> createState() => _RoleDetailPageState();
}

class _RoleDetailPageState extends ConsumerState<RoleDetailPage> {
  late LibraryRole _role;
  bool _loading = true;
  bool _failed = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _role = widget.role;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final role = await ref.read(roleDetailLoaderProvider)(_role.id);
      if (mounted) setState(() => _role = role);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    if (_deleting || widget.category == 'official' || !_role.canEdit) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.deleteRoleTitle,
      description: l10n.deleteRoleDescription,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.delete,
      confirmKey: const Key('confirm-delete-role'),
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(roleDeleteProvider)(_role.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) AppToast.error(context, l10n.networkRequestFailed);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _compose({required bool improve}) {
    final l10n = AppLocalizations.of(context)!;
    final prompt = improve
        ? l10n.improveRolePrompt(_role.title)
        : l10n.createRolePrompt(_role.title);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HomePage(
          initialPrompt: '$prompt\nID: ${_role.id}\n${_role.description}'),
    ));
  }

  String _text(Object? value) {
    if (value is String) return value.trim();
    if (value is List) {
      return value.map(_text).where((s) => s.isNotEmpty).join(' / ');
    }
    if (value is num || value is bool) return value.toString();
    return '';
  }

  List<(String, String)> _sections(AppLocalizations l10n) {
    final profile = _role.profile;
    final fields = profile['profileData'];
    final details = <String, (String, String)>{};
    if (fields is Map) {
      for (final entry in fields.entries) {
        final field = entry.value;
        if (field is Map && _text(field['label']).isNotEmpty) {
          details[entry.key.toString()] =
              (_text(field['label']), _text(field['value']));
        }
      }
    }
    final result = <(String, String)>[
      (l10n.rolePositioning, _role.description),
      (
        l10n.roleStyle,
        _text(profile['expressionStyle']).isNotEmpty
            ? _text(profile['expressionStyle'])
            : _text(profile['personality'])
      ),
      (l10n.roleAudience, _text(profile['targetAudience'])),
      (l10n.roleTags, _text(profile['contentTags'])),
    ];
    // Preserve server labels and values for custom profile fields.
    for (final entry in details.entries) {
      final index = switch (entry.key) {
        'positioning' || 'description' => 0,
        'expressionStyle' || 'personality' => 1,
        'targetAudience' => 2,
        'contentTags' => 3,
        _ => -1,
      };
      if (index >= 0) {
        result[index] = (result[index].$1, entry.value.$2);
      } else {
        result.add(entry.value);
      }
    }
    if (details.isEmpty && _text(profile['appearance']).isNotEmpty) {
      result.add((l10n.roleAppearance, _text(profile['appearance'])));
    }
    if (!details.keys
        .any((key) => key == 'boundaries' || key == 'expressionBoundaries')) {
      result.add((
        l10n.roleBoundaries,
        _text(profile['boundaries'] ?? profile['expressionBoundaries'])
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    final enabled = !_loading && !_failed && !_deleting;
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        key: const Key('role-detail-page'),
        backgroundColor: light ? const Color(0xFFF5F4FA) : colors.surface,
        appBar: AppBar(
          backgroundColor: light ? const Color(0xFFF5F4FA) : colors.surface,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Text(l10n.roleArchive,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          leading: IconButton(
            key: const Key('role-profile-back'),
            tooltip: l10n.backToPreviousPage,
            onPressed: _deleting ? null : () => Navigator.of(context).pop(),
            icon: Transform.rotate(
              angle: math.pi / 2,
              child: AppSvgIcon.asset('role_profile_back',
                  size: 40, color: colors.onSurface),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              key: const Key('role-profile-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _summary(l10n),
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            if (_failed)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                    onPressed: _load,
                                    icon: const Icon(Icons.refresh),
                                    label: Text(l10n.retryLoadingRoles)),
                              ),
                            const SizedBox(height: 20),
                            for (final section in _sections(l10n))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(section.$1,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              height: 25 / 14)),
                                      const SizedBox(height: 5),
                                      SelectableText(
                                          section.$2.isEmpty
                                              ? l10n.roleFieldPending
                                              : section.$2,
                                          style: TextStyle(
                                              fontSize: 14,
                                              height: 20 / 14,
                                              color: colors.onSurfaceVariant)),
                                    ]),
                              ),
                            const SizedBox(height: 20),
                          ]),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.sizeOf(context).height * .55,
                ),
                child: SingleChildScrollView(
                  child: _actions(l10n, enabled),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
        color: colors.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.person_outline, size: 32)));
    return Container(
      key: const Key('role-profile-summary'),
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      decoration: BoxDecoration(
          color: colors.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
                dimension: 70,
                child: _role.avatar.isEmpty
                    ? placeholder
                    : Image.network(_role.avatar,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => placeholder))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, constraints) {
            final title = Text(_role.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
            final badge = _certificateBadge(l10n);
            if (constraints.maxWidth < 230 ||
                MediaQuery.textScalerOf(context).scale(12) > 16) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 5),
                    badge,
                  ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              badge,
            ]);
          }),
          const SizedBox(height: 5),
          Text(
              _role.profileComplete
                  ? l10n.roleProfileReady
                  : l10n.roleProfilePending,
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: colors.onSurfaceVariant)),
          if (_text(_role.profile['contentTags']).isNotEmpty)
            Text(_text(_role.profile['contentTags']),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: colors.onSurfaceVariant)),
        ])),
      ]),
    );
  }

  Widget _certificateBadge(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
          color: colors.onSurfaceVariant.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/icons/role_profile_certificate.png',
            width: 12, height: 12),
        Flexible(
            child: Text(
                _role.isCertified ? l10n.roleCertified : l10n.roleUncertified,
                style:
                    TextStyle(fontSize: 12, color: colors.onSurfaceVariant))),
      ]),
    );
  }

  Widget _actions(AppLocalizations l10n, bool enabled) {
    final colors = Theme.of(context).colorScheme;
    final editable = _role.canEdit;
    final official = widget.category == 'official';
    return Container(
      key: const Key('role-profile-actions'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: colors.surface, borderRadius: BorderRadius.circular(30)),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.roleStoryTitle,
                style: const TextStyle(fontSize: 16, height: 1.7)),
            const SizedBox(height: 10),
            Text(l10n.roleStoryDescription,
                style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 10),
            if (!official) ...[
              Row(children: [
                Expanded(
                    child: SizedBox(
                        height: 50,
                        child: TextButton(
                          key: const Key('role-improve'),
                          onPressed: enabled && editable
                              ? () => _compose(improve: true)
                              : null,
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  AppColors.brand.withValues(alpha: .05),
                              foregroundColor: colors.onSurface,
                              shape: const StadiumBorder(),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontSize: 18),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8)),
                          child: Text(l10n.improveRole,
                              textAlign: TextAlign.center),
                        ))),
                const SizedBox(width: 10),
                SizedBox.square(
                    dimension: 50,
                    child: IconButton(
                      key: const Key('role-delete'),
                      tooltip: editable
                          ? l10n.deleteRoleTitle
                          : l10n.roleDeleteUnavailable,
                      onPressed: enabled && editable ? _delete : null,
                      padding: EdgeInsets.zero,
                      icon: _deleting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Opacity(
                              opacity: enabled && editable ? 1 : .4,
                              child: const AppSvgIcon.asset(
                                  'role_profile_delete',
                                  size: 50)),
                    )),
              ]),
              const SizedBox(height: 10),
            ],
            SizedBox(
                height: 50,
                child: FilledButton(
                  key: const Key('role-create'),
                  onPressed: enabled && (official || _role.canCreate)
                      ? () => _compose(improve: false)
                      : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                            child: Text(l10n.createWithRole,
                                textAlign: TextAlign.center)),
                        const SizedBox(width: 5),
                        const AppSvgIcon.asset('role_profile_arrow',
                            size: 12, color: Colors.white),
                      ]),
                )),
          ]),
    );
  }
}
