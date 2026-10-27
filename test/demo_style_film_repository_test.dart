import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_controller.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_style_film_job_card.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

const _selection = DemoStyleFilmSelection(
  styleId: 'impasto',
  styleNameZh: '油画厚涂',
  styleNameEn: 'Impasto',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreferencesStorage storage;
  late Dio dio;
  late _FilmApi api;
  late DemoRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      DemoRepository.storageKey: '{"sessions":[],"assets":[]}',
      DemoRepository.harnessStorageKey: '{"sessions":[],"assets":[]}',
    });
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
    api = _FilmApi(dio);
    repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 0,
    )..restore();
  });
  tearDown(() {
    repository.dispose();
    dio.close(force: true);
  });

  test(
    'new Bot identities are distinct, stable across edits, and copied with skills',
    () async {
      final local = DemoRepository(storage)..restore();
      addTearDown(local.dispose);
      const profile = DemoAssistantProfile(
        id: 'draft',
        memberId: 'popi',
        name: '导演',
        skillIds: [demoStyleFilmSkillId],
      );
      final first = await local.createSession(
        '一',
        DemoSessionKind.conversation,
        assistant: profile,
      );
      final second = await local.createSession(
        '二',
        DemoSessionKind.conversation,
        assistant: profile,
      );
      final stableId = local.session(first).botIdFor('popi');
      expect(stableId, startsWith('bot:'));
      expect(local.session(second).botIdFor('popi'), isNot(stableId));
      await local.updateSession(
        first,
        (s) => s.copyWith(memberNames: {'popi': '改名导演'}),
      );
      expect(local.session(first).botIdFor('popi'), stableId);
      final saved = local.assistantProfiles.singleWhere(
        (p) => p.id == stableId,
      );
      final copy = await local.createSession(
        '复用',
        DemoSessionKind.conversation,
        assistant: saved,
      );
      expect(local.session(copy).botIdFor('popi'), stableId);
      expect(local.session(copy).skillsFor('popi'), [demoStyleFilmSkillId]);
      expect(local.session(copy).filmDrafts, isEmpty);
      expect(local.session(copy).filmJobs, isEmpty);
      final restored = DemoRepository(storage)..restore();
      addTearDown(restored.dispose);
      expect(restored.session(first).botIdFor('popi'), stableId);
    },
  );

  test(
    'legacy identities depend on session and slot, never mutable profile text',
    () {
      const old = DemoSession(
        id: 's-old',
        title: 'Old',
        kind: DemoSessionKind.conversation,
        members: ['popi'],
        roles: [],
        messages: [],
        memberNames: {'popi': 'Custom'},
      );
      expect(old.botIdFor('popi'), 'legacy:s-old:popi');
      final restored = DemoSession.fromJson(old.toJson());
      expect(
        restored.copyWith(memberNames: {'popi': 'New'}).botIdFor('popi'),
        old.botIdFor('popi'),
      );
      expect(restored.skillsFor('popi'), isEmpty);
      expect(restored.filmJobs, isEmpty);
    },
  );

  test(
    'drafts persist per session and Bot, survive server refresh and disable, and clear explicitly',
    () async {
      await repository.refreshSessions();
      await repository.updateStyleFilmDraft('s1', 'bot:director', _selection);
      api.configuration['memberSkills'] = {'popi': <String>[]};
      await repository.refreshSession('s1');
      expect(repository.session('s1').skillsFor('popi'), isEmpty);
      expect(
        repository.styleFilmDraft('s1', 'bot:director')?.styleId,
        'impasto',
      );
      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(
        restored.styleFilmDraft('s1', 'bot:director')?.styleNameZh,
        '油画厚涂',
      );
      expect(
        () => repository.updateStyleFilmDraft('s1', 'bot:other', _selection),
        throwsArgumentError,
      );
      await repository.updateStyleFilmDraft('s1', 'bot:director', null);
      expect(repository.styleFilmDraft('s1', 'bot:director'), isNull);
      final raw =
          jsonDecode(storage.getString(DemoRepository.harnessStorageKey)!)
              as Map;
      expect((raw['sessions'] as List).single['filmDrafts'], isNull);
    },
  );

  test(
    'configuration keeps skills separate from six product capabilities and excludes local drafts',
    () async {
      await repository.refreshSessions();
      await repository.updateStyleFilmDraft('s1', 'bot:director', _selection);
      await repository.updateSession(
        's1',
        (s) => s.copyWith(memberSkills: {'popi': []}),
      );
      expect(api.updatedConfiguration?['memberSkills'], {'popi': []});
      expect(api.updatedConfiguration?['memberBotIds'], {
        'popi': 'bot:director',
      });
      expect(
        api.updatedConfiguration?['capabilities'],
        DemoSession.defaultCapabilities,
      );
      expect(api.updatedConfiguration?.containsKey('filmDrafts'), isFalse);
      expect(api.expectedConfigRevision, 1);
      expect(repository.styleFilmDraft('s1', 'bot:director'), isNotNull);
    },
  );

  test(
    'catalog preserves real readiness and resolves authenticated poster routes',
    () async {
      final catalog = await repository.loadStyleFilmCatalog(
        q: '墨',
        category: 'paint',
        page: 2,
        pageSize: 8,
      );
      expect(api.catalogQuery, {
        'q': '墨',
        'category': 'paint',
        'page': 2,
        'pageSize': 8,
      });
      expect(catalog.total, 59);
      expect(catalog.list.single.ready, isFalse);
      expect(
        catalog.list.single.reasonUnavailable,
        'compatibility_not_verified',
      );
      expect(
        catalog.list.single.posterUrl,
        'http://127.0.0.1:3084/api_agent/v2/style-films/styles/ink-wash/poster',
      );
      expect(catalog.supports.soundtracks, ['none']);
      expect(
        catalog.supports.accepts(_selection.copyWith(soundtrack: 'music')),
        isFalse,
      );
      expect(
        () => api.resolveStyleFilmPosterUrl('https://other.example/poster'),
        throwsFormatException,
      );
      final offline = DemoRepository(storage)..restore();
      addTearDown(offline.dispose);
      expect((await offline.loadStyleFilmCatalog()).available, isFalse);
      expect((await offline.loadStyleFilmCatalog()).list, isEmpty);
    },
  );

  test(
    'catalog keeps filtered ready totals and complete categories independent of its page',
    () {
      final catalog = DemoStyleFilmCatalog.fromJson({
        'readyCount': 6,
        'reasonUnavailableCode': 'runtime_unavailable',
        'categories': [
          {'id': 'paint', 'nameZh': '手绘与绘画', 'nameEn': 'Painting'},
          {'id': 'game', 'nameZh': '游戏', 'nameEn': 'Games'},
        ],
        'list': [
          {'id': 'impasto', 'ready': true, 'supported': true},
          {
            'id': 'unverified',
            'ready': false,
            'supported': true,
            'reasonUnavailableCode': 'unverified_style',
          },
          {
            'id': 'unsupported',
            'ready': false,
            'supported': false,
            'reasonUnavailableCode': 'unsupported_style',
          },
        ],
        'pageInfo': {'page': 1, 'pageSize': 3, 'total': 59, 'pageCount': 20},
      });
      expect(catalog.readyCount, 6);
      expect(catalog.reasonUnavailableCode, 'runtime_unavailable');
      expect(catalog.categories.map((category) => category.id), [
        'paint',
        'game',
      ]);
      expect(catalog.categories.last.nameFor('zh'), '游戏');
      expect(catalog.categories.last.nameFor('en'), 'Games');
      expect(catalog.list[1].supported, isTrue);
      expect(catalog.list[1].reasonUnavailableCode, 'unverified_style');
      expect(catalog.list[2].supported, isFalse);
      expect(catalog.list[2].reasonUnavailableCode, 'unsupported_style');
      expect(catalog.pageSize, 3);
      expect(catalog.total, 59);
    },
  );

  test(
    'older catalogs use safe optional defaults and page readiness fallback',
    () {
      final catalog = DemoStyleFilmCatalog.fromJson({
        'list': [
          {'id': 'ready', 'ready': true},
          {'id': 'unknown', 'ready': false},
        ],
      });
      expect(catalog.readyCount, 1);
      expect(catalog.categories, isEmpty);
      expect(catalog.reasonUnavailableCode, isEmpty);
      expect(catalog.list.first.supported, isTrue);
      expect(catalog.list.last.supported, isFalse);
      expect(catalog.list.last.reasonUnavailableCode, isEmpty);
      expect(const DemoStyleFilmCatalog().readyCount, 0);
      expect(
        const DemoStyleFilmCatalog(
          list: [DemoStyleFilmStyle(id: 'ready', ready: true)],
        ).readyCount,
        1,
      );
    },
  );

  test(
    'snapshot film jobs and real previews restore independently of completed text runs',
    () async {
      api.job = _job();
      await repository.refreshSessions();
      final job = repository.styleFilmJob('s1', 'film-1')!;
      expect(job.isAwaitingReview, isTrue);
      expect(
        job.storyboard.single.previewUrl,
        'http://127.0.0.1:3084/api_agent/v2/assets/preview-1/content',
      );
      expect(repository.session('s1').messages.single.filmJobId, 'film-1');
      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(restored.styleFilmJob('s1', 'film-1')?.allowedActions, [
        'approve',
        'revise',
      ]);
      api.job = _job(revision: 0, updatedAt: '2026-10-25T00:00:00Z');
      api.seq++;
      await repository.refreshSession('s1');
      expect(repository.styleFilmJob('s1', 'film-1')?.revision, 1);
    },
  );

  test(
    'unknown send preserves full request and draft; acceptance clears only matching selection',
    () async {
      await repository.refreshSessions();
      await repository.updateStyleFilmDraft('s1', 'bot:director', _selection);
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      api.failSend = true;
      await expectLater(
        controller.send(
          'A new story',
          [],
          l,
          skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(repository.styleFilmDraft('s1', 'bot:director'), isNotNull);
      await controller.send(
        'A new story',
        [],
        l,
        skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
      );
      expect(api.sent[0]['clientRequestId'], api.sent[1]['clientRequestId']);
      expect(api.sent[1]['skillInvocation'], {
        'skillId': demoStyleFilmSkillId,
        'arguments': _selection.toArguments(),
      });
      expect(
        (api.sent[1]['skillInvocation'] as Map)['arguments'],
        isNot(contains('styleNameZh')),
      );
      expect(repository.styleFilmDraft('s1', 'bot:director'), isNull);
    },
  );

  test(
    'changed invocation gets a fresh request; disabled skill omits hidden selection',
    () async {
      await repository.refreshSessions();
      await repository.updateStyleFilmDraft('s1', 'bot:director', _selection);
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      api.failSend = true;
      await expectLater(
        controller.send(
          'Story',
          [],
          l,
          skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await controller.send(
        'Story',
        [],
        l,
        skillInvocation: DemoStyleFilmInvocation(
          selection: _selection.copyWith(styleId: 'ink-wash'),
        ),
      );
      expect(
        api.sent[0]['clientRequestId'],
        isNot(api.sent[1]['clientRequestId']),
      );
      expect(
        repository.styleFilmDraft('s1', 'bot:director')?.styleId,
        'impasto',
      );
      api.configuration['memberSkills'] = {'popi': <String>[]};
      await repository.refreshSession('s1');
      await controller.send(
        'Normal chat',
        [],
        l,
        skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
      );
      expect(api.sent.last.containsKey('skillInvocation'), isFalse);
      expect(repository.styleFilmDraft('s1', 'bot:director'), isNotNull);
    },
  );

  test(
    'review retries reuse complete request and refresh authoritative job',
    () async {
      api.job = _job();
      await repository.refreshSessions();
      api.failReview = true;
      await expectLater(
        repository.reviewStyleFilm(
          's1',
          'film-1',
          expectedRevision: 1,
          action: 'revise',
          notes: '  Change the complete plan  ',
        ),
        throwsA(isA<TimeoutException>()),
      );
      await repository.reviewStyleFilm(
        's1',
        'film-1',
        expectedRevision: 1,
        action: 'revise',
        notes: 'Change the complete plan',
      );
      expect(api.reviews[0], api.reviews[1]);
      expect(api.reviews.last['notes'], 'Change the complete plan');
      expect(repository.styleFilmJob('s1', 'film-1')?.revision, 2);
      expect(
        () => repository.reviewStyleFilm(
          's1',
          'film-1',
          expectedRevision: 2,
          action: 'revise',
          notes: 'x' * 2001,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'review conflict refreshes current revision and keeps local draft',
    () async {
      api.job = _job();
      await repository.refreshSessions();
      await repository.updateStyleFilmDraft('s1', 'bot:director', _selection);
      api.conflictReview = true;
      await expectLater(
        repository.reviewStyleFilm(
          's1',
          'film-1',
          expectedRevision: 1,
          action: 'approve',
        ),
        throwsA(isA<AgentApiException>()),
      );
      expect(repository.styleFilmJob('s1', 'film-1')?.revision, 2);
      expect(repository.styleFilmDraft('s1', 'bot:director'), isNotNull);
    },
  );

  test(
    'unknown film submission survives a new repository and controller',
    () async {
      await repository.refreshSessions();
      await repository.updateStyleFilmDraft('s1', 'bot:director', _selection);
      final first = DemoChatController(repository, 's1');
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      api.failSend = true;
      await expectLater(
        first.send(
          'Persist this exact story',
          [],
          l,
          skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
        ),
        throwsA(isA<TimeoutException>()),
      );
      final requestId = api.sent.single['clientRequestId'];
      expect(
        repository
            .session('s1')
            .filmPendingRequests['bot:director']
            ?.clientRequestId,
        requestId,
      );
      first.dispose();
      repository.dispose();
      repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 0,
      )..restore();
      await repository.refreshSessions();
      final reopened = DemoChatController(repository, 's1');
      addTearDown(reopened.dispose);
      await reopened.send(
        'Persist this exact story',
        [],
        l,
        skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
      );
      expect(api.sent.last['clientRequestId'], requestId);
      expect(repository.session('s1').filmPendingRequests, isEmpty);
      expect(repository.styleFilmDraft('s1', 'bot:director'), isNull);
    },
  );

  test(
    'normal send while disabled never replays or clears an uncertain film request',
    () async {
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      api.failSend = true;
      await expectLater(
        controller.send(
          'Film story',
          [],
          l,
          skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
        ),
        throwsA(isA<TimeoutException>()),
      );
      final requestId = api.sent.single['clientRequestId'];
      api.configuration['memberSkills'] = {'popi': <String>[]};
      await repository.refreshSession('s1');
      await controller.send(
        'Normal text',
        [],
        l,
        skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
      );
      expect(api.sent.last.containsKey('skillInvocation'), isFalse);
      expect(api.sent.last['clientRequestId'], isNot(requestId));
      expect(
        repository
            .session('s1')
            .filmPendingRequests['bot:director']
            ?.clientRequestId,
        requestId,
      );
      api.configuration['memberSkills'] = {
        'popi': [demoStyleFilmSkillId],
      };
      await repository.refreshSession('s1');
      await controller.send(
        'Film story',
        [],
        l,
        skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
      );
      expect(api.sent.last['clientRequestId'], requestId);
      expect(repository.session('s1').filmPendingRequests, isEmpty);
    },
  );

  test('pending request keys isolate full bodies and Bot identities', () async {
    await repository.refreshSessions();
    expect(
      await repository.prepareStyleFilmRequest(
        's1',
        'bot:director',
        body: 'body-a',
        proposedRequestId: 'first',
      ),
      'first',
    );
    expect(
      await repository.prepareStyleFilmRequest(
        's1',
        'bot:director',
        body: 'body-a',
        proposedRequestId: 'second',
      ),
      'first',
    );
    expect(
      await repository.prepareStyleFilmRequest(
        's1',
        'bot:director',
        body: 'body-b',
        proposedRequestId: 'third',
      ),
      'third',
    );
    await expectLater(
      repository.prepareStyleFilmRequest(
        's1',
        'bot:other',
        body: 'body-b',
        proposedRequestId: 'fourth',
      ),
      throwsArgumentError,
    );
    expect(
      repository
          .session('s1')
          .filmPendingRequests['bot:director']
          ?.clientRequestId,
      'third',
    );
  });

  test('film watcher continues without an active text run', () async {
    api.job = {..._job(), 'state': 'rendering', 'stage': 'rendering'};
    api.beforeSnapshot = () {
      if (api.snapshotCalls >= 2) {
        api.job = {
          ..._job(updatedAt: '2026-10-25T03:00:00Z'),
          'state': 'completed',
          'stage': 'completed',
          'allowedActions': <String>[],
        };
        api.seq++;
      }
    };
    await repository.refreshSessions();
    await Future<void>.delayed(Duration.zero);
    expect(api.snapshotCalls, greaterThanOrEqualTo(2));
    expect(repository.styleFilmJob('s1', 'film-1')?.isCompleted, isTrue);
    expect(repository.isSessionRunning('s1'), isFalse);
  });

  test(
    'unsupported film references fail before submission and retain the selection',
    () async {
      await repository.refreshSessions();
      await repository.updateStyleFilmDraft('s1', 'bot:director', _selection);
      for (final roles in [false, true]) {
        await expectLater(
          repository.sendHarnessMessage(
            's1',
            clientRequestId: 'request-$roles',
            text: 'A story',
            mediaIds: roles ? const [] : const ['image-1'],
            contextRoleIds: roles ? const ['cat'] : const [],
            skillInvocation: const DemoStyleFilmInvocation(
              selection: _selection,
            ),
          ),
          throwsA(
            isA<AgentApiException>().having(
              (e) => e.code,
              'code',
              'style_film_references_unsupported',
            ),
          ),
        );
      }
      expect(api.sent, isEmpty);
      expect(repository.styleFilmDraft('s1', 'bot:director'), isNotNull);
    },
  );

  testWidgets(
    'accepted film planning failures retain their task card without generic error toast',
    (tester) async {
      api.job = {
        ..._job(),
        'state': 'failed_planning',
        'stage': 'planning',
        'allowedActions': ['revise'],
        'error': {
          'code': 'planning_failed',
          'message': 'Planner failed',
          'retryable': true,
        },
      };
      api.runState = 'failed';
      await tester.runAsync(repository.refreshSessions);
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      late BuildContext context;
      var retries = 0;
      await tester.pumpWidget(
        ToastificationWrapper(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (c) {
                context = c;
                return Scaffold(
                  body: DemoStyleFilmJobCard(
                    job: repository.styleFilmJob('s1', 'film-1')!,
                    onOpen: () {},
                    onRetry: () => retries++,
                  ),
                );
              },
            ),
          ),
        ),
      );
      final success = await tester.runAsync(
        () => demoPerform(context, () async {
          expect(
            await controller.send(
              'A failed planning story',
              [],
              l,
              skillInvocation: const DemoStyleFilmInvocation(
                selection: _selection,
              ),
            ),
            isTrue,
          );
        }),
      );
      await tester.pump();
      expect(success, isTrue);
      expect(find.text(l.demoStyleFilmFailed), findsOneWidget);
      expect(find.text(l.demoStorageError), findsNothing);
      expect(find.text(l.networkRequestFailed), findsNothing);
      expect(repository.styleFilmJob('s1', 'film-1')?.allowedActions, [
        'revise',
      ]);
      await tester.tap(
        find.byKey(const ValueKey('demo-style-film-job-film-1')),
      );
      expect(retries, 1);
      await tester.runAsync(
        () => controller.send(
          'A failed planning story',
          [],
          l,
          skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
        ),
      );
      expect(
        api.sent[0]['clientRequestId'],
        isNot(api.sent[1]['clientRequestId']),
      );
    },
  );

  test(
    'resuming a film run that becomes interrupted preserves business failure',
    () async {
      api.runState = 'running';
      api.job = {..._job(), 'state': 'planning', 'stage': 'planning'};
      repository.dispose();
      repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 2,
      )..restore();
      await repository.refreshSessions();
      api.beforeSnapshot = () {
        if (api.snapshotCalls >= 4) {
          api.runState = 'interrupted';
          api.job = {
            ..._job(),
            'state': 'failed_planning_unknown',
            'stage': 'planning',
            'allowedActions': ['revise'],
          };
        }
      };
      await repository.resumeHarnessSession('s1');
      expect(
        repository.styleFilmJob('s1', 'film-1')?.state,
        'failed_planning_unknown',
      );
      expect(repository.styleFilmJob('s1', 'film-1')?.allowedActions, [
        'revise',
      ]);
      expect(repository.isSessionRunning('s1'), isFalse);
    },
  );

  test(
    'accepted film clears generic pending before snapshot disconnect so later sends are new',
    () async {
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      api.beforeSnapshot = () {
        if (api.snapshotCalls == 2) {
          throw TimeoutException('Snapshot disconnected after acceptance');
        }
      };
      await expectLater(
        controller.send(
          'Accepted film',
          [],
          l,
          skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(repository.session('s1').filmPendingRequests, isEmpty);
      await controller.send(
        'Accepted film',
        [],
        l,
        skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
      );
      expect(
        api.sent[0]['clientRequestId'],
        isNot(api.sent[1]['clientRequestId']),
      );
    },
  );

  test(
    'normal message retains its existing generic pending after snapshot disconnect',
    () async {
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      api.beforeSnapshot = () {
        if (api.snapshotCalls == 2) {
          throw TimeoutException('Snapshot disconnected after acceptance');
        }
      };
      await expectLater(
        controller.send('Normal message', [], l),
        throwsA(isA<TimeoutException>()),
      );
      await controller.send('Normal message', [], l);
      expect(api.sent[0]['clientRequestId'], api.sent[1]['clientRequestId']);
    },
  );

  test(
    'accepted film planning stays busy without enabling generic Stop before its first snapshot',
    () async {
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      api.snapshotGate = Completer<void>();
      final sending = controller.send(
        'Planning film',
        [],
        l,
        skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
      );
      for (var i = 0; i < 30 && !controller.running; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(controller.running, isTrue);
      expect(controller.busy, isTrue);
      expect(controller.canStop, isFalse);
      await controller.stop();
      expect(api.stopCalls, 0);
      api.snapshotGate!.complete();
      await sending;
      expect(controller.running, isFalse);
    },
  );

  test(
    'Stop follows the active run rather than an older planning film job',
    () async {
      api.job = {
        ..._job(),
        'runId': 'old-film-run',
        'state': 'planning',
        'stage': 'planning',
      };
      api.runState = 'running';
      api.runFilmJobId = 'film-1';
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      expect(controller.canStop, isFalse);
      api.runFilmJobId = '';
      api.seq++;
      await repository.refreshSession('s1');
      expect(repository.styleFilmJob('s1', 'film-1')?.state, 'planning');
      expect(controller.canStop, isTrue);
    },
  );

  test(
    'restored film planning projects Stop support before exposing the resumed running state',
    () async {
      api.runState = 'running';
      api.runFilmJobId = 'film-1';
      await repository.refreshSessions();
      repository.dispose();
      repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 2,
      )..restore();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      expect(controller.running, isFalse);
      api.snapshotGate = Completer<void>();
      api.gatedSnapshotCall = api.snapshotCalls + 2;
      final resuming = repository.resumeHarnessSession('s1');
      for (var i = 0; i < 30 && !controller.running; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(controller.running, isTrue);
      expect(controller.busy, isTrue);
      expect(controller.canStop, isFalse);
      api.runState = 'completed';
      api.snapshotGate!.complete();
      await resuming;
      expect(controller.running, isFalse);
    },
  );

  test(
    'HTTP empty-text film assistant rows stay visible and job-only changes update the virtual item',
    () async {
      api.snapshotMessages = _filmHttpMessages();
      api.job = {
        ..._job(),
        'storyboard': List.generate(
          3,
          (index) => {
            'id': 'shot-${index + 1}',
            'title': 'Shot ${index + 1}',
            'description': 'A genuine storyboard frame',
            'startSeconds': index * 5,
            'durationSeconds': 5,
            'previewAssetId': 'preview-${index + 1}',
            'previewUrl': '/api_agent/v2/assets/preview-${index + 1}/content',
          },
        ),
      };
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(controller.chatController.messages.map((message) => message.id), [
        'user-film-1',
        'm1',
      ]);
      final initial = controller.chatController.messages.last;
      final initialDemo = initial.metadata!['demo'] as DemoMessage;
      expect(initialDemo.text, isEmpty);
      expect(initialDemo.filmJobId, 'film-1');
      final fingerprint = initial.metadata!['filmJobFingerprint'] as String;
      expect((jsonDecode(fingerprint) as Map)['storyboard'], hasLength(3));
      final operations = <chat.ChatOperation>[];
      final subscription = controller.chatController.operationsStream.listen(
        operations.add,
      );
      addTearDown(subscription.cancel);
      api.job = {
        ...api.job!,
        'revision': 2,
        'state': 'planning',
        'stage': 'planning',
        'updatedAt': '2026-10-25T02:00:00Z',
      };
      api.seq++;
      await repository.refreshSession('s1');
      await Future<void>.delayed(Duration.zero);
      final revised = controller.chatController.messages.last;
      expect(revised.metadata!['filmJobFingerprint'], isNot(fingerprint));
      expect((revised.metadata!['demo'] as DemoMessage).text, initialDemo.text);
      expect(
        (revised.metadata!['demo'] as DemoMessage).status,
        initialDemo.status,
      );
      api.job = {
        ...api.job!,
        'state': 'rendering',
        'stage': 'rendering',
        'updatedAt': '2026-10-25T03:00:00Z',
      };
      api.seq++;
      await repository.refreshSession('s1');
      await Future<void>.delayed(Duration.zero);
      final rendered = controller.chatController.messages.last;
      expect(
        (jsonDecode(rendered.metadata!['filmJobFingerprint'] as String)
            as Map)['state'],
        'rendering',
      );
      expect(
        operations.where(
          (operation) =>
              operation.type == chat.ChatOperationType.update &&
              operation.message?.id == 'm1',
        ),
        hasLength(2),
      );
      expect(
        operations.where(
          (operation) => operation.type == chat.ChatOperationType.set,
        ),
        isEmpty,
      );
    },
  );

  test(
    'an empty-text film reply replaces provisional activity while its run is still active',
    () async {
      await repository.refreshSessions();
      repository.dispose();
      repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 2,
      )..restore();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      api.snapshotMessages = _filmHttpMessages();
      api.job = {..._job(), 'state': 'planning', 'stage': 'planning'};
      api.runState = 'running';
      api.runFilmJobId = 'film-1';
      api.snapshotGate = Completer<void>();
      api.gatedSnapshotCall = api.snapshotCalls + 2;
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final sending = controller.send(
        'A story about a rainy station',
        [],
        l,
        skillInvocation: const DemoStyleFilmInvocation(selection: _selection),
      );
      for (
        var i = 0;
        i < 40 && api.snapshotCalls < api.gatedSnapshotCall!;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);
      expect(controller.running, isTrue);
      expect(
        controller.chatController.messages.any((message) => message.id == 'm1'),
        isTrue,
      );
      expect(
        controller.chatController.messages.where(
          (message) => message.id.startsWith('local-activity:'),
        ),
        isEmpty,
      );
      api.runState = 'completed';
      api.job = _job();
      api.snapshotGate!.complete();
      await sending;
      expect(
        controller.chatController.messages.where(
          (message) => message.id.startsWith('local-activity:'),
        ),
        isEmpty,
      );
    },
  );
}

// Mirrors the HTTP snapshot's empty assistant delivery row for a film job.
List<Map<String, Object?>> _filmHttpMessages() => [
  {
    'id': 'user-film-1',
    'role': 'user',
    'text': 'A story about a rainy station',
    'assetIds': <String>[],
  },
  {
    'id': 'm1',
    'role': 'assistant',
    'text': '',
    'status': 'completed',
    'memberId': 'popi',
    'memberName': 'Director',
    'runId': 'r1',
    'configRevision': 1,
    'filmJobId': 'film-1',
    'assetIds': <String>[],
  },
];

Map<String, Object?> _job({
  int revision = 1,
  String updatedAt = '2026-10-25T01:00:00Z',
}) => {
  'jobId': 'film-1',
  'sessionId': 's1',
  'runId': 'r1',
  'memberId': 'popi',
  'botId': 'bot:director',
  'memberName': 'Director',
  'configRevision': 1,
  'styleId': 'impasto',
  'styleNameZh': '油画厚涂',
  'styleNameEn': 'Impasto',
  'catalogVersion': 'fixed-test',
  'arguments': _selection.toArguments(),
  'title': 'New story',
  'revision': revision,
  'state': 'awaiting_storyboard',
  'stage': 'awaiting_storyboard',
  'createdAt': '2026-10-25T00:00:00Z',
  'updatedAt': updatedAt,
  'storyboard': [
    {
      'id': 'shot-1',
      'title': 'Opening',
      'description': 'A new story',
      'startSeconds': 0,
      'durationSeconds': 15,
      'previewAssetId': 'preview-1',
      'previewUrl': '/api_agent/v2/assets/preview-1/content',
    },
  ],
  'assetIds': <String>[],
  'allowedActions': ['approve', 'revise'],
};

class _FilmApi extends NetworkAgentApi {
  _FilmApi(super.dio);
  final configuration = <String, Object?>{
    'members': ['popi'],
    'roles': <String>[],
    'capabilities': DemoSession.defaultCapabilities,
    'memberCapabilities': {'popi': DemoSession.defaultCapabilities},
    'memberNames': {'popi': 'Director'},
    'memberBotIds': {'popi': 'bot:director'},
    'memberSkills': {
      'popi': [demoStyleFilmSkillId],
    },
    'workMode': 'manual',
    'activeMemberId': 'popi',
  };
  Map<String, Object?>? job;
  List<Map<String, Object?>>? snapshotMessages;
  int seq = 1;
  int snapshotCalls = 0;
  int stopCalls = 0;
  String runState = 'completed';
  String runFilmJobId = '';
  Completer<void>? snapshotGate;
  int? gatedSnapshotCall;
  VoidCallback? beforeSnapshot;
  int configRevision = 1;
  bool failSend = false, failReview = false, conflictReview = false;
  final sent = <Map<String, Object?>>[];
  final reviews = <Map<String, Object?>>[];
  Map<String, Object?>? catalogQuery, updatedConfiguration;
  int? expectedConfigRevision;
  Map<String, dynamic> get record => {
    'id': 's1',
    'title': 'Director',
    'kind': 'conversation',
    'configurationStatus': 'configured',
    'configuration': configuration,
    'configRevision': configRevision,
    'revision': seq,
  };

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? projectId,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [record],
    'pageInfo': {'pageCount': 1},
  };
  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};
  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    snapshotCalls++;
    beforeSnapshot?.call();
    if (snapshotGate != null &&
        (gatedSnapshotCall == null || snapshotCalls == gatedSnapshotCall)) {
      await snapshotGate!.future;
    }
    return {
      'session': record,
      'lastSeq': seq,
      'messages':
          snapshotMessages ??
          (job == null
              ? <Object?>[]
              : [
                  {
                    'id': 'm1',
                    'role': 'assistant',
                    'text': '',
                    'filmJobId': 'film-1',
                  },
                ]),
      'runs': [
        {
          'id': 'r1',
          'state': runState,
          if (runFilmJobId.isNotEmpty) 'filmJobId': runFilmJobId,
        },
      ],
      'mediaJobs': <Object?>[],
      'filmJobs': job == null ? <Object?>[] : [job],
      'assets': <Object?>[],
    };
  }

  @override
  Future<Map<String, dynamic>> updateSession(
    String id, {
    String? clientRequestId,
    String? title,
    bool? archived,
    bool? pinned,
    Map<String, Object?>? configuration,
    int? expectedConfigRevision,
    CancelToken? cancelToken,
  }) async {
    updatedConfiguration = configuration;
    this.expectedConfigRevision = expectedConfigRevision;
    if (configuration != null) {
      this.configuration
        ..clear()
        ..addAll(configuration);
      configRevision++;
    }
    return record;
  }

  @override
  Future<Map<String, dynamic>> styleFilmCatalog({
    String? q,
    String? category,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    catalogQuery = {
      'q': q,
      'category': category,
      'page': page,
      'pageSize': pageSize,
    };
    return {
      'skillId': demoStyleFilmSkillId,
      'catalogVersion': 'fixed-test',
      'upstreamCommit': 'fixed',
      'available': false,
      'reasonUnavailable': 'compatibility_not_verified',
      'supports': {
        'durations': [15, 30],
        'aspectRatios': ['9:16', '16:9', '1:1'],
        'soundtracks': ['none'],
      },
      'list': [
        {
          'id': 'ink-wash',
          'nameZh': '中国水墨',
          'nameEn': 'Ink wash',
          'posterUrl': '/api_agent/v2/style-films/styles/ink-wash/poster',
          'ready': false,
          'reasonUnavailable': 'compatibility_not_verified',
        },
      ],
      'pageInfo': {
        'page': page,
        'pageSize': pageSize,
        'total': 59,
        'pageCount': 8,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> sendSessionMessage(
    String id, {
    required String clientRequestId,
    required String text,
    String? taskId,
    List<String>? mediaIds,
    List<String>? contextRoleIds,
    Map<String, Object?>? skillInvocation,
    CancelToken? cancelToken,
  }) async {
    sent.add({
      'clientRequestId': clientRequestId,
      'text': text,
      if (skillInvocation != null) 'skillInvocation': skillInvocation,
    });
    if (failSend) {
      failSend = false;
      throw TimeoutException('Unknown acceptance');
    }
    return {
      'runId': 'r1',
      'state': 'queued',
      if (skillInvocation != null) 'jobId': 'film-1',
    };
  }

  @override
  Future<Map<String, dynamic>> stopSession(
    String id, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    stopCalls++;
    throw StateError('This transport must not stop a film planning run');
  }

  @override
  Future<Map<String, dynamic>> reviewStyleFilm(
    String sessionId,
    String jobId, {
    required String clientRequestId,
    required int expectedRevision,
    required String action,
    String? notes,
    CancelToken? cancelToken,
  }) async {
    reviews.add({
      'clientRequestId': clientRequestId,
      'expectedRevision': expectedRevision,
      'action': action,
      if (notes != null) 'notes': notes,
    });
    if (failReview) {
      failReview = false;
      throw TimeoutException('Unknown review');
    }
    job = _job(revision: 2, updatedAt: '2026-10-25T02:00:00Z');
    seq++;
    if (conflictReview) {
      throw const AgentApiException(
        code: 'film_revision_conflict',
        message: 'Changed',
        statusCode: 409,
      );
    }
    return {
      'jobId': jobId,
      'revision': 2,
      'state': 'awaiting_storyboard',
      'stage': 'awaiting_storyboard',
    };
  }
}
