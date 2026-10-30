import 'package:flutter/foundation.dart';

@immutable
class V2QuestionOption {
  const V2QuestionOption({required this.label, this.description = ''});

  final String label;
  final String description;

  Map<String, Object?> toJson() => {
    'label': label,
    if (description.isNotEmpty) 'description': description,
  };

  factory V2QuestionOption.fromJson(Object? value) {
    if (value is String) return V2QuestionOption(label: value);
    final json = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    return V2QuestionOption(
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

@immutable
class V2QuestionField {
  const V2QuestionField({
    required this.id,
    required this.question,
    this.header = '',
    this.options = const [],
    this.multiSelect = false,
  });

  final String id;
  final String question;
  final String header;
  final List<V2QuestionOption> options;
  final bool multiSelect;

  Map<String, Object?> toJson() => {
    'id': id,
    'question': question,
    if (header.isNotEmpty) 'header': header,
    'options': options.map((option) => option.toJson()).toList(),
    if (multiSelect) 'multiSelect': true,
  };

  factory V2QuestionField.fromJson(Map<String, Object?> json) =>
      V2QuestionField(
        id: json['id']?.toString() ?? '',
        question: json['question']?.toString() ?? '',
        header: json['header']?.toString() ?? '',
        options: ((json['options'] as List?) ?? const [])
            .map(V2QuestionOption.fromJson)
            .where((option) => option.label.isNotEmpty)
            .toList(),
        multiSelect: json['multiSelect'] == true,
      );
}

@immutable
class V2QuestionAnswer {
  const V2QuestionAnswer({
    required this.id,
    this.selected = const [],
    this.custom = '',
  });

  final String id;
  final List<String> selected;
  final String custom;

  Map<String, Object?> toJson() => {
    'id': id,
    'selected': selected,
    if (custom.isNotEmpty) 'custom': custom,
  };

  factory V2QuestionAnswer.fromJson(Map<String, Object?> json) =>
      V2QuestionAnswer(
        id: json['id']?.toString() ?? '',
        selected: ((json['selected'] as List?) ?? const [])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(),
        custom: json['custom']?.toString() ?? '',
      );
}

@immutable
class V2Question {
  const V2Question({
    required this.id,
    required this.revision,
    required this.status,
    required this.questions,
    this.title = '',
    this.answers = const [],
  });

  final String id;
  final int revision;
  final String status;
  final String title;
  final List<V2QuestionField> questions;
  final List<V2QuestionAnswer> answers;

  bool get isPending => status == 'pending';

  /// Converts the DSH selected/custom answer projection into card values.
  Map<String, Object?> get answer {
    final byId = {for (final item in answers) item.id: item};
    return {
      for (final field in questions)
        if (byId[field.id] case final item?)
          field.id: field.multiSelect
              ? <String>{
                  ...item.selected,
                  if (item.custom.trim().isNotEmpty) item.custom.trim(),
                }.toList()
              : item.custom.trim().isNotEmpty
              ? item.custom.trim()
              : item.selected.firstOrNull ?? '',
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'status': status,
    if (title.isNotEmpty) 'title': title,
    'questions': questions.map((question) => question.toJson()).toList(),
    if (answers.isNotEmpty)
      'answers': answers.map((answer) => answer.toJson()).toList(),
  };

  factory V2Question.fromJson(Map<String, Object?> json) => V2Question(
    id: json['id']?.toString() ?? '',
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    status: json['status']?.toString() ?? 'pending',
    title: json['title']?.toString() ?? '',
    questions: ((json['questions'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (value) => V2QuestionField.fromJson(Map<String, Object?>.from(value)),
        )
        .where((field) => field.id.isNotEmpty && field.question.isNotEmpty)
        .toList(),
    answers: ((json['answers'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              V2QuestionAnswer.fromJson(Map<String, Object?>.from(value)),
        )
        .where((answer) => answer.id.isNotEmpty)
        .toList(),
  );
}
