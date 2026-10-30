import 'dart:convert';

class DemoPreferenceOption {
  const DemoPreferenceOption(this.name, this.description);
  final String name;
  final String description;
}

class DemoPreferenceStep {
  const DemoPreferenceStep({
    required this.key,
    required this.title,
    required this.options,
    required this.maxSelections,
    required this.maxNameBytes,
    required this.allowCustom,
    required this.required,
  });

  final String key;
  final String title;
  final List<DemoPreferenceOption> options;
  final int maxSelections;
  final int maxNameBytes;
  final bool allowCustom;
  final bool required;

  static List<DemoPreferenceStep> parse(Map<String, dynamic> value) {
    const keys = {
      'contentDirections',
      'audienceFeelings',
      'presentationFormats',
      'targetAudience',
    };
    if (value['schemaVersion'] != 1 || value['steps'] is! List) {
      throw const FormatException('Unsupported preference catalog');
    }
    final steps = (value['steps'] as List)
        .map((raw) {
          final step = Map<String, dynamic>.from(raw as Map);
          if (!keys.contains(step['key']) ||
              step['selectionMode'] != 'multiple' ||
              step['maxSelections'] is! int ||
              (step['maxSelections'] as int) < 1 ||
              (step['maxSelections'] as int) > 20 ||
              step['maxNameBytes'] is! int ||
              (step['maxNameBytes'] as int) < 1 ||
              (step['maxNameBytes'] as int) > 2000) {
            throw const FormatException('Invalid preference step');
          }
          return DemoPreferenceStep(
            key: step['key'] as String,
            title: step['title'] as String,
            maxSelections: step['maxSelections'] as int,
            maxNameBytes: step['maxNameBytes'] as int,
            allowCustom: step['allowCustom'] == true,
            required: step['required'] == true,
            options: (step['options'] as List)
                .map((raw) {
                  final option = Map<String, dynamic>.from(raw as Map);
                  return DemoPreferenceOption(
                    option['name'] as String,
                    option['description'] as String,
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    if (steps.length != keys.length ||
        steps.map((step) => step.key).toSet().length != keys.length) {
      throw const FormatException('Incomplete preference catalog');
    }
    return steps;
  }

  /// 选项仅用于初始化，分隔符不承担可反向解析的存储语义。
  String? compose(Iterable<String> selected, String custom) {
    final values = {
      ...selected.map((s) => s.trim()),
      if (custom.trim().isNotEmpty) custom.trim(),
    }.where((s) => s.isNotEmpty).toList();
    if ((required && values.isEmpty) ||
        values.length > maxSelections ||
        (!allowCustom && custom.trim().isNotEmpty) ||
        values.any(
          (s) =>
              utf8.encode(s).length > maxNameBytes ||
              RegExp(r'[\x00-\x08\x0b-\x1f\x7f-\x9f]').hasMatch(s),
        )) {
      return null;
    }
    final text = values.join(' x ');
    return text.length <= 4000 ? text : null;
  }
}
