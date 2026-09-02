import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import 'widgets/profile_chrome.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nameController = TextEditingController();
  String? _hydratedUserId;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final displayId =
        user?.code.isNotEmpty == true ? user!.code : user?.id ?? '--';
    final l10n = AppLocalizations.of(context)!;
    if (user != null && _hydratedUserId != user.id) {
      _nameController.text = user.name;
      _hydratedUserId = user.id;
    }

    return Scaffold(
      body: Column(
        children: [
          const ProfileTopBar(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: ProfileAvatar(
                    size: 130,
                    editable: true,
                    imageUrl: user?.avatarUrl,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 365),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.nicknameRequiredLabel,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('profile-name'),
                        controller: _nameController,
                        maxLength: 15,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          counterText: '',
                          suffixText: '${_nameController.text.length}/15',
                          border: _border,
                          enabledBorder: _border,
                          focusedBorder: _border,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.nicknameHelp,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'UID',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: displayId,
                        readOnly: true,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          suffixIcon: IconButton(
                            key: const Key('edit-profile-uid-copy'),
                            tooltip: l10n.copyAction,
                            onPressed: displayId == '--'
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: displayId),
                                    );
                                    if (context.mounted) {
                                      AppToast.success(context, l10n.uidCopied);
                                    }
                                  },
                            icon: Icon(
                              Icons.copy_outlined,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          border: _border,
                          enabledBorder: _border,
                          focusedBorder: _border,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  l10n.confirm,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder get _border => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: BorderSide.none,
      );

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.error(context, l10n.nicknameRequired);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(userProvider.notifier).updateUser(name: name);
      if (!mounted) return;
      AppToast.success(context, l10n.profileUpdated);
      context.pop();
    } catch (_) {
      if (mounted) AppToast.error(context, l10n.profileUpdateFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
