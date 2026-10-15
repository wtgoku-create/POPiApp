import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_repository.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account_home.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';

void main() {
  late Dio dio;
  late List<RequestOptions> requests;
  late List<Map<String, dynamic>> Function(RequestOptions) rows;
  setUp(() {
    requests = [];
    rows = (_) => [];
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'status': '0000',
                  'data': {
                    'list': rows(request),
                    'pageInfo': {
                      'page': request.queryParameters['page'],
                      'pageSize': request.queryParameters['pageSize'],
                      'pageCount': 2,
                      'total': 40,
                    },
                  },
                },
              ),
            );
          },
        ),
      );
  });
  tearDown(() => dio.close(force: true));

  test(
    'resident role filtering does not discard the server next page',
    () async {
      rows = (request) => [
        {
          'id': request.queryParameters['page'],
          'title': 'Role',
          'canUseText': request.queryParameters['page'] == 2,
        },
      ];
      final repository = IpAccountRepository(NetworkApi(dio));
      final first = await repository.availableRoles('user');
      expect(first.items, isEmpty);
      expect(first.hasMore, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters, {
        'category': 'user',
        'page': 1,
        'pageSize': 20,
      });
      final second = await repository.availableRoles('user', page: 2);
      expect(second.items.single.id, '2');
      expect(second.hasMore, isFalse);
      expect(requests.map((request) => request.queryParameters['page']), [
        1,
        2,
      ]);
    },
  );

  test(
    'style templates fetch one page of twenty and expose continuation',
    () async {
      rows = (request) => [
        {'id': 'style-${request.queryParameters['page']}', 'title': 'Style'},
      ];
      final repository = ApiSessionRepository(
        NetworkAgentApi(dio),
        NetworkApi(dio),
        () => throw StateError('Storage is not needed to list styles'),
      );
      final first = await repository.roleTemplates();
      expect(first.items.single.id, 'style-1');
      expect(first.hasMore, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['pageSize'], 20);
      final second = await repository.roleTemplates(page: 2);
      expect(second.items.single.id, 'style-2');
      expect(second.hasMore, isFalse);
      expect(requests, hasLength(2));
    },
  );

  test(
    'unused resource helper returns only the requested archive page',
    () async {
      rows = (_) => [
        {'id': 'creation', 'title': 'Archive', 'status': 'draft'},
      ];
      final repository = IpAccountRepository(NetworkApi(dio));
      const account = IpAccountHome(id: '42', title: 'Account', revision: 1);
      final first = await repository.resources(account);
      expect(first.creations.single.id, 'creation');
      expect(first.hasMore, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['pageSize'], 20);
      final second = await repository.resources(account, page: 2);
      expect(second.page, 2);
      expect(second.hasMore, isFalse);
      expect(requests, hasLength(2));
    },
  );
}
