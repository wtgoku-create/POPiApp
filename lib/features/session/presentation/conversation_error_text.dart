import '../../../l10n/generated/app_localizations.dart';

/// Home tasks store codes in `error`; other task types use `errorCode`.
String conversationTaskErrorText(
  AppLocalizations l10n, {
  String? code,
  String? message,
  String? fallback,
}) {
  final localized =
      _errorCodeText(code?.trim(), l10n) ??
      _errorCodeText(message?.trim(), l10n);
  if (localized != null) return localized;
  final detail = message?.trim() ?? '';
  if (detail.isNotEmpty && !RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(detail)) {
    return detail;
  }
  return fallback ?? l10n.chatRunFailed;
}

String? _errorCodeText(String? code, AppLocalizations l10n) => switch (code) {
  'INSUFFICIENT_POINTS' || 'INSUFFICIENT_COINS' => l10n.chatInsufficientPoints,
  'VIDEO_GENERATION_FAILED' => l10n.chatVideoGenerationFailed,
  'IMAGE_GENERATION_FAILED' => l10n.chatImageGenerationFailed,
  'TEXT_GENERATION_TIMEOUT' => l10n.chatTextGenerationTimeout,
  'TEXT_GENERATION_FAILED' => l10n.chatTextGenerationFailed,
  'SCRIPT_GENERATION_FAILED' => l10n.chatScriptGenerationFailed,
  'TOPIC_GENERATION_FAILED' => l10n.chatTopicGenerationFailed,
  'RESULT_CHECK_FAILED' => l10n.chatResultCheckFailed,
  'OUTPUT_VALIDATION_FAILED' => l10n.chatOutputValidationFailed,
  'STORYBOARD_MISSING' => l10n.chatStoryboardMissing,
  'VIDEO_MISSING' => l10n.chatVideoMissing,
  'INPUT_SNAPSHOT_MISMATCH' || 'INPUT_STALE' => l10n.chatTaskInputChanged,
  'CONFIRMATION_MISMATCH' => l10n.chatTaskConfirmationMismatch,
  'INVALID_VIDEO_PROMPT' ||
  'PROMPT_COMPILATION_FAILED' => l10n.chatVideoPromptInvalid,
  'OUTPUT_RECEIPT_INVALID' ||
  'MEDIA_RECEIPT_MISMATCH' => l10n.chatTaskResultUnavailable,
  'SUBMISSION_FAILED' => l10n.chatTaskSubmissionFailed,
  'DEPENDENCY_UNAVAILABLE' => l10n.chatTaskServiceUnavailable,
  'ROLE_REFERENCE_UNAVAILABLE' => l10n.chatRoleReferenceUnavailable,
  'INVALID_TASK_STAGE' || 'MEDIA_ITEM_FAILED' => l10n.chatRunFailed,
  _ => null,
};
