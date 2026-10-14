import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_error_text.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations_en.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations_zh.dart';

void main() {
  final zh = AppLocalizationsZh();
  final en = AppLocalizationsEn();

  test('localizes backend home task codes stored in either error field', () {
    const cases = {
      'VIDEO_GENERATION_FAILED': '视频生成失败',
      'TEXT_GENERATION_TIMEOUT': '文本生成超时，请重试',
      'SCRIPT_GENERATION_FAILED': '剧本生成失败，请重试',
      'RESULT_CHECK_FAILED': '视频完整性检查未通过，已保留生成结果',
      'STORYBOARD_MISSING': '缺少已保存的分镜内容，请确认分镜后再生成',
      'INPUT_SNAPSHOT_MISMATCH': '创作内容已变更，请重新确认生成方案',
      'OUTPUT_RECEIPT_INVALID': '生成结果暂时无法读取，请稍后重试',
      'INSUFFICIENT_POINTS': '积分不足，请充值后重试',
      'INSUFFICIENT_COINS': '积分不足，请充值后重试',
    };
    for (final entry in cases.entries) {
      expect(conversationTaskErrorText(zh, code: entry.key), entry.value);
      expect(conversationTaskErrorText(zh, message: entry.key), entry.value);
    }
  });

  test('explicit known code takes precedence over the backend detail', () {
    expect(
      conversationTaskErrorText(
        zh,
        code: 'INSUFFICIENT_POINTS',
        message: 'VIDEO_GENERATION_FAILED',
      ),
      zh.chatInsufficientPoints,
    );
  });

  test(
    'unknown codes use the fallback and preserve useful backend guidance',
    () {
      expect(
        conversationTaskErrorText(zh, message: ' NEW_FAILURE_123 '),
        zh.chatRunFailed,
      );
      expect(
        conversationTaskErrorText(
          zh,
          code: 'NEW_FAILURE',
          message: 'NEW_FAILURE',
          fallback: zh.chatVideoGenerationFailed,
        ),
        zh.chatVideoGenerationFailed,
      );
      expect(conversationTaskErrorText(zh, message: '  '), zh.chatRunFailed);
      expect(
        conversationTaskErrorText(
          zh,
          code: 'INVALID_REFERENCE',
          message: '请重新选择参考图片',
        ),
        '请重新选择参考图片',
      );
    },
  );

  test('uses the selected locale for known task and API errors', () {
    expect(
      conversationTaskErrorText(en, message: 'VIDEO_GENERATION_FAILED'),
      'Video generation failed',
    );
    expect(
      conversationErrorText(
        const AgentApiException(
          code: 'TEXT_GENERATION_TIMEOUT',
          message: 'TEXT_GENERATION_TIMEOUT',
        ),
        zh,
      ),
      zh.chatTextGenerationTimeout,
    );
    expect(
      conversationErrorText(
        const AgentApiException(code: 'NEW_FAILURE', message: 'NEW_FAILURE'),
        zh,
      ),
      zh.chatRequestFailed,
    );
  });
}
