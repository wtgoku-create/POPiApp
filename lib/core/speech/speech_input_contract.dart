abstract interface class SpeechInput {
  Future<void> start({
    required String locale,
    required void Function(String text) onResult,
    required void Function(String code) onError,
    required void Function() onDone,
  });

  Future<void> stop();

  Future<void> cancel();

  void dispose();
}

final class SpeechInputException implements Exception {
  const SpeechInputException(this.code);

  final String code;

  @override
  String toString() => 'SpeechInputException($code)';
}
