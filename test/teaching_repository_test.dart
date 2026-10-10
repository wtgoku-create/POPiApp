import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/teaching/data/teaching_repository.dart';

void main() {
  TeachingRepository repository(
    Object? Function(RequestOptions request) respond,
  ) {
    final dio = Dio(BaseOptions(baseUrl: 'https://popi.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response(requestOptions: request, data: respond(request)),
        ),
      ),
    );
    return TeachingRepository(NetworkApi(dio));
  }

  test('uses published categories and the same Web sort order', () async {
    final repo = repository((request) {
      expect(request.method, 'GET');
      expect(request.path, '/api_client/content/courseCategory/list');
      return {
        'status': '0000',
        'data': [
          {'id': 2, 'code': 'second', 'name': ' 二 ', 'status': 1, 'sort': 20},
          {'id': 1, 'code': 'first', 'name': '一', 'status': 1, 'sort': 10},
          {'id': 3, 'code': '', 'name': '缺少code', 'status': 1},
          {'id': 4, 'code': 'off', 'name': '禁用', 'status': 0},
          {
            'id': 5,
            'code': 'deleted',
            'name': '删除',
            'status': 1,
            'deleted': true,
          },
        ],
      };
    });
    final categories = await repo.fetchCategories();
    expect(categories.map((item) => item.id), [1, 2]);
    expect(categories.last.name, '二');
  });

  test(
    'sends filters and parses course metadata and server pagination',
    () async {
      final repo = repository((request) {
        expect(request.path, '/api_client/content/course/list');
        expect(request.queryParameters, {
          'page': 2,
          'pageSize': 20,
          'categoryId': 3,
          'keyword': 'AI',
        });
        return {
          'status': '0000',
          'data': {
            'pageInfo': {'page': 2, 'pageCount': 4},
            'list': [
              {
                'id': 10,
                'name': ' AI创作 ',
                'desp': ' 课程简介 ',
                'cover': '/media/cover.png',
                'memberLevels': [3, '1', 3, 'bad'],
                'tags': ['', ' 新手 ', '第二个'],
                'userInfo': {'name': ' Alice ', 'avatar': '/media/avatar.png'},
              },
              {'id': 9, 'name': '已删除', 'deleted': true},
              {'id': 8, 'name': '未发布', 'status': 0},
            ],
          },
        };
      });
      final result = await repo.fetchCourses(
        page: 2,
        categoryId: 3,
        keyword: ' AI ',
      );
      expect(result.hasMore, isTrue);
      final course = result.items.single;
      expect(course.name, 'AI创作');
      expect(course.description, '课程简介');
      expect(course.coverUrl, 'https://popi.test/media/cover.png');
      expect(course.instructorName, 'Alice');
      expect(course.instructorAvatarUrl, 'https://popi.test/media/avatar.png');
      expect(course.memberLevels, [1, 3]);
      expect(course.lowestKnownMemberLevel({3: 'Max'}), 3);
      expect(course.lowestKnownMemberLevel({2: 'Plus'}), isNull);
      expect(course.tag, '新手');
    },
  );

  test(
    'all omits filter parameters and fallback uses the unfiltered page size',
    () async {
      final repo = repository((request) {
        expect(request.queryParameters, {'page': 1, 'pageSize': 2});
        return {
          'status': '0000',
          'data': {
            'list': [
              {'id': 1, 'name': '有效', 'cover': 'javascript:alert(1)'},
              {'id': 2, 'name': '未发布', 'status': 0},
            ],
          },
        };
      });
      final result = await repo.fetchCourses(page: 1, pageSize: 2);
      expect(result.hasMore, isTrue);
      expect(result.items.single.coverUrl, isEmpty);
    },
  );

  test(
    'loads the first server document and only exposes reader fields',
    () async {
      final paths = <String>[];
      final repo = repository((request) {
        paths.add(request.path);
        if (request.path.endsWith('/list')) {
          expect(request.queryParameters, {'courseId': 5});
          return {
            'status': '0000',
            'data': {
              'list': [
                {'id': 20, 'sort': 99},
                {'id': 10, 'sort': 1},
              ],
            },
          };
        }
        expect(request.queryParameters, {'id': 20});
        return {
          'status': '0000',
          'data': {
            'id': 20,
            'title': ' 文章 ',
            'contentJson': '{"type":"blocknote","blocks":[]}',
            'contentHtml': '<h1>正文</h1>',
            'memberLevels': [3, '2', 2],
            'canViewPaidContent': false,
            'createTime': '2026-10-10',
            'tags': [' 标签 ', '', 1],
            'userInfo': {
              'name': ' 讲师 ',
              'avatar': '/media/avatar.png',
              'phone': 'private',
            },
            'token': 'private',
          },
        };
      });
      final document = (await repo.fetchCourseDocument(5))!;
      expect(paths, [
        '/api_client/content/document/list',
        '/api_client/content/document/detail',
      ]);
      expect(document.id, 20);
      expect(document.title, '文章');
      expect(document.memberLevels, [2, 3]);
      expect(document.publishTime, '2026-10-10');
      expect(document.canViewPaidContent, isFalse);
      expect(document.tags, ['标签']);
      expect(
        document.instructorAvatarUrl,
        'https://popi.test/media/avatar.png',
      );
      final data = document.toReaderData();
      expect(data.containsKey('token'), isFalse);
      expect((data['userInfo'] as Map).containsKey('phone'), isFalse);
    },
  );

  test(
    'handles empty and malformed document lists and legacy content',
    () async {
      final empty = repository(
        (_) => {
          'status': '0000',
          'data': {'list': []},
        },
      );
      expect(await empty.fetchCourseDocument(1), isNull);
      for (final list in [
        'bad',
        [null],
        [
          {'id': 'bad'},
        ],
      ]) {
        final malformed = repository(
          (_) => {
            'status': '0000',
            'data': {'list': list},
          },
        );
        await expectLater(
          malformed.fetchCourseDocument(1),
          throwsA(isA<ApiException>()),
        );
      }
      final legacy = repository(
        (request) => {
          'status': '0000',
          'data': request.path.endsWith('/list')
              ? {
                  'list': [
                    {'id': 9},
                  ],
                }
              : {
                  'id': 9,
                  'name': '旧文章',
                  'content': '<p>旧正文</p>',
                  'canViewPaidContent': 'true',
                },
        },
      );
      final document = (await legacy.fetchCourseDocument(1))!;
      expect(document.title, '旧文章');
      expect(document.contentHtml, '<p>旧正文</p>');
      expect(document.canViewPaidContent, isFalse);
    },
  );

  test('rejects failed envelopes and malformed course lists', () async {
    final rejected = repository((_) => {'status': '9999', 'message': '失败'});
    await expectLater(rejected.fetchCategories(), throwsA(isA<ApiException>()));
    final malformed = repository(
      (_) => {
        'status': '0000',
        'data': {'list': 'bad'},
      },
    );
    await expectLater(
      malformed.fetchCourses(page: 1),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'highlights use configured member labels, QR and the lowest monthly price',
    () async {
      final paths = <String>[];
      final repo = repository((request) {
        paths.add(request.path);
        return {
          'status': '0000',
          'data': switch (request.path) {
            '/api_client/users/member/list' => {
              'list': [
                {'memberLevel': 1, 'memberName': ' Starter ', 'status': 1},
                {'memberLevel': 2, 'memberName': 'Hidden', 'status': 0},
                {
                  'memberLevel': 3,
                  'memberName': 'Deleted',
                  'status': 1,
                  'deleted': true,
                },
              ],
            },
            '/api_client/param/config' => {
              'systemConfig': {'popiSocialGroup': '/media/community.png'},
            },
            '/api_client/products/plan/list' => {
              'list': [
                {'id': 1, 'price': 100, 'planCategory': 'yearly', 'status': 1},
                {'id': 2, 'price': 990, 'planCategory': 'monthly', 'status': 1},
                {
                  'id': 3,
                  'price': 20900,
                  'planCategory': 'monthly',
                  'status': 1,
                },
                {
                  'id': 4,
                  'price': 10,
                  'planCategory': 'monthly',
                  'status': 1,
                  'deleted': true,
                },
              ],
            },
            _ => throw StateError(request.path),
          },
        };
      });
      final highlights = await repo.fetchHighlights();
      expect(paths.toSet().length, 3);
      expect(highlights.memberLabels, {1: 'Starter'});
      expect(
        highlights.communityQrUrl,
        'https://popi.test/media/community.png',
      );
      expect(highlights.startingPrice, '9.9');
    },
  );

  test('optional metadata failures do not discard the available QR', () async {
    final repo = repository(
      (request) => request.path.endsWith('/param/config')
          ? {
              'status': '0000',
              'data': {
                'systemConfig': {'popiSocialGroup': 'https://cdn.test/qr.png'},
              },
            }
          : {'status': '9999', 'message': 'Unavailable'},
    );
    final highlights = await repo.fetchHighlights();
    expect(highlights.communityQrUrl, 'https://cdn.test/qr.png');
    expect(highlights.memberLabels, isEmpty);
    expect(highlights.startingPrice, isNull);
  });
}
