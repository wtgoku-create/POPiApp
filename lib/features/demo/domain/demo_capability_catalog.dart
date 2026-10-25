import 'package:flutter/foundation.dart';

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
    this.granted = true,
    this.reasonUnavailable = '',
  });

  final String id;
  final String name;
  final String description;
  final String source;
  final bool available;
  final bool bound;
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
    this.isDemo = false,
  });

  final List<DemoRuntimeCapability> tools;
  final List<DemoRuntimeCapability> skills;
  final List<DemoRuntimeCapability> mcp;
  final bool isDemo;

  /// Offline fixtures do not imply a connection to any runtime services.
  static const offline = DemoCapabilityCatalog(isDemo: true);

  factory DemoCapabilityCatalog.fromResponse(Map<String, Object?> response) {
    if (response['catalog'] case final Map catalog) {
      return DemoCapabilityCatalog(
        tools: _entries(catalog['tools']),
        skills: _entries(catalog['skills']),
        mcp: _entries(catalog['mcp']),
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
    return DemoCapabilityCatalog(tools: List.unmodifiable(tools));
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
