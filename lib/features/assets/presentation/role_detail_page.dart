import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/role_library_repository.dart';
import '../domain/library_role.dart';
import '../domain/role_profile_edit.dart';

class RoleDetailPage extends ConsumerStatefulWidget {
  const RoleDetailPage({
    super.key,
    required this.role,
    required this.category,
    this.onRoleUpdated,
  });
  final LibraryRole role;
  final String category;
  final ValueChanged<LibraryRole>? onRoleUpdated;

  @override
  ConsumerState<RoleDetailPage> createState() => _RoleDetailPageState();
}

class _RoleDetailPageState extends ConsumerState<RoleDetailPage> {
  static const _overviewTypes = {
    RoleProfileFieldType.style,
    RoleProfileFieldType.audience,
    RoleProfileFieldType.tags,
  };
  late final RoleLibraryRepository _repository;
  late LibraryRole _role;
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  bool _fullProfile = true;
  RoleProfileEdit? _edit;
  final _controllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startEditing() {
    if (_loading ||
        _failed ||
        !_role.canEdit ||
        widget.category == 'official') {
      return;
    }
    final edit = RoleProfileEdit.fromRole(_role);
    for (final field in edit.fields.where((field) => field.editable)) {
      _controllers[field.id] = TextEditingController(text: field.text);
    }
    setState(() => _edit = edit);
  }

  void _cancelEditing() {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _edit = null);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  bool get _draftComplete => _controllers.values.every(
    (controller) => controller.text.trim().isNotEmpty,
  );

