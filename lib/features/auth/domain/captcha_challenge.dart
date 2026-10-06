class CaptchaChallenge {
  const CaptchaChallenge(
      {required this.id, required this.bgUrl, required this.puzzleUrl});

  final String id;
  final String bgUrl;
  final String puzzleUrl;

  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final bgUrl = json['bgUrl'] as String? ?? '';
    final puzzleUrl = json['puzzleUrl'] as String? ?? '';
    if (id.isEmpty || bgUrl.isEmpty || puzzleUrl.isEmpty) {
      throw const FormatException('Invalid slider captcha challenge');
    }
    return CaptchaChallenge(id: id, bgUrl: bgUrl, puzzleUrl: puzzleUrl);
  }
}

class SliderCaptchaVerification {
  const SliderCaptchaVerification(
      {required this.captchaId,
      required this.phone,
      required this.x,
      required this.y,
      required this.sliderOffsetX,
      required this.duration,
      required this.trail});

  final String captchaId;
  final String phone;
  final double x;
  final double y;
  final double sliderOffsetX;
  final int duration;
  final List<List<double>> trail;

  Map<String, dynamic> toJson() => {
        'id': captchaId,
        'phone': phone,
        'usage': 'LOGIN',
        'type': 'SLIDER',
        'x': x,
        'y': y,
        'sliderOffsetX': sliderOffsetX,
        'duration': duration,
        'trail': trail,
        'targetType': 'button',
      };
}
