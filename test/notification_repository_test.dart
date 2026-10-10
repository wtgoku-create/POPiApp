import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/notifications/data/notification_repository.dart';
import 'package:popi_ai_app/shared/type/notification_type.dart';

void main() {
  late Dio dio;
  late NotificationRepository repository;
  late List<RequestOptions> requests;
  late Map<String, Object?> data;
  String status = '0000';

  setUp(() {
    requests = [];
    status = '0000';
    data = {
      'pageInfo': {'page': 1, 'pageCount': 2},
      'list': [
        {
          'id': '41',
          'title': ' Title ',
          'content': ' Full message ',
          'readStatus': '0',
          'sendTime': '2026-10-01T10:30:00+08:00',
        },
      ],
    };
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data:
                  jsonDecode(
                        jsonEncode({
                          'status': status,
                          'message': 'Unavailable',
                          'data': options.path.endsWith('/read')
                              ? <String, Object?>{}
                              : data,
                        }),
                      )
                      as Map<String, dynamic>,
            ),
          );
        },
      ),
    );
    repository = NotificationRepository(NetworkApi(dio));
  });
  tearDown(() => dio.close());

  test('uses web list and read contracts with numeric delivery ids', () async {
    final result = await repository.fetchNotifications(
      NotificationType.personal,
      page: 1,
    );
    expect(requests.single.method, 'GET');
    expect(requests.single.path, '/api_client/content/notification/list');
    expect(requests.single.queryParameters, {
      'messageType': 'personal',
      'page': 1,
      'pageSize': 20,
    });
    final item = result.items.single;
    expect(item.id, 41);
    expect(item.title, 'Title');
    expect(item.content, 'Full message');
    expect(item.isUnread, isTrue);
    expect(item.sentAt, DateTime.parse('2026-10-01T10:30:00+08:00'));
    expect(result.hasMore, isTrue);
    await repository.markRead(item.id);
    expect(requests.last.path, '/api_client/content/notification/read');
    expect(requests.last.method, 'POST');
    expect(requests.last.data, {'id': 41});
    expect(() => repository.markRead(0), throwsArgumentError);
  });

  test('stops at the last or empty page and honors total pagination', () async {
    expect(
      (await repository.fetchNotifications(
        NotificationType.system,
        page: 2,
      )).hasMore,
      isFalse,
    );
    data['list'] = [];
    expect(
      (await repository.fetchNotifications(
        NotificationType.system,
        page: 1,
      )).hasMore,
      isFalse,
    );
    data = {
      'pageInfo': {'total': 3},
      'list': [
        {'id': 1},
        {'id': 2},
      ],
    };
    expect(
      (await repository.fetchNotifications(
        NotificationType.system,
        page: 1,
        pageSize: 2,
      )).hasMore,
      isTrue,
    );
    expect(
      (await repository.fetchNotifications(
        NotificationType.system,
        page: 2,
        pageSize: 2,
      )).hasMore,
      isFalse,
    );
  });

  test(
    'excludes deleted, expired and invalid deliveries without reordering',
    () async {
      data['list'] = [
        {'id': 1, 'readStatus': 1, 'createTime': '2026-09-01T00:00:00Z'},
        {'id': 2, 'deleted': true},
        {'id': 3, 'userDeleted': true},
        {'id': 4, 'expireTime': '2000-01-01T00:00:00Z'},
        {'id': 0},
        {'id': 5, 'sendTime': 'invalid', 'createTime': '2026-09-01T00:00:00Z'},
      ];
      final items = (await repository.fetchNotifications(
        NotificationType.system,
        page: 1,
      )).items;
      expect(items.map((item) => item.id), [1, 5]);
      expect(items.first.isUnread, isFalse);
      expect(items.last.sentAt, DateTime.utc(2026, 9));
    },
  );

  test(
    'maps membership to an app page and keeps web-only links usable',
    () async {
      data['list'] = [
        {'id': 1, 'linkType': 'page', 'linkValue': '/subscribe?plan=monthly'},
        {'id': 2, 'linkType': 'page', 'linkValue': '#/teaching'},
        {'id': 3, 'linkType': 'page', 'linkValue': '/explore'},
        {'id': 4, 'linkType': 'url', 'linkValue': 'www.example.com/news'},
      ];
      final items = (await repository.fetchNotifications(
        NotificationType.system,
        page: 1,
      )).items;
      expect(items[0].target!.location, '/profile/membership?plan=monthly');
      expect(items[1].target!.location, '/teaching');
      expect(items[2].target!.url.toString(), 'https://example.test/explore');
      expect(items[3].target!.url.toString(), 'https://www.example.com/news');
    },
  );

  test('rejects unsupported schemes and unknown link types', () async {
    data['list'] = [
      {'id': 1, 'linkType': 'url', 'linkValue': 'javascript:alert(1)'},
      {'id': 2, 'linkType': 'page', 'linkValue': 'data:text/html,hello'},
      {'id': 3, 'linkType': 'none', 'linkValue': 'https://example.com'},
      {
        'id': 4,
        'imageUrls': ['file:///private/image.png'],
      },
    ];
    final items = (await repository.fetchNotifications(
      NotificationType.system,
      page: 1,
    )).items;
    expect(
      items.every((item) => item.target == null && item.imageUrl == null),
      isTrue,
    );
  });

  test(
    'resolves image URLs and removes duplicate image links from content',
    () async {
      data['list'] = [
        {
          'id': 1,
          'imageUrls': ['/media/result.png'],
          'content': 'Ready https://cdn.example.com/result.png',
        },
        {'id': 2, 'linkValue': 'https://cdn.example.com/result.jpg?token=1'},
        {'id': 3, 'content': 'See https://example.com/news'},
      ];
      final items = (await repository.fetchNotifications(
        NotificationType.system,
        page: 1,
      )).items;
      expect(items.first.imageUrl, 'https://example.test/media/result.png');
      expect(items.first.content, 'Ready');
      expect(items[1].imageUrl, 'https://cdn.example.com/result.jpg?token=1');
      expect(items.last.content, 'See https://example.com/news');
      expect(items.last.imageUrl, isNull);
    },
  );

  test('propagates business and malformed list failures', () async {
    status = '4000';
    await expectLater(repository.markRead(41), throwsA(isA<ApiException>()));
    await expectLater(
      repository.fetchNotifications(NotificationType.system, page: 1),
      throwsA(isA<ApiException>()),
    );
    status = '0000';
    data['list'] = 'invalid';
    await expectLater(
      repository.fetchNotifications(NotificationType.system, page: 1),
      throwsA(isA<ApiException>()),
    );
  });
}
