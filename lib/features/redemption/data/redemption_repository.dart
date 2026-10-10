import '../../../core/network/network_api.dart';
import '../../../core/network/api_exception.dart';
import '../domain/redemption.dart';

/// Adapts the same authenticated redemption contracts used by the web client.
class RedemptionRepository {
  const RedemptionRepository(this.api);

  final NetworkApi api;

  Future<bool> isWechatBound() async {
    final data = await api.wechatOfficialBindingStatus();
    if (data['bound'] is! bool) {
      throw const FormatException('Missing binding status');
    }
    return data['bound'] as bool;
  }

  Future<WechatBindingQrCode> fetchBindingQrCode() async =>
      WechatBindingQrCode.fromJson(await api.wechatOfficialBindingQrCode());

  Future<bool> checkBinding(String sceneCode) async {
    final data = await api.checkWechatOfficialBinding(sceneCode);
    if (data['bound'] is! bool) {
      throw const FormatException('Missing binding result');
    }
    return data['bound'] == true && data['status'] == 'success';
  }

  Future<InvitationPage<InvitationCode>> fetchCodes(
    int page, {
    int pageSize = 20,
  }) async => InvitationPage.fromJson(
    await api.inviteCodes(page, pageSize),
    page: page,
    pageSize: pageSize,
    parse: InvitationCode.fromJson,
  );

  Future<InvitationPage<InvitationRecord>> fetchRecords(
    int page, {
    int pageSize = 20,
  }) async => InvitationPage.fromJson(
    await api.inviteRecords(page, pageSize),
    page: page,
    pageSize: pageSize,
    parse: InvitationRecord.fromJson,
  );

  Future<RegistrationReward> fetchRegistrationReward() async {
    final Map<String, dynamic> rule;
    try {
      rule = await api.pointsRewardRule('invited_friend');
    } on ApiException {
      throw const RegistrationRewardUnavailable();
    }
    final used = await api.usedInviteCode();
    return RegistrationReward.fromJson(rule, used);
  }

  Future<void> claimRegistrationReward(String code) =>
      api.useInviteCode(_code(code));

  String _code(String value) {
    final code = value.trim();
    if (code.isEmpty) throw ArgumentError.value(value, 'code');
    return code;
  }
}
