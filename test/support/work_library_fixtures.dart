import 'package:dio/dio.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

class LibraryTestUserController extends UserController {
  @override
  User? build() => const User(id: '1', name: 'User', email: '');

  @override
  Future<void> clearUser() async => state = null;
}

/// Adds completed image/video task responses alongside other API fixtures.
Dio withWorkLibrary(Dio dio) {
  dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path != '/api_client/anime/task/list') {
          handler.next(request);
          return;
        }
        final type = request.queryParameters['type'];
        handler.resolve(
          Response(
            requestOptions: request,
            data: {
              'status': '0000',
              'data': {
                'list': [
                  for (var i = 1; i <= 9; i++)
                    if (type == null || type == (i % 3 == 0 ? 2 : 1))
                      {
                        'status': 2,
                        'type': i % 3 == 0 ? 2 : 1,
                        'createTime': i <= 6
                            ? '2026-09-01T10:00:00'
                            : '2026-08-31T10:00:00',
                        'resultList': [
                          {
                            'id': '$i',
                            'images': [
                              'assets/images/assets_works_gallery_${i.toString().padLeft(2, '0')}.png',
                            ],
                            if (i % 3 == 0)
                              'video': 'https://example.test/$i.mp4',
                          },
                        ],
                      },
                ],
                'pageInfo': {'pageCount': 1},
              },
            },
          ),
        );
      },
    ),
  );
  return dio;
}
