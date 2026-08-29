import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import 'widgets/profile_chrome.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController(text: '啵啵');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ProfileTopBar(showSettings: false),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 10),
                const Center(child: ProfileAvatar(size: 130, editable: true)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 365),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '昵称*',
                        style: TextStyle(
                          color: AppColors.textSecondary,
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
                          fillColor: const Color(0xFFF0F3F9),
                          counterText: '',
                          suffixText: '${_nameController.text.length}/15',
                          border: _border,
                          enabledBorder: _border,
                          focusedBorder: _border,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '可以输入中文、英文、数字。最多15个字符。',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'UID',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: '09821',
                        readOnly: true,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF0F3F9),
                          suffixIcon: const Icon(
                            Icons.copy_outlined,
                            size: 18,
                            color: AppColors.textTertiary,
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
                          onPressed: () => context.pop(),
                          child: const Text(
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
}
