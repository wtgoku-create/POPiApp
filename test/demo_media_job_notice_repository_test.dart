import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _completedJob = DemoMediaJob(
  jobId: 'job-completed',
  state: 'completed',
  operation: 'image',
  model: 'image-2.5-official',
  runId: 'run-1',
  assetIds: ['milk'],
  ingestionState: 'completed',
);

const _secondCompletedJob = DemoMediaJob(
  jobId: 'job-new',
  state: 'failed',
  operation: 'image',
  model: 'image-2.5-official',
  runId: 'run-2',
);

const _pendingJob = DemoMediaJob(
  jobId: 'job-pending',
  state: 'running',
  operation: 'image',
  model: 'image-2.5-official',
  runId: 'run-3',
);

class _Storage extends PreferencesStorage {
  _Storage(super.preferences);

  final values = <String, String>{};
  var writes = 0;
  var removals = 0;
  var failDismissalWrites = false;

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failDismissalWrites && key.endsWith('_dismissed_media_jobs_v1')) {
      throw StateError('Disk unavailable');
    }
    writes += 1;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    removals += 1;
    values.remove(key);
  }
}

Future<DemoRepository> _repositoryWithJobs(_Storage storage) async {
  final repository = DemoRepository(storage)..restore();
  await repository.updateSession(
    'alice',
    (session) => session.copyWith(
      mediaJobs: const [_completedJob, _secondCompletedJob, _pendingJob],
    ),
  );
  await repository.updateSession(
    'bob',
    (session) => session.copyWith(mediaJobs: const [_completedJob]),
  );
  return repository;
}

