import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';

class ProfileTopBar extends StatelessWidget {
  const ProfileTopBar({
    this.showSettings = true,
    super.key,
  });

  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final top = math.max(MediaQuery.paddingOf(context).top, 52).toDouble();
    return SizedBox(
      height: top + 56,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: Row(
          children: [
            const SizedBox(width: 20),
            SizedBox.square(
              dimension: 40,
              child: IconButton(
                key: const Key('profile-back'),
                tooltip: '返回',
                padding: EdgeInsets.zero,
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 21),
              ),
            ),
            const Spacer(),
            if (showSettings)
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  tooltip: '设置',
                  padding: const EdgeInsets.all(5),
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined, size: 30),
                ),
              ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({this.size = 120, this.editable = false, super.key});

  final double size;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/icons/popi_user_avatar.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (editable)
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xCCFFFFFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              size: 21,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
