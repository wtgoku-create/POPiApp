import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../assets/domain/library_role.dart';
import '../../domain/home_role_profile_edit.dart';
import 'role_guide_controls.dart';

/// Editable content within the existing role archive sheet.
class HomeRoleProfileForm extends StatelessWidget {
  const HomeRoleProfileForm({
    required this.role,
    required this.edit,
    required this.controllers,
    required this.scrollController,
    required this.formKey,
    required this.saving,
    required this.invalidField,
    required this.onChanged,
    super.key,
  });

  final LibraryRole role;
  final HomeRoleProfileEdit edit;
  final Map<String, TextEditingController> controllers;
  final ScrollController scrollController;
  final GlobalKey<FormState> formKey;
  final bool saving;
  final String? invalidField;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RoleGuideAvatar(role: role, size: 60),
                const SizedBox(width: 12),
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
            const SizedBox(height: 20),
            for (final field in edit.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: TextFormField(
                  key: ValueKey((role.id, field.id)),
                  controller: controllers[field.id],
                  enabled: !saving,
                  minLines: field.id == 'title' ? 1 : 2,
                  maxLines: null,
                  validator: (value) =>
                      field.id == 'title' && (value?.trim().isEmpty ?? true)
                      ? l10n.roleFieldRequired
                      : null,
                  decoration: InputDecoration(
                    labelText: switch (field.id) {
                      'title' => l10n.chatRoleName,
                      'description' => l10n.roleDescription,
                      'expressionStyle' => l10n.roleStyle,
                      'targetAudience' => l10n.roleAudience,
                      'contentTags' => l10n.roleTags,
                      _ => field.label,
                    },
                    errorText: invalidField == field.id
                        ? l10n.roleFieldInvalidFormat
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (_) => onChanged(field.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
