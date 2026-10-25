import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_session_list_presentation.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

DemoSession _session({
  List<DemoMessage> messages = const [],
  DateTime? updatedAt,
  String time = '',
  Map<String, String> memberNames = const {},
  List<DemoMediaJob> mediaJobs = const [],
}) => DemoSession(
  id: 'real-session',
  title: '小红帽的故事',
  kind: DemoSessionKind.conversation,
  members: const ['writer', 'popi'],
  roles: const [],
  activeMemberId: 'writer',
  messages: messages,
  updatedAt: updatedAt,
  time: time,
  memberNames: memberNames,
  mediaJobs: mediaJobs,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations zh;
  final now = DateTime(2026, 10, 25, 12);

  setUpAll(() async {
    const locale = Locale('zh');
    await GlobalMaterialLocalizations.delegate.load(locale);
    zh = await AppLocalizations.delegate.load(locale);
  });

  DemoSessionListPresentation present(DemoSession session) =>
      DemoSessionListPresentation.fromSession(session, zh, now: now);

  test(
    'uses actual sender names and skips empty progress and skipped replies',
    () {
      final info = present(
        _session(
          memberNames: const {'writer': '首席编剧'},
          messages: const [
            DemoMessage(id: 'reply', text: '整理剧本\n 与分镜', memberId: 'writer'),
            DemoMessage(id: 'skip', text: '不应显示', status: 'skipped'),
            DemoMessage(
              id: 'thinking',
              text: '',
              memberId: 'writer',
              activity: DemoActivity(kind: 'script', status: 'running'),
            ),
          ],
        ),
      );
      expect(info.summary, '首席编剧：整理剧本 与分镜');
      expect(info.activeMessage?.id, 'thinking');
      expect(info.activityMemberId, 'writer');
      expect(info.activityMemberName, '首席编剧');
    },
  );

  test(
    'uses user and removed-member snapshot identity without reattributing history',
    () {
      expect(
        present(
          _session(
            messages: const [
              DemoMessage(id: 'user', text: '保留这个配色', user: true),
            ],
          ),
        ).summary,
        '你：保留这个配色',
      );
      expect(
        present(
          _session(
            messages: const [
              DemoMessage(
                id: 'reply',
                text: '已经准备好了',
                memberId: 'removed',
                memberName: '旧助手',
              ),
            ],
          ),
        ).summary,
        '旧助手：已经准备好了',
      );
      expect(
        present(
          _session(
            messages: const [DemoMessage(id: 'legacy', text: '历史消息')],
          ),
        ).summary,
        'POPi：历史消息',
      );
    },
  );

  test(
    'single assistant summary uses the same given name as its list title',
    () {
      DemoSession single(String title, Map<String, String> names) =>
          DemoSession(
            id: title,
            title: title,
            kind: DemoSessionKind.conversation,
            members: const ['popi'],
            roles: const [],
            messages: const [
              DemoMessage(id: 'reply', text: '你好', memberId: 'popi'),
            ],
            memberNames: names,
          );

      expect(present(single('新建会话', const {'popi': '哈哈'})).summary, '哈哈：你好');
      expect(present(single('Watt', const {})).summary, 'Watt：你好');
    },
  );

  test(
    'unattributed legacy messages use the sole assistant but stay POPi in groups',
    () {
      final soleWriter = DemoSession(
        id: 'writer',
        title: '新建会话',
        kind: DemoSessionKind.conversation,
        members: const ['writer'],
        roles: const [],
        messages: const [DemoMessage(id: 'reply', text: '旧消息')],
        memberNames: const {'writer': 'Watt'},
      );
      expect(present(soleWriter).summary, 'Watt：旧消息');
      expect(
        present(
          _session(
            messages: const [DemoMessage(id: 'group-legacy', text: '群聊旧消息')],
          ),
        ).summary,
        'POPi：群聊旧消息',
      );
    },
  );

  test(
    'empty conversations and attachment-only messages have truthful summaries',
    () {
      expect(present(_session()).summary, '暂无消息');
      expect(
        present(
          _session(
            messages: const [
              DemoMessage(
                id: 'asset',
                text: '',
                user: true,
                assetIds: ['asset-1'],
              ),
            ],
          ),
        ).summary,
        '你：[附件]',
      );
      expect(present(_session()).activeMessage, isNull);
      expect(present(_session()).timeLabel, isEmpty);
    },
  );

  test(
    'formats real local calendar times without replacing them with just now',
    () {
      for (final entry in [
        (DateTime(2026, 10, 25, 11, 10), '11:10'),
        (DateTime(2026, 10, 24, 23, 59), '昨天'),
        (DateTime(2026, 10, 23), '10月23日'),
        (DateTime(2025, 10, 23), '2025年10月23日'),
      ]) {
        expect(present(_session(updatedAt: entry.$1)).timeLabel, entry.$2);
      }
      expect(present(_session(time: '周五')).timeLabel, '周五');
    },
  );

  test(
    'message time takes priority over a later rename or settings update',
    () {
      expect(
        present(
          _session(
            updatedAt: now,
            messages: [
              DemoMessage(
                id: 'reply',
                text: '已经完成',
                createdAt: DateTime(2026, 10, 24),
              ),
            ],
          ),
        ).timeLabel,
        '昨天',
      );
    },
  );

  test(
    'activity time advances the clock while preserving the visible summary',
    () {
      final info = present(
        _session(
          messages: [
            DemoMessage(
              id: 'text',
              text: '先整理剧本',
              createdAt: DateTime(2026, 10, 25, 10, 45),
            ),
            DemoMessage(
              id: 'progress',
              text: '',
              memberId: 'writer',
              createdAt: DateTime(2026, 10, 25, 10, 48),
              activity: const DemoActivity(kind: 'script', status: 'running'),
            ),
          ],
        ),
      );
      expect(info.summary, 'POPi：先整理剧本');
      expect(info.timeLabel, '10:48');
    },
  );

  test('uses local day boundaries and localized English dates', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final session = _session(updatedAt: DateTime(2026, 9, 30, 23, 59));
    expect(
      DemoSessionListPresentation.fromSession(
        session,
        en,
        now: DateTime(2026, 10, 1, 0, 1),
      ).timeLabel,
      'Yesterday',
    );
    expect(
      DemoSessionListPresentation.fromSession(session, en, now: now).timeLabel,
      'Sep 30',
    );
  });

  test('completed text can still show the real pending media worker', () {
    final info = present(
      _session(
        memberNames: const {'writer': '首席编剧'},
        messages: const [
          DemoMessage(
            id: 'reply',
            text: '图片任务已提交',
            memberId: 'writer',
            runId: 'run-1',
            activity: DemoActivity(kind: 'image', status: 'completed'),
          ),
        ],
        mediaJobs: const [
          DemoMediaJob(
            jobId: 'job-1',
            state: 'processing',
            operation: 'text_to_image',
            model: 'image',
            runId: 'run-1',
            memberId: 'writer',
          ),
        ],
      ),
    );
    expect(info.activeMessage?.activity?.kind, 'image');
    expect(info.activityMemberId, 'writer');
    expect(info.summary, '首席编剧：图片任务已提交');
  });

  test('terminal turns do not invent active states', () {
    for (final status in ['completed', 'failed', 'stopped']) {
      final info = present(
        _session(
          messages: [
            DemoMessage(
              id: 'reply',
              text: '真实消息',
              activity: DemoActivity(kind: 'script', status: status),
            ),
          ],
        ),
      );
      expect(info.activeMessage, isNull);
    }
  });

  test('terminal media jobs override stale ingestion flags', () {
    for (final state in ['canceled', 'cancelled', 'failed', 'error']) {
      final info = present(
        _session(
          mediaJobs: [
            DemoMediaJob(
              jobId: 'job-1',
              state: state,
              operation: 'text_to_image',
              model: 'image',
              runId: 'run-1',
              ingestionState: 'pending',
            ),
          ],
        ),
      );
      expect(info.activeMessage, isNull, reason: state);
    }
  });
}
