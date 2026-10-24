import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_network_image.dart';
import '../../data/demo_fixtures.dart';
import '../../data/demo_repository.dart';
import '../../domain/demo_models.dart';
import '../demo_remote_media.dart';
import 'demo_widgets.dart';

/// Returns the best image source shared by role previews and the composer.
String demoContentRoleAvatarSource(
  DemoRepository repository,
  DemoSession session,
  String roleId,
) {
  final profile = session.roleProfiles[roleId];
  final reference = profile?.referenceAssetIds
      .map(
        (id) => repository.assets
            .where(
              (asset) => asset.id == id && asset.kind == DemoAssetKind.image,
            )
            .firstOrNull,
      )
      .whereType<DemoAsset>()
      .firstOrNull;
  if (reference != null) {
    return reference.isRemote ? reference.contentUrl : reference.cover;
  }
  final referenceUrl = profile?.referenceImageUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .firstOrNull;
  if (referenceUrl != null) return referenceUrl;
  return DemoFixtures.characters
          .where((role) => role.id == roleId)
          .firstOrNull
          ?.image ??
      'assets/images/demo_role_1.png';
}

/// Displays a content role using its first owned reference image when present.
class DemoContentRoleAvatar extends StatelessWidget {
  const DemoContentRoleAvatar({
    required this.repository,
    required this.session,
    required this.roleId,
    this.size = 40,
    super.key,
  });

  final DemoRepository repository;
  final DemoSession session;
  final String roleId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final profile = session.roleProfiles[roleId];
    final reference = profile?.referenceAssetIds
        .map(
          (id) => repository.assets
              .where(
                (asset) => asset.id == id && asset.kind == DemoAssetKind.image,
              )
              .firstOrNull,
        )
        .whereType<DemoAsset>()
        .firstOrNull;
    if (reference != null) {
      return ClipOval(
        child: DemoAssetImage(
          asset: reference,
          width: size,
          height: size,
          cacheWidth: (size * 3).ceil(),
          fit: BoxFit.cover,
        ),
      );
    }

    final source = demoContentRoleAvatarSource(repository, session, roleId);
    if (!source.startsWith('assets/')) {
      return ClipOval(
        child: AppNetworkImage(
          source,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return DemoAvatar(image: source, size: size);
  }
}
