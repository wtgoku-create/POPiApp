import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/shared/controllers/paged_list_controller.dart';
import 'package:popi_ai_app/shared/type/list_page.dart';

void main() {
  late PagedListController<String> controller;
  late Future<ListPage<String>> Function(int, CancelToken) fetch;
  late List<int> requests;

  setUp(() {
    requests = [];
    fetch = (page, _) async =>
        ListPage(items: ['row-$page'], page: page, pageCount: 2);
    controller = PagedListController(
      itemId: (item) => item,
      fetch: (page, token) {
        requests.add(page);
        return fetch(page, token);
      },
    );
  });
  tearDown(() {
    if (!controller.disposed) controller.dispose();
  });

  test('fetches one page at a time and stops after the last page', () async {
    expect(controller.items, isEmpty);
    await controller.load();
    expect(requests, [1]);
    expect(controller.items, ['row-1']);
    await controller.load();
    await controller.load();
    expect(requests, [1, 2]);
    expect(controller.items, ['row-1', 'row-2']);
    expect(controller.hasMore, isFalse);
  });

  test(
    'duplicate scrolls share a pending page and overlapping IDs merge',
    () async {
      await controller.load();
      final pending = Completer<ListPage<String>>();
      fetch = (_, _) => pending.future;
      final loading = controller.load();
      await controller.load();
      expect(requests, [1, 2]);
      expect(controller.items, ['row-1']);
      pending.complete(
        const ListPage(items: ['row-1', 'row-2'], page: 2, pageCount: 2),
      );
      await loading;
      expect(controller.items, ['row-1', 'row-2']);
    },
  );

  test('failed next page preserves rows and retries the same page', () async {
    await controller.load();
    fetch = (_, _) async => throw StateError('offline');
    await expectLater(controller.load(), throwsStateError);
    expect(controller.items, ['row-1']);
    expect(controller.page, 1);
    expect(controller.hasMore, isTrue);
    expect(controller.loading, isFalse);
    fetch = (page, _) async =>
        ListPage(items: ['row-2'], page: page, pageCount: 2);
    await controller.load();
    expect(requests, [1, 2, 2]);
    expect(controller.items, ['row-1', 'row-2']);
  });

  test('empty filtered pages retain the server continuation', () async {
    fetch = (page, _) async =>
        ListPage(items: page == 1 ? [] : ['usable'], page: page, pageCount: 2);
    await controller.load();
    expect(controller.items, isEmpty);
    expect(controller.hasMore, isTrue);
    await controller.load();
    expect(controller.items, ['usable']);
    expect(requests, [1, 2]);
  });

  test(
    'refresh cancels pending pagination and discards its late result',
    () async {
      await controller.load();
      final pending = Completer<ListPage<String>>();
      late CancelToken oldToken;
      fetch = (_, token) {
        oldToken = token;
        return pending.future;
      };
      final more = controller.load();
      fetch = (page, _) async =>
          ListPage(items: ['fresh'], page: page, pageCount: 1);
      await controller.load(reset: true);
      expect(oldToken.isCancelled, isTrue);
      pending.complete(const ListPage(items: ['stale'], page: 2, pageCount: 2));
      await more;
      expect(controller.items, ['fresh']);
      expect(requests, [1, 2, 1]);
    },
  );

  test('disposal cancels requests and suppresses obsolete errors', () async {
    final pending = Completer<ListPage<String>>();
    late CancelToken token;
    fetch = (_, value) {
      token = value;
      return pending.future;
    };
    final load = controller.load();
    controller.dispose();
    expect(token.isCancelled, isTrue);
    pending.completeError(StateError('offline'));
    await load;
    expect(controller.items, isEmpty);
  });

  test(
    'deletion reconciles offset pagination without removing other rows',
    () async {
      await controller.load();
      controller.remove('row-1');
      expect(controller.items, isEmpty);
      expect(controller.page, 0);
      await controller.load();
      expect(requests, [1, 1]);
    },
  );
}
