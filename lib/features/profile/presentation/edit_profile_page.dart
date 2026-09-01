import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
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
                        '昵称*',
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
                        '可以输入中文、英文、数字。最多15个字符。',
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
                        initialValue: user?.code.isNotEmpty == true
                            ? user!.code
                            : user?.id ?? '--',
                        readOnly: true,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          suffixIcon: Icon(
                            Icons.copy_outlined,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
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
                              : const Text(
                                  '确认',
                                  style: TextStyle(
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.error(context, '请输入昵称');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(userProvider.notifier).updateUser(name: name);
      if (!mounted) return;
      AppToast.success(context, '资料已更新');
      context.pop();
    } catch (_) {
      if (mounted) AppToast.error(context, '资料更新失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
