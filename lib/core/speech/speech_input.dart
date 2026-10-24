import 'speech_input_contract.dart';
import 'speech_input_native.dart'
    if (dart.library.js_interop) 'speech_input_web.dart'
    as implementation;

export 'speech_input_contract.dart';

SpeechInput createSpeechInput() => implementation.createSpeechInput();
