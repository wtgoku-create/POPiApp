import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';

class ProfileTopBar extends StatelessWidget {
  const ProfileTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final top = math.max(MediaQuery.paddingOf(context).top, 52).toDouble();
    return SizedBox(
      height: top + 48,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: Row(
          children: [
            const SizedBox(width: 20),
            SizedBox.square(
              dimension: 40,
              child: IconButton(
                key: const Key('profile-back'),
                tooltip: AppLocalizations.of(context)!.back,
                padding: EdgeInsets.zero,
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 21),
              ),
            ),
            const Spacer(),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    this.size = 84,
    this.editable = false,
    this.imageUrl,
    this.imageProvider,
    super.key,
  });

  final double size;
  final bool editable;
  final String? imageUrl;
  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipOval(
          child: imageProvider != null
              ? Image(
                  image: imageProvider!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover)
              : imageUrl == null || imageUrl!.isEmpty
                  ? Image.asset(
                      'assets/icons/common_user_avatar.png',
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      imageUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/icons/common_user_avatar.png',
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                      ),
                    ),
        ),
        if (editable)
          Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle)),
        if (editable)
          Image.asset('assets/icons/profile_avatar_edit.png',
              width: 50, height: 50),
      ],
    );
  }
}
