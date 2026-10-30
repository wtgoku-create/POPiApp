import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/app_url.dart';
import 'ip_account_home.dart';

/// Server-defined choices and validation for an account preference group.
class AccountPreferenceStep {
  const AccountPreferenceStep({
    required this.key,
    required this.title,
    this.options = const [],
    this.allowCustom = true,
    this.required = false,
    this.maxSelections = 20,
    this.maxNameBytes = 300,
  });
  final String key;
  final String title;
  final List<AccountPreferenceOption> options;
  final bool allowCustom;
  final bool required;
  final int maxSelections;
  final int maxNameBytes;

  factory AccountPreferenceStep.fromJson(Map<String, dynamic> json) {
    if (json['key'] is! String ||
        json['title'] is! String ||
        json['options'] is! List ||
        json['selectionMode'] != 'multiple') {
      throw const ApiException();
    }
    return AccountPreferenceStep(
      key: json['key'] as String,
      title: json['title'] as String,
      allowCustom: json['allowCustom'] == true,
      required: json['required'] == true,
      maxSelections: json['maxSelections'] as int,
      maxNameBytes: json['maxNameBytes'] as int,
      options: [
        for (final value in json['options'] as List)
          AccountPreferenceOption.fromJson(value as Map<String, dynamic>),
      ],
    );
  }

  bool accepts(List<String> values) =>
      (!required || values.isNotEmpty) &&
      values.length <= maxSelections &&
      values.every(
        (value) =>
            value.trim().isNotEmpty &&
            utf8.encode(value).length <= maxNameBytes,
      );

  /// Agent catalogs and session configuration share these four preference groups.
  static List<AccountPreferenceStep> parseCatalog(
    Map<String, dynamic> catalog,
  ) {
    if (catalog['schemaVersion'] != 1 || catalog['steps'] is! List) {
      throw const FormatException('Unsupported preference catalog');
    }
    final steps = [
      for (final step in catalog['steps'] as List)
        AccountPreferenceStep.fromJson(step as Map<String, dynamic>),
    ];
    const keys = {
      'contentDirections',
      'audienceFeelings',
      'presentationFormats',
      'targetAudience',
    };
    final received = steps.map((step) => step.key).toSet();
    if (steps.length != keys.length ||
        received.length != keys.length ||
        received.difference(keys).isNotEmpty ||
        steps.any(
          (step) =>
              step.maxSelections < 1 ||
              step.maxSelections > 20 ||
              step.maxNameBytes < 1 ||
              step.maxNameBytes > 2000,
        )) {
      throw const FormatException('Invalid preference catalog');
    }
    return steps;
  }

  static String composeText(Iterable<String> values) {
    final text = values
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .join(' x ');
    if (text.length > 4000) {
      throw const FormatException('Preference text is too long');
    }
    return text;
  }
}

class AccountPreferenceOption {
  const AccountPreferenceOption({
    required this.name,
    this.description = '',
    this.imageUrl,
  });
  final String name;
  final String description;
  final String? imageUrl;
  factory AccountPreferenceOption.fromJson(Map<String, dynamic> json) =>
      AccountPreferenceOption(
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        imageUrl: AppUrl.resolveNullable(json['imageUrl'] as String?),
      );
}

/// Paginated, generated creation archives; drafts are excluded by the server.
class AccountArchivePage {
  const AccountArchivePage({
    required this.items,
    required this.page,
    required this.pageCount,
    required this.total,
  });
  final List<IpAccountCreation> items;
  final int page;
  final int pageCount;
  final int total;
}

/// Read-only frozen archive content, with selectable historical versions.
class AccountCreationArchive {
  const AccountCreationArchive({
    required this.title,
    required this.sections,
    required this.versions,
    this.versionId,
    this.sessionId,
  });
  final String title;
  final Map<String, String> sections;
  final Map<String, int> versions;
  final String? versionId;
  final String? sessionId;
  factory AccountCreationArchive.fromJson(Map<String, dynamic> json) =>
      AccountCreationArchive(
        title: json['title'] as String? ?? '',
        sections: {
          for (final key in [
            'summary',
            'brief',
            'topic',
            'script',
            'storyboard',
            'cast',
            'generation',
          ])
            if (json[key] != null)
              key: json[key] is String
                  ? json[key] as String
                  : const JsonEncoder.withIndent('  ').convert(json[key]),
        },
        versions: {
          for (final version in json['versions'] as List? ?? const [])
            (version as Map)['id'].toString(): version['version'] as int,
        },
        versionId: json['versionId'] as String?,
        sessionId: json['sessionId'] as String?,
      );
}
