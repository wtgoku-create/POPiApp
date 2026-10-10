/// Pagination shared by invitation codes and invitation records.
class InvitationPage<T> {
  const InvitationPage({required this.items, required this.hasMore});

  final List<T> items;
  final bool hasMore;

  factory InvitationPage.fromJson(
    Map<String, dynamic> json, {
    required int page,
    required int pageSize,
    required T Function(Map<String, dynamic>) parse,
  }) {
    final raw = json['list'];
    if (raw is! List) throw const FormatException('Missing invitation list');
    final items = raw
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid invitation item');
          }
          return parse(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    final info = json['pageInfo'] is Map ? json['pageInfo'] as Map : json;
    final current = _number(info['page']) ?? page;
    final size = _number(info['pageSize']) ?? pageSize;
    final count = _number(info['pageCount']);
    final total = _number(info['total']);
    final explicit =
        json['hasMore'] ??
        json['hasNext'] ??
        info['hasMore'] ??
        info['hasNext'];
    final hasMore = explicit is bool
        ? explicit
        : count != null
        ? current < count
        : total != null
        ? current * size < total
        : items.length >= pageSize;
    return InvitationPage(items: items, hasMore: items.isNotEmpty && hasMore);
  }
}

class InvitationCode {
  const InvitationCode({required this.code, required this.usedCount});

  final String code;
  final int usedCount;
  bool get isUsed => usedCount > 0;

  factory InvitationCode.fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString() ?? '';
    if (code.isEmpty) throw const FormatException('Missing invitation code');
    return InvitationCode(
      code: code,
      usedCount: _number(json['usedCount']) ?? 0,
    );
  }
}

class InvitationRecord {
  const InvitationRecord({required this.name, required this.createdAt});

  final String name;
  final DateTime? createdAt;

  factory InvitationRecord.fromJson(Map<String, dynamic> json) =>
      InvitationRecord(
        name: json['inviteeUserName']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createTime']?.toString() ?? ''),
      );
}

class RegistrationReward {
  const RegistrationReward({
    required this.points,
    required this.claimed,
    required this.code,
  });

  final int points;
  final bool claimed;
  final String code;

  factory RegistrationReward.fromJson(
    Map<String, dynamic> rule,
    Map<String, dynamic> used,
  ) {
    final points = _number(rule['points']);
    if (points == null) throw const FormatException('Missing reward points');
    return RegistrationReward(
      points: points,
      claimed: used['id'] != null,
      code: (used['code'] ?? used['inviteCode'])?.toString() ?? '',
    );
  }
}

class RegistrationRewardUnavailable implements Exception {
  const RegistrationRewardUnavailable();
}

class WechatBindingQrCode {
  const WechatBindingQrCode({
    required this.sceneCode,
    required this.url,
    required this.expiresAt,
  });

  final String sceneCode;
  final String url;
  final DateTime expiresAt;

  factory WechatBindingQrCode.fromJson(Map<String, dynamic> json) {
    final scene = json['sceneCode']?.toString() ?? '';
    final url = redemptionImageUrl(json['qrCodeUrl']);
    if (scene.isEmpty || url == null) {
      throw const FormatException('Missing binding QR code');
    }
    return WechatBindingQrCode(
      sceneCode: scene,
      url: url,
      expiresAt: DateTime.now().add(
        Duration(seconds: _number(json['expireSeconds']) ?? 300),
      ),
    );
  }
}

String? redemptionImageUrl(Object? value) {
  final uri = Uri.tryParse(value?.toString().trim() ?? '');
  return uri != null &&
          uri.hasAuthority &&
          (uri.scheme == 'https' || uri.scheme == 'http')
      ? uri.toString()
      : null;
}

int? _number(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
