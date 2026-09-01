import 'user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    this.expiresIn,
  });

  final User user;
  final String accessToken;
  final Duration? expiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final expired = json['expired'];
    return AuthSession(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: (json['token'] ?? json['accessToken']) as String,
      expiresIn: expired is num ? Duration(seconds: expired.toInt()) : null,
    );
  }
}
