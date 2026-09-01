import 'dart:convert';
import 'dart:typed_data';

class CaptchaChallenge {
  const CaptchaChallenge({required this.id, required this.imageBase64});

  final String id;
  final String imageBase64;

  Uint8List get imageBytes {
    final payload = imageBase64.contains(',')
        ? imageBase64.substring(imageBase64.indexOf(',') + 1)
        : imageBase64;
    return base64Decode(payload);
  }

  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) {
    return CaptchaChallenge(
      id: json['id'].toString(),
      imageBase64: json['data'] as String? ?? '',
    );
  }
}
