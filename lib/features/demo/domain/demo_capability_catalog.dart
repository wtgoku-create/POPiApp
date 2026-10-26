import 'package:flutter/foundation.dart';

const demoSeedanceReferenceRemixSkillId = 'seedance-reference-remix';

/// Identifiers are syntactically bounded; the runtime catalog owns authorization.
bool isValidDemoSkillId(String id) =>
    id.length <= 64 && RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id);

/// A binding advertised by DSH, separate from content-generation permissions.
@immutable
class DemoRuntimeCapability {
  const DemoRuntimeCapability({
    required this.id,
    required this.name,
    this.description = '',
    this.source = '',
    this.available = false,
    this.bound = true,
    bool? installed,
    this.granted = true,
    this.reasonUnavailable = '',
  }) : installed = installed ?? bound;

  final String id;
  final String name;
  final String description;
  final String source;
  final bool available;
  final bool bound;
  final bool installed;
  final bool granted;
  final String reasonUnavailable;

  factory DemoRuntimeCapability.fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) throw const FormatException('Missing capability identity');
    final name = json['name']?.toString().trim() ?? '';
    return DemoRuntimeCapability(
      id: id,
      name: name.isEmpty ? id : name,
      description: json['description']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      available: json['available'] == true,
      bound:
          json['bound'] == true ||
          (json['bound'] == null && json['available'] == true),
      installed: json['installed'] is bool
          ? json['installed'] as bool
          : json['source'] == 'installed'
          ? true
          : null,
      granted: json['granted'] != false,
      reasonUnavailable: json['reasonUnavailable']?.toString() ?? '',
    );
  }
}

@immutable
class DemoCapabilityCatalog {
  const DemoCapabilityCatalog({
    this.tools = const [],
    this.skills = const [],
    this.mcp = const [],
    this.referencePublishingConfigured = false,
    this.referencePublishingTtlSeconds,
    this.isDemo = false,
  });

  final List<DemoRuntimeCapability> tools;
  final List<DemoRuntimeCapability> skills;
  final List<DemoRuntimeCapability> mcp;
  final bool referencePublishingConfigured;
  final int? referencePublishingTtlSeconds;
  final bool isDemo;

  /// Offline fixtures do not imply a connection to any runtime services.
  static const offline = DemoCapabilityCatalog(isDemo: true);

  factory DemoCapabilityCatalog.fromResponse(Map<String, Object?> response) {
    final multimodal = response['multimodal'];
    final referencePublishing = multimodal is Map
        ? multimodal['referencePublishing']
        : null;
    final referencePublishingMap = referencePublishing is Map
        ? referencePublishing
        : const <Object?, Object?>{};
    final ttl = referencePublishingMap['ttlSeconds'];
    final referencePublishingTtlSeconds = ttl is num && ttl.toInt() > 0
        ? ttl.toInt()
        : null;
    final referencePublishingConfigured =
        referencePublishingMap['configured'] == true;
    if (response['catalog'] case final Map catalog) {
      return DemoCapabilityCatalog(
        tools: _entries(catalog['tools']),
        skills: _entries(catalog['skills']),
        mcp: _entries(catalog['mcp']),
        referencePublishingConfigured: referencePublishingConfigured,
        referencePublishingTtlSeconds: referencePublishingTtlSeconds,
      );
    }
    // Older Harness versions expose their registered tools by provider.
    final tools = <DemoRuntimeCapability>[];
    for (final source in ['web', 'multimodal']) {
      final section = response[source];
      if (section is! Map) continue;
      final configured = source == 'web'
          ? section['configured'] == true
          : section['state'] == 'ready';
      final entries = section['tools'];
      if (entries is! List) continue;
      for (final id in entries.whereType<String>()) {
        tools.add(
          DemoRuntimeCapability(
            id: id,
            name: id,
            source: source,
            available: section['dshToolsBound'] == true && configured,
            bound: section['dshToolsBound'] == true,
          ),
        );
      }
    }
    return DemoCapabilityCatalog(
      tools: List.unmodifiable(tools),
      referencePublishingConfigured: referencePublishingConfigured,
      referencePublishingTtlSeconds: referencePublishingTtlSeconds,
    );
  }

  static List<DemoRuntimeCapability> _entries(Object? value) {
    if (value == null) return const [];
    if (value is! List) throw const FormatException('Invalid DSH catalog');
    return List.unmodifiable([
      for (final entry in value)
        if (entry is Map)
          DemoRuntimeCapability.fromJson(Map<String, Object?>.from(entry))
        else
          throw const FormatException('Invalid DSH capability'),
    ]);
  }
}
