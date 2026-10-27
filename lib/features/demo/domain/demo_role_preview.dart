import 'package:flutter/foundation.dart';

import 'demo_models.dart';

/// Read-only presentation data derived from an existing demo role profile.
@immutable
class DemoRolePreviewData {
  const DemoRolePreviewData._({
    required this.name,
    required this.instructions,
    required this.isReady,
    required this.expressionStyle,
    required this.targetAudience,
    required this.contentTags,
    required this.references,
    required this.missingReferenceCount,
  });

  factory DemoRolePreviewData.fromProfile({
    required String roleId,
    required DemoRoleProfile? profile,
    required String fallbackName,
    required List<DemoAsset> assets,
  }) {
    final instructions = profile?.instructions ?? '';
    final fields = _extractPreviewFields(instructions);
    final resolvedReferences = _resolveReferences(
      roleId: roleId,
      profile: profile,
      assets: assets,
    );

    return DemoRolePreviewData._(
      name: profile != null && profile.name.trim().isNotEmpty
          ? profile.name
          : fallbackName,
      instructions: instructions,
      isReady: profile?.isReady ?? false,
      expressionStyle: fields[_PreviewField.expressionStyle] ?? '',
      targetAudience: fields[_PreviewField.targetAudience] ?? '',
      contentTags: fields[_PreviewField.contentTags] ?? '',
      references: List.unmodifiable(resolvedReferences.references),
      missingReferenceCount: resolvedReferences.missingReferenceCount,
    );
  }

  final String name;
  final String instructions;

  /// Mirrors the profile's generation-context readiness only.
  final bool isReady;

  final String expressionStyle;
  final String targetAudience;
  final String contentTags;
  final List<DemoRolePreviewReference> references;
  final int missingReferenceCount;
}

/// A preview reference is either an owned image asset or a public HTTP(S) URL.
@immutable
class DemoRolePreviewReference {
  const DemoRolePreviewReference({required this.key, this.asset, this.url})
    : assert((asset == null) != (url == null));

  final String key;
  final DemoAsset? asset;
  final String? url;

  bool get isOwned => asset != null;
  bool get isPublic => url != null;
}

enum _PreviewField { expressionStyle, targetAudience, contentTags }

const _expressionStyleLabels = {
  '性格与表达风格',
  '表达风格',
  '性格',
  'personality & expression style',
  'expression style',
  'personality',
};
const _targetAudienceLabels = {'面向受众', '目标受众', 'target audience'};
const _contentTagsLabels = {'内容标签', 'content tags', 'tags'};

Map<_PreviewField, String> _extractPreviewFields(String instructions) {
  final fields = <_PreviewField, String>{};
  String? fenceCharacter;

  for (final line in instructions.split('\n')) {
    final leftTrimmed = line.trimLeft();
    final delimiter = _fenceCharacter(leftTrimmed);
    if (delimiter != null) {
      if (fenceCharacter == null) {
        fenceCharacter = delimiter;
      } else if (fenceCharacter == delimiter) {
        fenceCharacter = null;
      }
      continue;
    }
    if (fenceCharacter != null) continue;

    final colonIndex = _firstColonIndex(line);
    if (colonIndex < 0) continue;
    final label = line.substring(0, colonIndex).trim();
    final value = line.substring(colonIndex + 1).trim();
    if (label.isEmpty || value.isEmpty) continue;

    final normalizedLabel = label.toLowerCase();
    final field = switch (normalizedLabel) {
      final label when _expressionStyleLabels.contains(label) =>
        _PreviewField.expressionStyle,
      final label when _targetAudienceLabels.contains(label) =>
        _PreviewField.targetAudience,
      final label when _contentTagsLabels.contains(label) =>
        _PreviewField.contentTags,
      _ => null,
    };
    if (field != null) fields.putIfAbsent(field, () => value);
  }

  return fields;
}

String? _fenceCharacter(String line) {
  if (line.startsWith('```')) return '`';
  if (line.startsWith('~~~')) return '~';
  return null;
}

int _firstColonIndex(String line) {
  final ascii = line.indexOf(':');
  final fullWidth = line.indexOf('：');
  if (ascii < 0) return fullWidth;
  if (fullWidth < 0) return ascii;
  return ascii < fullWidth ? ascii : fullWidth;
}

_ResolvedReferences _resolveReferences({
  required String roleId,
  required DemoRoleProfile? profile,
  required List<DemoAsset> assets,
}) {
  if (profile == null) return const _ResolvedReferences();

  final imagesById = <String, DemoAsset>{};
  final imagesByContentUrl = <String, DemoAsset>{};
  for (final asset in assets) {
    if (asset.kind != DemoAssetKind.image) continue;
    imagesById.putIfAbsent(asset.id, () => asset);
    final contentUrl = asset.contentUrl.trim();
    if (contentUrl.isNotEmpty) {
      imagesByContentUrl.putIfAbsent(contentUrl, () => asset);
    }
  }

  final references = <DemoRolePreviewReference>[];
  final requestedAssetIds = <String>{};
  final includedAssetIds = <String>{};
  final includedLocations = <String>{};
  var missingReferenceCount = 0;

  void addOwned(DemoAsset asset) {
    if (!includedAssetIds.add(asset.id)) return;
    final contentUrl = asset.contentUrl.trim();
    if (contentUrl.isNotEmpty && !includedLocations.add(contentUrl)) return;
    references.add(
      DemoRolePreviewReference(key: '$roleId:asset:${asset.id}', asset: asset),
    );
  }

  for (final assetId in profile.referenceAssetIds) {
    if (!requestedAssetIds.add(assetId)) continue;
    final asset = imagesById[assetId];
    if (asset == null) {
      missingReferenceCount++;
    } else {
      addOwned(asset);
    }
  }

  final publicUrls = <String>[];
  final seenUrls = <String>{};
  for (final rawUrl in profile.referenceImageUrls) {
    final url = rawUrl.trim();
    if (!_isPublicHttpUrl(url) || !seenUrls.add(url)) continue;
    final ownedAsset = imagesByContentUrl[url];
    if (ownedAsset != null) {
      addOwned(ownedAsset);
    } else {
      publicUrls.add(url);
    }
  }

  for (final url in publicUrls) {
    if (!includedLocations.add(url)) continue;
    references.add(DemoRolePreviewReference(key: '$roleId:url:$url', url: url));
  }

  return _ResolvedReferences(
    references: references,
    missingReferenceCount: missingReferenceCount,
  );
}

bool _isPublicHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

class _ResolvedReferences {
  const _ResolvedReferences({
    this.references = const [],
    this.missingReferenceCount = 0,
  });

  final List<DemoRolePreviewReference> references;
  final int missingReferenceCount;
}
