import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/speech/speech_input.dart';

final speechInputFactoryProvider = Provider<SpeechInput Function()>(
  (ref) => createSpeechInput,
);
