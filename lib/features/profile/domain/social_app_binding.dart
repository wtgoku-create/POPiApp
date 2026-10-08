/// The server is the source of truth for a user's social account binding.
class SocialAppBinding {
  const SocialAppBinding({
    required this.bound,
    this.nickname = '',
    this.avatar = '',
  });

  final bool bound;
  final String nickname;
  final String avatar;

  factory SocialAppBinding.fromJson(Map<String, dynamic> json) {
    final bound = json['bound'];
    if (bound is! bool) {
      throw const FormatException('Missing social account binding status');
    }
    return SocialAppBinding(
      bound: bound,
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
    );
  }
}

enum SocialBindingFailure { canceled, unavailable, failed }

class SocialBindingException implements Exception {
  const SocialBindingException(this.reason);

  final SocialBindingFailure reason;
}