  Future<void> _saveChanges() async {
    final edit = _edit;
    if (edit == null || _saving || !_draftComplete) return;
    final l10n = AppLocalizations.of(context)!;
    final profile = edit.savedProfile(
      {for (final entry in _controllers.entries) entry.key: entry.value.text},
      fieldLabels: {
        for (final field in edit.fields) field.id: _fieldLabel(field, l10n),
      },
    );
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final updated = await _repository.saveProfile(_role.id, profile);
      if (!mounted) return;
      setState(() {
        _role = updated.withFallbackAvatar(_role.avatar);
        _saving = false;
      });
      _cancelEditing();
      widget.onRoleUpdated?.call(_role);
      AppToast.success(context, l10n.roleChangesSaved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, l10n.roleChangesSaveFailed);
    }
  }

  @override
  void initState() {
    super.initState();
    _repository = RoleLibraryRepository(NetworkApi(ref.read(dioProvider)));
    _role = widget.role;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final role = await _repository.fetchDetail(_role.id);
      if (mounted) {
        setState(() => _role = role.withFallbackAvatar(_role.avatar));
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _compose() {
    final l10n = AppLocalizations.of(context)!;
    final prompt = l10n.createRolePrompt(_role.title);
    context.push(
      Uri(
        path: '/session',
        queryParameters: {
          'prompt': '$prompt\nID: ${_role.id}\n${_role.description}',
        },
      ).toString(),
    );
  }

  String _fieldLabel(RoleProfileField field, AppLocalizations l10n) {
    if (field.profileDataKey != null && field.label.isNotEmpty) {
      return field.label;
    }
    return switch (field.type) {
      RoleProfileFieldType.positioning => l10n.rolePositioning,
      RoleProfileFieldType.style => l10n.roleStyle,
      RoleProfileFieldType.audience => l10n.roleAudience,
      RoleProfileFieldType.tags => l10n.roleTags,
      RoleProfileFieldType.appearance => l10n.roleAppearance,
      RoleProfileFieldType.boundaries => l10n.roleBoundaries,
      RoleProfileFieldType.custom =>
        field.label.isEmpty ? field.profileDataKey! : field.label,
    };
  }

  List<RoleProfileField> get _visibleFields {
    final fields = (_edit ?? RoleProfileEdit.fromRole(_role)).fields;
    if (_edit != null) return fields;
    return fields
        .where((field) => _overviewTypes.contains(field.type))
        .toList();
  }

  List<RoleProfileField> get _fullProfileFields => RoleProfileEdit.fromRole(
    _role,
  ).fields.where((field) => field.id.startsWith('profileData-')).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    final panelBackground = light
        ? Colors.white.withValues(alpha: .5)
        : colors.surfaceContainerLow;
    final enabled = !_loading && !_failed;
    return PopScope(
      canPop: !_saving && _edit == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && _edit != null) _cancelEditing();
      },
      child: Scaffold(
        key: const Key('role-detail-page'),
        backgroundColor: light ? const Color(0xFFF5F4FA) : colors.surface,
        appBar: AppBar(
          backgroundColor: light ? const Color(0xFFF5F4FA) : colors.surface,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Text(
            l10n.roleArchive,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            key: const Key('role-profile-back'),
            tooltip: l10n.backToPreviousPage,
            onPressed: _saving
                ? null
                : () {
                    if (_edit != null) {
                      _cancelEditing();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
            icon: Transform.rotate(
              angle: math.pi / 2,
              child: AppSvgIcon.asset(
                'role_profile_back',
                size: 40,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: panelBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(45),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  key: const Key('role-profile-scroll'),
                  padding: const EdgeInsets.all(20),
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
                                    label: Text(l10n.retryLoadingRoles),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              for (final field in _visibleFields)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: _edit == null ? 20 : 18,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          text: _fieldLabel(field, l10n),
                                          children: [
                                            if (_edit != null && field.editable)
                                              TextSpan(
                                                text: ' *',
                                                style: TextStyle(
                                                  color: colors.error,
                                                ),
                                              ),
                                          ],
                                        ),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (_edit != null && field.editable)
                                        TextFormField(
                                          key: Key('role-edit-${field.id}'),
                                          controller: _controllers[field.id],
                                          enabled: !_saving,
                                          minLines: 2,
                                          maxLines: null,
                                          keyboardType: TextInputType.multiline,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          onChanged: (_) => setState(() {}),
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 20 / 14,
                                            color: colors.onSurfaceVariant,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: l10n.roleFieldPending,
                                            helperText: ' ',
                                            errorText:
                                                _controllers[field.id]!.text
                                                    .trim()
                                                    .isEmpty
                                                ? l10n.roleFieldRequired
                                                : null,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 11,
                                                  vertical: 9,
                                                ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: colors.primary
                                                    .withValues(alpha: .18),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: colors.primary,
                                              ),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        )
                                      else
                                        SelectableText(
                                          roleProfileText(field.value).isEmpty
                                              ? l10n.roleFieldPending
                                              : roleProfileText(field.value),
                                          style: TextStyle(
                                            fontSize: 16,
                                            height: 20 / 16,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              if (_edit == null &&
                                  _fullProfileFields.isNotEmpty)
                                _profileArchive(l10n, enabled),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: ColoredBox(
          color: panelBackground,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(45),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: ColoredBox(
                  color: light
                      ? AppColors.brand.withValues(alpha: .05)
                      : colors.surfaceContainer,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        _edit == null ? 40 : 20,
                        20,
                        _edit == null ? 40 : 20,
                        20,
                      ),
                      child: Center(
                        heightFactor: 1,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 560,
                            maxHeight: MediaQuery.sizeOf(context).height * .55,
                          ),
                          child: SingleChildScrollView(
                            child: _edit != null
                                ? _editActions(l10n)
                                : _actions(l10n, enabled),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileArchive(AppLocalizations l10n, bool enabled) {
    final colors = Theme.of(context).colorScheme;
    final version = _role.profileVersion;
    final versionLabel = version == null
        ? ''
        : 'v${version % 1 == 0 ? version.toStringAsFixed(1) : version.toString()}';
    final label = version == null
        ? l10n.roleFullProfile
        : l10n.roleFullProfileVersion(versionLabel);
    return Container(
      key: const Key('role-profile-archive'),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: .05),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _fullProfile,
            child: Tooltip(
              message: _fullProfile ? l10n.roleCollapseProfile : label,
              child: TextButton(
                key: const Key('role-profile-toggle'),
                onPressed: enabled
                    ? () => setState(() => _fullProfile = !_fullProfile)
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  minimumSize: const Size.fromHeight(61),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RotatedBox(
                      quarterTurns: 1,
                      child: const AppSvgIcon.asset(
                        'role_profile_arrow',
                        size: 12,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_fullProfile)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, field) in _fullProfileFields.indexed) ...[
                    if (index > 0) const SizedBox(height: 20),
                    _archiveField(field, l10n),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _archiveField(RoleProfileField field, AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final label = Container(
      key: Key('role-profile-label-${field.id}'),
      width: 94,
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? AppColors.brand.withValues(alpha: .05)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _fieldLabel(field, l10n),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 20 / 16,
        ),
      ),
    );
    final content = SelectableText(
      field.text.isEmpty ? l10n.roleFieldPending : roleProfileText(field.value),
      key: Key('role-profile-value-${field.id}'),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 20 / 16,
        color: colors.onSurfaceVariant,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 240 ||
            MediaQuery.textScalerOf(context).scale(16) > 22) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 8), content],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(width: 20),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _summary(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.person_outline, size: 32)),
    );
    return Container(
      key: const Key('role-profile-summary'),
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? AppColors.brand.withValues(alpha: .05)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.brand.withValues(alpha: .1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox.square(
                dimension: 64,
                child: _role.avatar.isEmpty
                    ? placeholder
                    : _role.avatar.startsWith('assets/')
                    ? Image.asset(
                        _role.avatar,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => placeholder,
                      )
                    : Image.network(
                        _role.avatar,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => placeholder,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _role.title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _role.profileComplete
                      ? l10n.roleProfileReady
                      : l10n.roleProfilePending,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (roleProfileText(_role.profile['contentTags']).isNotEmpty)
                  Text(
                    roleProfileText(_role.profile['contentTags']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editActions(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      key: const Key('role-profile-edit-actions'),
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: TextButton(
              key: const Key('role-edit-cancel'),
              onPressed: _saving ? null : _cancelEditing,
              style: TextButton.styleFrom(
                backgroundColor: colors.primary.withValues(alpha: .05),
                foregroundColor: colors.onSurface,
                shape: const StadiumBorder(),
              ),
              child: Text(l10n.cancel, textAlign: TextAlign.center),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: FilledButton(
              key: const Key('role-edit-confirm'),
              onPressed: _saving || !_draftComplete ? null : _saveChanges,
              child: Text(
                _saving ? l10n.savingRoleChanges : l10n.confirmRoleChanges,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(AppLocalizations l10n, bool enabled) {
    final colors = Theme.of(context).colorScheme;
    final editable = _role.canEdit;
    final official = widget.category == 'official';
    final compact =
        MediaQuery.sizeOf(context).height < 700 ||
        MediaQuery.textScalerOf(context).scale(16) > 20;
    return Column(
      key: const Key('role-profile-actions'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text(
            l10n.roleStoryTitle,
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.roleStoryDescription,
            style: const TextStyle(fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 10),
        ],
        if (!official) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: TextButton(
              key: const Key('role-improve'),
              onPressed: enabled && editable ? _startEditing : null,
              style: TextButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                shape: const StadiumBorder(),
                textStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 18),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              child: Text(l10n.improveRole, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 10),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: FilledButton(
            key: const Key('role-create'),
            onPressed: enabled && (official || _role.canCreate)
                ? _compose
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(l10n.createWithRole, textAlign: TextAlign.center),
                ),
                const SizedBox(width: 5),
                const AppSvgIcon.asset(
                  'role_profile_arrow',
                  size: 12,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
