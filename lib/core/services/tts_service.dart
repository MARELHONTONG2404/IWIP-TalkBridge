import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

typedef TtsCompletionCallback = void Function();
typedef TtsErrorCallback = void Function(String message);

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _initFuture;
  TtsCompletionCallback? _onComplete;
  TtsCompletionCallback? _onStart;
  TtsErrorCallback? _onError;

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
        }
      }

      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setLanguage('id-ID');

      _tts.setStartHandler(() => _onStart?.call());
      _tts.setCompletionHandler(() => _onComplete?.call());
      _tts.setCancelHandler(() => _onComplete?.call());
      _tts.setErrorHandler((msg) {
        _log('[TTS] error: $msg');
        _onError?.call('Suara gagal diputar. Unduh paket suara di pengaturan HP.');
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

    final locale = await _resolveLocale(
      languageCode: languageCode,
      speechCode: speechCode,
    );

    final langOk = await _applyLanguage(locale);
    if (!langOk) {
      _log('[TTS] language not available: $locale');
      if (notifyOnError) {
        _onError?.call(
          'Paket suara belum terpasang. Buka Settings → Google TTS → '
          'Install voice data untuk bahasa tujuan.',
        );
      }
      return false;
    }

    final result = await _tts.speak(trimmed);
    final ok = result == 1;
    if (!ok && notifyOnError) {
      _onError?.call('Suara tidak dapat diputar. Cek volume HP dan paket suara.');
    }
    return ok;
  }

  Future<bool> _applyLanguage(String locale) async {
    var result = await _tts.setLanguage(locale);
    if (result == 1) return true;

    // Coba varian locale (umum di Android untuk Mandarin).
    for (final alt in _localeAlternatives(locale)) {
      result = await _tts.setLanguage(alt);
      if (result == 1) return true;
    }
    return false;
  }

  List<String> _localeAlternatives(String locale) {
    switch (locale.toLowerCase()) {
      case 'zh-cn':
        return ['cmn-CN', 'cmn_CN', 'zh_CN', 'zh-CN'];
      case 'id-id':
        return ['id_ID', 'in-ID', 'in_ID'];
      case 'en-us':
        return ['en_US', 'en-GB', 'en_GB'];
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
  }
}
