import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'cast selector uses Web PUT contract, allows clear and reuses uncertain command',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PreferencesStorage(await SharedPreferences.getInstance());
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final repository = ApiSessionRepository(
        NetworkAgentApi(dio),
        NetworkApi(dio),
        () => storage,
      );
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (requests.length == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'cast': [], 'runId': 'run'},
                ),
              );
            }
          },
        ),
      );
      await expectLater(
        repository.updateCast('a', 'session', ['2', '1']),
        throwsA(isA<DioException>()),
      );
      await repository.updateCast('a', 'session', ['2', '1']);
      expect(requests[0].data, requests[1].data);
      expect(requests[1].method, 'PUT');
      expect(requests[1].path, '/api_agent/v2/sessions/session/cast');
      expect(requests[1].data, {
        'clientRequestId': isA<String>(),
        'roleIds': [2, 1],
      });
      expect(requests[1].data.containsKey('reply'), isFalse);
      await repository.updateCast('a', 'session', []);
      expect(requests.last.data['roleIds'], isEmpty);
      expect(
        requests.last.data['clientRequestId'],
        isNot(requests[1].data['clientRequestId']),
      );
      for (final roles in [
        ['0'],
        ['x'],
        ['1', '1'],
        ['1', '2', '3', '4', '5', '6'],
      ]) {
        await expectLater(
          repository.updateCast('a', 'session', roles),
          throwsArgumentError,
        );
      }
      expect(requests, hasLength(3));
    },
  );
}
