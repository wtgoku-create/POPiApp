import 'user.dart';

/// Browser authorization uses a QR scene or a one-time OAuth state.
class WebSocialLoginChallenge {
  const WebSocialLoginChallenge({
    required this.state,
    required this.url,
    required this.expiresIn,
  });

  final String state;
  final String url;
  final Duration expiresIn;

  factory WebSocialLoginChallenge.fromJson(
    Map<String, dynamic> json, {
    required bool douyin,
  }) {
    final state = (douyin ? json['state'] : json['sceneCode'] ?? json['scene'])
        ?.toString()
        .trim();
    final url =
        (douyin
                ? json['authUrl']
                : json['qrCodeUrl'] ??
                      json['qrUrl'] ??
                      json['url'] ??
                      json['qr_code'])
            ?.toString()
            .trim();
    if (state == null || state.isEmpty || url == null || url.isEmpty) {
      throw const FormatException('Missing browser authorization challenge');
    }
    if (douyin) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          !uri.hasAuthority ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid authorization URL');
      }
    }
    final seconds = json['expireSeconds'];
    return WebSocialLoginChallenge(
      state: state,
      url: url,
      expiresIn: Duration(
        seconds: seconds is num && seconds > 0 ? seconds.toInt() : 300,
      ),
    );
  }
}

sealed class WebSocialSignInResult {
  const WebSocialSignInResult();
}

class WebSocialWaiting extends WebSocialSignInResult {
  const WebSocialWaiting();
}

class WebSocialPhoneBindingRequired extends WebSocialSignInResult {
  const WebSocialPhoneBindingRequired(this.registerToken);
  final String registerToken;
}

class WebSocialSignInSucceeded extends WebSocialSignInResult {
  const WebSocialSignInSucceeded(this.user);
  final User user;
}