void main() {
  late _Storage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage(await SharedPreferences.getInstance());
  });

  test(
    'terminal notice dismissal persists without changing jobs or assets',
    () async {
      final repository = await _repositoryWithJobs(storage);
      addTearDown(repository.dispose);
      final assetIds = repository.assets.map((asset) => asset.id).toList();
      final jobs = repository.session('alice').mediaJobs;

      expect(
        repository.isMediaJobNoticeDismissed('alice', 'job-completed'),
        isFalse,
      );
      await repository.dismissMediaJobNotice('alice', 'job-completed');

      expect(
        repository.isMediaJobNoticeDismissed('alice', 'job-completed'),
        isTrue,
      );
      expect(repository.session('alice').mediaJobs, same(jobs));
      expect(repository.assets.map((asset) => asset.id), assetIds);

      final restored = DemoRepository(storage)..restore();
      addTearDown(restored.dispose);
      expect(
        restored.isMediaJobNoticeDismissed('alice', 'job-completed'),
        isTrue,
      );

      await restored.updateSession(
        'alice',
        (session) => session.copyWith(
          mediaJobs: const [_completedJob, _secondCompletedJob],
        ),
      );
      expect(
        restored.isMediaJobNoticeDismissed('alice', 'job-completed'),
        isTrue,
      );
      expect(restored.isMediaJobNoticeDismissed('alice', 'job-new'), isFalse);
    },
  );

  test('dismissal is idempotent and isolated by session', () async {
    final repository = await _repositoryWithJobs(storage);
    addTearDown(repository.dispose);

    await repository.dismissMediaJobNotice('alice', 'job-completed');
    final writesAfterFirstDismissal = storage.writes;
    await repository.dismissMediaJobNotice('alice', 'job-completed');

    expect(storage.writes, writesAfterFirstDismissal);
    expect(
      repository.isMediaJobNoticeDismissed('alice', 'job-completed'),
      isTrue,
    );
    expect(
      repository.isMediaJobNoticeDismissed('bob', 'job-completed'),
      isFalse,
    );
  });

  test('pending and unknown jobs cannot be dismissed', () async {
    final repository = await _repositoryWithJobs(storage);
    addTearDown(repository.dispose);
    final writesBefore = storage.writes;

    await repository.dismissMediaJobNotice('alice', 'job-pending');
    await repository.dismissMediaJobNotice('alice', 'job-unknown');

    expect(storage.writes, writesBefore);
    expect(
      repository.isMediaJobNoticeDismissed('alice', 'job-pending'),
      isFalse,
    );
  });

  test(
    'failed persistence keeps the notice visible and can be retried',
    () async {
      final repository = await _repositoryWithJobs(storage);
      addTearDown(repository.dispose);
      storage.failDismissalWrites = true;

      await expectLater(
        repository.dismissMediaJobNotice('alice', 'job-completed'),
        throwsStateError,
      );
      expect(
        repository.isMediaJobNoticeDismissed('alice', 'job-completed'),
        isFalse,
      );

      storage.failDismissalWrites = false;
      await repository.dismissMediaJobNotice('alice', 'job-completed');
      expect(
        repository.isMediaJobNoticeDismissed('alice', 'job-completed'),
        isTrue,
      );
    },
  );

  test('reset clears persisted dismissal metadata', () async {
    final repository = await _repositoryWithJobs(storage);
    addTearDown(repository.dispose);
    await repository.dismissMediaJobNotice('alice', 'job-completed');

    await repository.reset();
    expect(storage.removals, 1);

    await repository.updateSession(
      'alice',
      (session) => session.copyWith(mediaJobs: const [_completedJob]),
    );
    expect(
      repository.isMediaJobNoticeDismissed('alice', 'job-completed'),
      isFalse,
    );
  });

  test('offline and Harness dismissal stores are isolated', () async {
    final offline = await _repositoryWithJobs(storage);
    addTearDown(offline.dispose);
    await offline.dismissMediaJobNotice('alice', 'job-completed');

    final harnessSnapshot = Map<String, Object?>.from(
      jsonDecode(storage.values[DemoRepository.storageKey]!) as Map,
    )..['assets'] = <Object?>[];
    storage.values[DemoRepository.harnessStorageKey] = jsonEncode(
      harnessSnapshot,
    );
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final harness = DemoRepository.harness(storage, NetworkAgentApi(dio))
      ..restore();
    addTearDown(harness.dispose);

    expect(
      harness.isMediaJobNoticeDismissed('alice', 'job-completed'),
      isFalse,
    );
    expect(
      harness.session('alice').mediaJobs.map((job) => job.jobId),
      contains('job-new'),
    );
    await harness.dismissMediaJobNotice('alice', 'job-new');
    expect(
      storage
          .values['${DemoRepository.harnessStorageKey}_dismissed_media_jobs_v1'],
      isNotNull,
    );
    expect(harness.isMediaJobNoticeDismissed('alice', 'job-new'), isTrue);
    expect(offline.isMediaJobNoticeDismissed('alice', 'job-new'), isFalse);
    expect(offline.isMediaJobNoticeDismissed('alice', 'job-completed'), isTrue);
  });

  test('missing or corrupt dismissal metadata restores safely', () async {
    final repository = await _repositoryWithJobs(storage);
    addTearDown(repository.dispose);
    expect(
      repository.isMediaJobNoticeDismissed('alice', 'job-completed'),
      isFalse,
    );

    storage.values['${DemoRepository.storageKey}_dismissed_media_jobs_v1'] =
        '{broken';
    final restored = DemoRepository(storage)..restore();
    addTearDown(restored.dispose);
    expect(
      restored.isMediaJobNoticeDismissed('alice', 'job-completed'),
      isFalse,
    );
  });

  test(
    'older dismissals remain hidden as newer notices are dismissed',
    () async {
      final repository = await _repositoryWithJobs(storage);
      addTearDown(repository.dispose);
      await repository.dismissMediaJobNotice('alice', 'job-completed');
      await repository.dismissMediaJobNotice('alice', 'job-new');

      final restored = DemoRepository(storage)..restore();
      addTearDown(restored.dispose);
      expect(
        restored.isMediaJobNoticeDismissed('alice', 'job-completed'),
        isTrue,
      );
      expect(restored.isMediaJobNoticeDismissed('alice', 'job-new'), isTrue);
    },
  );
}
