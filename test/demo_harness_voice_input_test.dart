import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/speech/speech_input.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/speech_input_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

class _Speech implements SpeechInput {
  late void Function(String) result;
  late void Function() done;
  int stops = 0;

  @override
  Future<void> start({
    required String locale,
    required void Function(String) onResult,
    required void Function(String) onError,
    required void Function() onDone,
  }) async {
    expect(locale, 'zh-CN');
    result = onResult;
    done = onDone;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

class _HarnessApi extends NetworkAgentApi {
  _HarnessApi(super.dio);

  int sendCalls = 0;

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => {
    'session': _sessionRecord,
    'lastSeq': 1,
    'messages': [_messageRecord],
    'runs': <Object?>[],
    'mediaJobs': <Object?>[],
    'assets': <Object?>[],
  };

  @override
  Future<Map<String, dynamic>> sendSessionMessage(
    String id, {
    required String clientRequestId,
    required String text,
    String? taskId,
    List<String>? mediaIds,
    List<String>? contextRoleIds,
    CancelToken? cancelToken,
  }) async {
    sendCalls++;
    return {
      'sessionId': id,
      'runId': 'unexpected-run',
      'messageId': 'unexpected-message',
      'state': 'queued',
    };
  }
}

const _message = DemoMessage(
  id: 'assistant-1',
  text: '已有消息',
  memberId: 'popi',
  memberName: 'POPi',
  configRevision: 1,
);

const _session = DemoSession(
  id: 'harness-session',
  title: 'Harness 会话',
  kind: DemoSessionKind.conversation,
  members: ['popi'],
  roles: [],
  messages: [_message],
  memberCapabilities: {
    'popi': ['character', 'script', 'image'],
  },
  activeMemberId: 'popi',
  configurationStatus: 'configured',
  configRevision: 1,
  serverRevision: 1,
  lastSeq: 1,
);

const _configuration = <String, Object?>{
  'members': ['popi'],
  'roles': <String>[],
  'capabilities': ['character', 'script', 'image'],
  'memberCapabilities': <String, Object?>{
    'popi': ['character', 'script', 'image'],
  },
  'memberNames': <String, String>{},
  'memberInstructions': <String, String>{},
  'memberAvatars': <String, String>{},
  'memberColors': <String, int>{},
  'workMode': 'onDemand',
  'activeMemberId': 'popi',
  'direction': '',
  'positioning': '',
  'roleProfiles': <String, Object?>{},
};

const _sessionRecord = <String, Object?>{
  'id': 'harness-session',
  'title': 'Harness 会话',
  'kind': 'conversation',
  'revision': 1,
  'archived': false,
  'configuration': _configuration,
  'configurationStatus': 'configured',
  'configRevision': 1,
};

const _messageRecord = <String, Object?>{
  'id': 'assistant-1',
  'role': 'assistant',
  'text': '已有消息',
  'status': 'completed',
  'memberId': 'popi',
  'memberName': 'POPi',
  'configRevision': 1,
  'createdAt': '2026-10-24T00:00:00.000Z',
};

void main() {
  testWidgets(
    'Harness chat keeps dictated text as a draft and does not send it',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        DemoRepository.harnessStorageKey: jsonEncode({
          'sessions': [_session.toJson()],
          'assets': <Object?>[],
        }),
      });
      final storage = PreferencesStorage(await SharedPreferences.getInstance());
      final dio = Dio();
      final api = _HarnessApi(dio);
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 0,
      )..restore();
      final speech = _Speech();
      addTearDown(() {
        repository.dispose();
        dio.close(force: true);
        toastification.dismissAll(delayForAnimation: false);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            speechInputFactoryProvider.overrideWithValue(() => speech),
          ],
          child: ToastificationWrapper(
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: DemoChatPage(
                repository: repository,
                sessionId: 'harness-session',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(ExtendedTextField);
      final mic = find.byKey(const Key('popi-voice-input'));
      expect(input, findsOneWidget);
      expect(mic, findsOneWidget);
      final inputController = tester
          .widget<ExtendedTextField>(input)
          .controller!;
      inputController.value = const TextEditingValue(
        text: '原草稿：',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pumpAndSettle();
      final originalMessageCount = repository
          .session('harness-session')
          .messages
          .length;

      await tester.tap(mic);
      await tester.pumpAndSettle();
      speech.result('语音');
      await tester.pumpAndSettle();
      await tester.tap(mic);
      await tester.pump();
      expect(speech.stops, 1);
      speech.result('语音补充');
      speech.done();
      await tester.pumpAndSettle();

      expect(inputController.text, '原草稿：语音补充');
      expect(
        repository.session('harness-session').messages,
        hasLength(originalMessageCount),
      );
      expect(api.sendCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
