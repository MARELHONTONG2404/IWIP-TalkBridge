import 'package:flutter_tts/flutter_tts.dart';

typedef TtsCompletionCallback = void Function();

class TtsService {
  final FlutterTts _tts = FlutterTts();
  TtsCompletionCallback? _onComplete;
  TtsCompletionCallback? _onStart;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => _onStart?.call());
    _tts.setCompletionHandler(() => _onComplete?.call());
    _tts.setCancelHandler(() => _onComplete?.call());
  }

  void setHandlers({
    TtsCompletionCallback? onStart,
    TtsCompletionCallback? onComplete,
  }) {
    _onStart = onStart;
    _onComplete = onComplete;
  }

  Future<void> speak(String text, {String? languageCode}) async {
    if (languageCode != null) {
      final locale = _localeForCode(languageCode);
      await _tts.setLanguage(locale);
    }
    await _tts.speak(text);
  }

  String _localeForCode(String code) {
    switch (code) {
      case 'id':
        return 'id-ID';
      case 'en':
        return 'en-US';
      case 'zh':
        return 'zh-CN';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      default:
        return code;
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
