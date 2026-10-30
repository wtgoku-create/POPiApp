import 'package:flutter/material.dart';

import '../../data/demo_fixtures.dart';
import '../../data/demo_repository.dart';
import '../../data/demo_website_character_catalog.dart';
import '../../domain/demo_models.dart';
import '../demo_remote_media.dart';
import '../demo_role_image.dart';
import 'demo_widgets.dart';

/// Returns the best image source shared by role previews and the composer.
String demoContentRoleAvatarSource(
  DemoRepository repository,
  DemoSession session,
  String roleId,
) {
  final profile = session.roleProfiles[roleId];
  final businessAvatar =
      repository.libraryRole(roleId)?['avatarUrl']?.toString() ?? '';
  if (businessAvatar.isNotEmpty) return businessAvatar;
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
  if (repository.usesBusinessLibrary) {
    return profile?.referenceImageUrls
            .where((url) => url.trim().isNotEmpty)
            .firstOrNull ??
        '';
  }
  final catalogProfile = DemoWebsiteCharacterCatalog.profile(roleId);
  final customReferenceUrl =
      DemoWebsiteCharacterCatalog.legacyProfiles.containsKey(roleId)
      ? profile?.referenceImageUrls
            .map((url) => url.trim())
            .where(
              (url) =>
                  url.isNotEmpty &&
                  !(catalogProfile?.referenceImageUrls.contains(url) ?? false),
            )
            .firstOrNull
      : null;
  if (customReferenceUrl != null) return customReferenceUrl;
  // Website catalog characters keep a bundled avatar for stable/offline list
  // rendering. Their public three-view URL remains in the role profile and is
  // still supplied to the generation context after the role is associated.
  final websiteAvatar = DemoWebsiteCharacterCatalog.bundledAvatar(roleId);
  if (websiteAvatar != null) return websiteAvatar;
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
    if (source.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.person_outline,
          size: size * 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (!source.startsWith('assets/')) {
      return ClipOval(
        child: DemoRoleImage(
          repository: repository,
          source: source,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return DemoAvatar(image: source, size: size);
  }
}
