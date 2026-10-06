import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' show instantiateImageCodec;

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import 'widgets/profile_chrome.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key, this.pickAvatar});

  final Future<XFile?> Function()? pickAvatar;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nameController = TextEditingController();
  String? _hydratedUserId;
  bool _isSaving = false;
  bool _isPicking = false;
  Uint8List? _avatarBytes;
  MemoryImage? _avatarPreview;
  String? _avatarFilename;
  String? _uploadedAvatarUrl;

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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Semantics(
                    button: true,
                    label: l10n.changeAvatar,
                    child: InkWell(
                      key: const Key('edit-profile-avatar'),
                      customBorder: const CircleBorder(),
                      onTap: _isSaving || _isPicking ? null : _pickAvatar,
                      child: ProfileAvatar(
                        size: 130,
                        editable: true,
                        imageUrl: user?.avatarUrl,
                        imageProvider: _avatarPreview,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_isSaving && !_isPicking) _saveProfile();
                        },
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
                          key: const Key('save-profile-button'),
                          onPressed:
                              _isSaving || _isPicking ? null : _saveProfile,
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
    if (_isSaving || _isPicking || ref.read(userProvider) == null) return;
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.error(context, l10n.nicknameRequired);
      return;
    }

    setState(() => _isSaving = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      if (_avatarBytes != null && _uploadedAvatarUrl == null) {
        _uploadedAvatarUrl =
            await NetworkApi(ref.read(dioProvider)).uploadAvatar(
          bytes: _avatarBytes!,
          filename: _avatarFilename!,
        );
      }
      if (!mounted) return;
      await ref
          .read(userProvider.notifier)
          .updateUser(name: name, avatarUrl: _uploadedAvatarUrl);
      if (!mounted) return;
      AppToast.success(context, l10n.profileUpdated);
      context.pop();
    } catch (_) {
      if (mounted) AppToast.error(context, l10n.profileUpdateFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_isPicking || _isSaving) return;
    setState(() => _isPicking = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final file = await (widget.pickAvatar?.call() ??
          ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1024,
              maxHeight: 1024,
              imageQuality: 90));
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarPreview = MemoryImage(bytes);
        _avatarFilename = file.name;
        _uploadedAvatarUrl = null;
      });
    } catch (_) {
      if (mounted) {
        AppToast.error(
            context, AppLocalizations.of(context)!.avatarSelectionFailed);
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }
}
