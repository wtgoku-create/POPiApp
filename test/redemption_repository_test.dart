import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/redemption/data/redemption_repository.dart';
import 'package:popi_ai_app/features/redemption/domain/redemption.dart';

void main() {
  late Dio dio;
  late RedemptionRepository repository;
  late List<RequestOptions> requests;
  late Map<String, Object?> payloads;
  String status = '0000';

  setUp(() {
    requests = [];
    payloads = {};
    status = '0000';
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: jsonDecode(
                jsonEncode({
                  'status': status,
                  'message': 'Invalid code',
                  'data': payloads[options.path] ?? <String, Object?>{},
                }),
              ),
            ),
          );
        },
      ),
    );
    repository = RedemptionRepository(NetworkApi(dio));
  });
  tearDown(() => dio.close());

  test(
    'uses the web endpoint contracts and parses invitation pagination',
    () async {
      payloads['/api_client/users/inviteCode/list'] = {
        'pageInfo': {'page': '1', 'pageSize': '20', 'pageCount': '2'},
        'list': [
          {'code': 'A123', 'usedCount': '0'},
          {'code': 'B123', 'usedCount': 1},
        ],
      };
      payloads['/api_client/users/inviteCodeLog/list'] = {
        'pageInfo': {'page': 2, 'pageSize': 20, 'total': 21},
        'list': [
          {
            'inviteeUserName': 'Friend',
            'createTime': '2026-09-02T09:46:00+08:00',
          },
        ],
      };
      final codes = await repository.fetchCodes(1);
      final records = await repository.fetchRecords(2);
      expect(requests[0].method, 'GET');
      expect(requests[0].queryParameters, {'page': 1, 'pageSize': 20});
      expect(requests[1].queryParameters, {'page': 2, 'pageSize': 20});
      expect(codes.hasMore, isTrue);
      expect(codes.items.first.isUsed, isFalse);
      expect(codes.items.last.isUsed, isTrue);
      expect(records.hasMore, isFalse);
      expect(records.items.single.name, 'Friend');
      expect(
        records.items.single.createdAt,
        DateTime.parse('2026-09-02T09:46:00+08:00'),
      );
    },
  );

  test(
    'loads configurable reward points and restores a claimed code',
    () async {
      payloads['/api_client/products/ruleConfig/detailByCode'] = {
        'points': '125',
      };
      payloads['/api_client/users/inviteCode/isUsed'] = {
        'id': 10,
        'code': 'USED',
      };
      final reward = await repository.fetchRegistrationReward();
      expect(requests.first.queryParameters, {'code': 'invited_friend'});
      expect(reward.points, 125);
      expect(reward.claimed, isTrue);
      expect(reward.code, 'USED');
      payloads['/api_client/users/inviteCode/isUsed'] = {};
      expect((await repository.fetchRegistrationReward()).claimed, isFalse);
    },
  );

  test('trims registration claim payloads and rejects empty codes', () async {
    await repository.claimRegistrationReward('  FRIEND  ');
    expect(requests.last.path, '/api_client/users/inviteCode/useInviteCode');
    expect(requests.last.method, 'POST');
    expect(requests.last.data, {'inviteCode': 'FRIEND'});
    expect(() => repository.claimRegistrationReward('  '), throwsArgumentError);
    expect(() => repository.claimRegistrationReward(''), throwsArgumentError);
    expect(requests, hasLength(1));
  });

  test(
    'propagates business failures and marks closed reward rules unavailable',
    () async {
      status = '4000';
      await expectLater(
        repository.claimRegistrationReward('BAD'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Invalid code',
          ),
        ),
      );
      await expectLater(
        repository.fetchRegistrationReward(),
        throwsA(isA<RegistrationRewardUnavailable>()),
      );
      status = '0000';
      payloads['/api_client/products/ruleConfig/detailByCode'] = {
        'points': 100,
      };
      payloads['/api_client/users/inviteCode/isUsed'] = 'malformed';
      await expectLater(
        repository.fetchRegistrationReward(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('checks official-account binding and exchanges the QR scene', () async {
    payloads['/api_client/users/user/wxghBindStatus'] = {'bound': false};
    expect(await repository.isWechatBound(), isFalse);
    payloads['/api_client/users/user/wxghBindQrCode'] = {
      'sceneCode': 'scene',
      'qrCodeUrl': 'https://example.com/qr.png',
      'expireSeconds': 180,
    };
    final before = DateTime.now();
    final qr = await repository.fetchBindingQrCode();
    expect(qr.sceneCode, 'scene');
    expect(
      qr.expiresAt.difference(before).inSeconds,
      inInclusiveRange(179, 180),
    );
    payloads['/api_client/users/user/checkWxghBind'] = {
      'status': 'waiting',
      'bound': false,
    };
    expect(await repository.checkBinding(qr.sceneCode), isFalse);
    expect(requests.last.queryParameters, {'sceneCode': 'scene'});
    payloads['/api_client/users/user/checkWxghBind'] = {
      'status': 'success',
      'bound': true,
    };
    expect(await repository.checkBinding(qr.sceneCode), isTrue);
  });

  test('handles explicit pagination and does not loop on empty pages', () {
    final page = InvitationPage<InvitationCode>.fromJson(
      {'hasNext': true, 'list': []},
      page: 1,
      pageSize: 20,
      parse: InvitationCode.fromJson,
    );
    expect(page.hasMore, isFalse);
    expect(redemptionImageUrl('javascript:alert(1)'), isNull);
    expect(redemptionImageUrl('/relative.png'), isNull);
  });
}
