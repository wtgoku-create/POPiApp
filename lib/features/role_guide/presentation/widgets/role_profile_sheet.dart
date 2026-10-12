import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../assets/domain/library_role.dart';
import '../../../assets/presentation/role_detail_page.dart';
import '../../domain/home_role_profile_edit.dart';
import 'home_role_profile_form.dart';
import 'role_guide_sheet.dart';
import 'role_guide_markdown.dart';

/// Uses the archive page layout while browsing roles in selection order.
class RoleProfileSheet extends StatefulWidget {
  const RoleProfileSheet({
    required this.roles,
    this.initialRoleId,
    this.useSnapshot = false,
    this.onSaveCreationProfile,
    super.key,
  });

  final List<LibraryRole> roles;
  final String? initialRoleId;
  final bool useSnapshot;
  final Future<List<LibraryRole>> Function(String, Map<String, Object?>)?
  onSaveCreationProfile;

  @override
  State<RoleProfileSheet> createState() => _RoleProfileSheetState();
}

class _RoleProfileSheetState extends State<RoleProfileSheet> {
  int _index = 0;
  late final List<LibraryRole> _roles;
  HomeRoleProfileEdit? _edit;
  final _controllers = <String, TextEditingController>{};
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _failed = false;
  String? _invalidField;

  @override
  void initState() {
    super.initState();
    _roles = List.of(widget.roles);
    final initialIndex = _roles.indexWhere(
      (role) => role.id == widget.initialRoleId,
    );
    if (initialIndex >= 0) _index = initialIndex;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  void _editProfile() {
    final edit = HomeRoleProfileEdit(_roles[_index]);
    for (final field in edit.fields) {
      _controllers[field.id] = TextEditingController(text: edit.text(field));
    }
    setState(() => _edit = edit);
  }

  void _cancelEditing() {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _edit = null;
      _failed = false;
      _invalidField = null;
    });
    _disposeControllers();
  }

  Future<void> _saveProfile() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    Map<String, Object?> profile;
    try {
      profile = _edit!.savedProfile({
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      });
    } on FormatException catch (error) {
      setState(() => _invalidField = error.source as String?);
      return;
    }
    final roleId = _roles[_index].id;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final roles = await widget.onSaveCreationProfile!(roleId, profile);
      if (!mounted) return;
      setState(() {
        _roles
          ..clear()
          ..addAll(roles);
        final index = _roles.indexWhere((role) => role.id == roleId);
        _index = index < 0 ? 0 : index;
        _saving = false;
      });
      _cancelEditing();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = _roles[_index];
    final hasMultipleRoles = _roles.length > 1;
    final title = hasMultipleRoles
        ? l10n.roleProfilePage(_index + 1, _roles.length)
        : l10n.roleArchive;
    return PopScope(
      canPop: !_saving && _edit == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && _edit != null) _cancelEditing();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: RoleGuideSheet(
          key: const Key('role-guide-profile-sheet'),
          title: title,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: .9),
          initialSize: .875,
          header: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                if (hasMultipleRoles) ...[
                  const SizedBox(width: 5),
                  _navigationButton(
                    previous: true,
                    tooltip: l10n.rolePreviousProfile,
                    onPressed: _edit != null || _index == 0
                        ? null
                        : () => setState(() => _index--),
                  ),
                  _navigationButton(
                    previous: false,
                    tooltip: l10n.roleNextProfile,
                    onPressed: _edit != null || _index == _roles.length - 1
                        ? null
                        : () => setState(() => _index++),
                  ),
                ],
              ],
            ),
          ),
          footer: _edit != null
              ? _editActions(l10n)
              : widget.onSaveCreationProfile == null
              ? null
              : Container(
                  key: const Key('role-creation-edit-entry'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.roleCreationEditTitle,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.roleCreationEditDescription,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        key: const Key('role-profile-edit-creation'),
                        onPressed: _editProfile,
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                          minimumSize: const Size.fromHeight(36),
                          shape: const StadiumBorder(),
                          textStyle: Theme.of(
                            context,
                          ).textTheme.labelLarge!.copyWith(fontSize: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                l10n.roleEditCreationArchive,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppSvgIcon.asset(
                              'role_profile_arrow',
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          builder: (context, controller) => _edit != null
              ? HomeRoleProfileForm(
                  key: const Key('role-creation-profile-form'),
                  role: role,
                  edit: _edit!,
                  controllers: _controllers,
                  scrollController: controller,
                  formKey: _formKey,
                  saving: _saving,
                  invalidField: _invalidField,
                  onChanged: (fieldId) {
                    if (_invalidField == fieldId) {
                      setState(() => _invalidField = null);
                    }
                  },
                )
              : RoleDetailPage.sheet(
                  key: ValueKey(role.id),
                  role: role,
                  category: role.canEdit ? 'personal' : 'official',
                  scrollController: controller,
                  useSnapshot: widget.useSnapshot,
                ),
        ),
      ),
    );
  }

  Widget _editActions(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_failed) ...[
        Text(
          l10n.roleChangesSaveFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 12),
      ],
      Row(
        children: [
          Expanded(
            child: TextButton(
              key: const Key('home-role-edit-cancel'),
              onPressed: _saving ? null : _cancelEditing,
              child: Text(l10n.cancel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              key: const Key('home-role-edit-save'),
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.confirmRoleChanges, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _navigationButton({
    required bool previous,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: 24,
    height: 32,
    child: IconButton(
      key: Key(previous ? 'role-profile-previous' : 'role-profile-next'),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: RotatedBox(
        quarterTurns: previous ? 2 : 0,
        child: SizedBox(
          width: 6,
          height: 12,
          child: AppSvgIcon.asset(
            'role_profile_arrow',
            color: onPressed == null
                ? Theme.of(context).disabledColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ),
  );
}

class RoleGuideTextSection extends StatelessWidget {
  const RoleGuideTextSection({
    required this.title,
    required this.text,
    super.key,
  });
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        RoleGuideMarkdown(
          text: text,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    ),
  );
}
