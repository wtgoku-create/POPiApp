import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../session/presentation/session_page.dart';
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
  late LibraryRole _role;
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
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
      final updated = await ref.read(roleProfileSaverProvider)(
        _role.id,
        profile,
      );
      if (!mounted) return;
      setState(() {
        _role = updated;
        _saving = false;
      });
      _cancelEditing();
      widget.onRoleUpdated?.call(updated);
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

  void _compose() {
    final l10n = AppLocalizations.of(context)!;
    final prompt = l10n.createRolePrompt(_role.title);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionPage(
          initialPrompt: '$prompt\nID: ${_role.id}\n${_role.description}',
        ),
      ),
    );
  }

  String _fieldLabel(RoleProfileField field, AppLocalizations l10n) =>
      switch (field.type) {
        RoleProfileFieldType.positioning => l10n.rolePositioning,
        RoleProfileFieldType.style => l10n.roleStyle,
        RoleProfileFieldType.audience => l10n.roleAudience,
        RoleProfileFieldType.tags => l10n.roleTags,
        RoleProfileFieldType.appearance => l10n.roleAppearance,
        RoleProfileFieldType.boundaries => l10n.roleBoundaries,
        RoleProfileFieldType.custom =>
          field.label.isEmpty ? field.profileDataKey! : field.label,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
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
                                  label: Text(l10n.retryLoadingRoles),
                                ),
                              ),
                            const SizedBox(height: 20),
                            for (final field
                                in (_edit ?? RoleProfileEdit.fromRole(_role))
                                    .fields)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 25 / 14,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: colors.primary.withValues(
                                                alpha: .18,
                                              ),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: colors.primary,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      SelectableText(
                                        roleProfileText(field.value).isEmpty
                                            ? l10n.roleFieldPending
                                            : roleProfileText(field.value),
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 20 / 14,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
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
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 70,
              child: _role.avatar.isEmpty
                  ? placeholder
                  : Image.network(
                      _role.avatar,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => placeholder,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final title = Text(
                      _role.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                    final badge = _certificateBadge(l10n);
                    if (constraints.maxWidth < 230 ||
                        MediaQuery.textScalerOf(context).scale(12) > 16) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 5), badge],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 8),
                        badge,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 5),
                Text(
                  _role.profileComplete
                      ? l10n.roleProfileReady
                      : l10n.roleProfilePending,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (roleProfileText(_role.profile['contentTags']).isNotEmpty)
                  Text(
                    roleProfileText(_role.profile['contentTags']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
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

  Widget _certificateBadge(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: colors.onSurfaceVariant.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/role_profile_certificate.png',
            width: 12,
            height: 12,
          ),
          Flexible(
            child: Text(
              _role.isCertified ? l10n.roleCertified : l10n.roleUncertified,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
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
    return Container(
      key: const Key('role-profile-actions'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.roleStoryTitle,
            style: const TextStyle(fontSize: 16, height: 1.7),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.roleStoryDescription,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 10),
          if (!official) ...[
            SizedBox(
              height: 50,
              child: TextButton(
                key: const Key('role-improve'),
                onPressed: enabled && editable ? _startEditing : null,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.brand.withValues(alpha: .05),
                  foregroundColor: colors.onSurface,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(l10n.improveRole, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 50,
            child: FilledButton(
              key: const Key('role-create'),
              onPressed: enabled && (official || _role.canCreate)
                  ? _compose
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      l10n.createWithRole,
                      textAlign: TextAlign.center,
                    ),
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
      ),
    );
  }
}
