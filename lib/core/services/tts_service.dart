import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

typedef TtsCompletionCallback = void Function();
typedef TtsErrorCallback = void Function(String message, {bool isMissingVoice});

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _initFuture;
  TtsCompletionCallback? _onComplete;
  TtsCompletionCallback? _onStart;
  TtsErrorCallback? _onError;

  // Cached state for logging
  String _currentEngine = 'Unknown';
  List<dynamic> _availableLanguages = [];
  List<dynamic> _availableVoices = [];

  TtsService() {
    _initFuture = _initTts();
  }

  Future<void> _initTts() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final engines = await _tts.getEngines;
        final hasGoogle = engines.any(
          (e) => (e['name'] as String?)?.contains('google') ?? false,
        );
        if (hasGoogle) {
          await _tts.setEngine('com.google.android.tts');
          _currentEngine = 'com.google.android.tts';
        } else {
          _currentEngine = await _tts.getDefaultEngine ?? 'Unknown';
        }
      } else if (!kIsWeb && Platform.isIOS) {
        _currentEngine = 'iOS Default';
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
        );
      }

      _availableLanguages = await _tts.getLanguages;
      _availableVoices = await _tts.getVoices;

      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setLanguage('id-ID');

      _tts.setStartHandler(() => _onStart?.call());
      _tts.setCompletionHandler(() => _onComplete?.call());
      _tts.setCancelHandler(() => _onComplete?.call());
      _tts.setErrorHandler((msg) {
        _log('[TTS] Error from handler: $msg');
        _onError?.call('Suara gagal diputar. Unduh paket suara di pengaturan HP.', isMissingVoice: false);
      });
    } catch (e) {
      _log('[TTS] init failed: $e');
    }
  }

  void setHandlers({
    TtsCompletionCallback? onStart,
    TtsCompletionCallback? onComplete,
    TtsErrorCallback? onError,
  }) {
    _onStart = onStart;
    _onComplete = onComplete;
    _onError = onError;
  }

  Future<void> _ensureReady() => _initFuture ?? _initTts();

  /// Membacakan teks. Mengembalikan true jika berhasil dimulai.
  Future<bool> speak(
    String text, {
    String? languageCode,
    String? speechCode,
    bool notifyOnError = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    await _ensureReady();
    await _tts.stop();

    final requestedLocale = await _resolveLocale(
      languageCode: languageCode,
      speechCode: speechCode,
    );

    _log('\n[TTS]\nEngine: $_currentEngine\nAvailable Languages: ${_availableLanguages.length} items\nAvailable Voices: ${_availableVoices.length} items\nRequested Locale: $requestedLocale');

    try {
      final String? finalLocale = await _applyLanguage(requestedLocale);
      
      _log('Resolved Locale: $finalLocale');

      if (finalLocale == null) {
        _log('Speak Result: 0 (Language/Voice not available)');
        _log('Error: Missing voice for $requestedLocale');
        
        if (notifyOnError) {
          _onError?.call(
            'Paket suara Mandarin belum tersedia.\nSilakan buka: Settings → Google Text-to-Speech → Install Chinese (Simplified).',
            isMissingVoice: true,
          );
        }
        return false;
      }

      // Ensure volume is up
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.48);

      final result = await _tts.speak(trimmed);
      _log('Speak Result: $result');
      
      final ok = result == 1;
      if (!ok && notifyOnError) {
        _onError?.call('Suara tidak dapat diputar. Cek volume HP dan paket suara.', isMissingVoice: false);
      }
      return ok;
    } catch (e, st) {
      _log('Speak Result: 0 (Exception)');
      _log('Error: $e\n$st');
      if (notifyOnError) {
        _onError?.call('Terjadi kesalahan saat memutar suara.', isMissingVoice: false);
      }
      return false;
    }
  }

  /// Tries to set the language. Returns the exact locale that worked, or null if failed.
  Future<String?> _applyLanguage(String locale) async {
    bool isAvailable = await _tts.isLanguageAvailable(locale);
    if (isAvailable) {
      final res = await _tts.setLanguage(locale);
      if (res == 1) return locale;
    }

    // Coba varian locale (umum di Android untuk Mandarin).
    for (final alt in _localeAlternatives(locale)) {
      isAvailable = await _tts.isLanguageAvailable(alt);
      if (isAvailable) {
        final res = await _tts.setLanguage(alt);
        if (res == 1) return alt;
      }
    }
    
    // Jika tidak ada varian yang cocok dan ini adalah bahasa Mandarin (zh/zh-CN),
    // kita JANGAN fallback ke bahasa Inggris atau Indonesia.
    if (locale.toLowerCase().startsWith('zh')) {
       // Abaikan fallback ke en/id, kembalikan null untuk trigger dialog missing voice.
       return null;
    }
    
    return null;
  }

  List<String> _localeAlternatives(String locale) {
    switch (locale.toLowerCase()) {
      case 'zh-cn':
        return ['cmn-CN', 'cmn_CN', 'zh_CN', 'zh-CN', 'zh'];
      case 'zh':
        return ['zh-CN', 'cmn-CN', 'zh_CN', 'cmn_CN'];
      case 'id-id':
        return ['id_ID', 'in-ID', 'in_ID', 'id'];
      case 'en-us':
        return ['en_US', 'en-GB', 'en_GB', 'en'];
      default:
        return [locale.replaceAll('-', '_'), locale.replaceAll('_', '-')];
    }
  }

  Future<String> _resolveLocale({
    String? languageCode,
    String? speechCode,
  }) async {
    if (speechCode != null && speechCode.isNotEmpty) {
      return speechCode;
    }

    switch (languageCode) {
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
        return languageCode ?? 'id-ID';
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
    _onStart = null;
    _onComplete = null;
    _onError = null;
  }
}
