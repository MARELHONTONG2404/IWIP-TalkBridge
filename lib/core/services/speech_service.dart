import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_text_processor.dart';

typedef SpeechErrorCallback = void Function(String message);
typedef SpeechResultCallback = void Function(
  String text, {
  required bool isFinal,
  double confidence,
});
typedef SpeechStatusCallback = void Function(String status);
typedef SpeechSoundLevelCallback = void Function(double level);

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _isAvailable = false;
  String? _lastError;
  String? _activeLocale;
  String _languageCode = 'id';

  SpeechErrorCallback? _onError;
  SpeechStatusCallback? _onStatus;
  SpeechResultCallback? _onResult;
  SpeechSoundLevelCallback? _onSoundLevel;

  static const _autoLocaleToken = '__auto__';

  List<String> _localeFallbackChain = [];
  int _localeFallbackIndex = 0;
  bool _isRetryingLocale = false;

  bool get isListening => _speech.isListening;

  bool get isAvailable => _isAvailable;

  String? get lastError => _lastError;

  String? get activeLocale => _activeLocale;

  Future<bool> hasPermission() => _speech.hasPermission;

  Future<List<LocaleName>> availableLocales() => _speech.locales();

  Future<bool> initialize({
    SpeechErrorCallback? onError,
    SpeechStatusCallback? onStatus,
  }) async {
    print('DEBUG: initialize() called');
    _lastError = null;
    _onError = onError;
    _onStatus = onStatus;

    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        print('DEBUG: onStatus: $status');
        _onStatus?.call(status);
      },
      onError: (error) {
        print('DEBUG: onError: ${error.errorMsg}');
        if (error.errorMsg == 'error_no_match') return;

        if (_handleRecoverableError(error.errorMsg)) return;

        _lastError = _mapErrorMessage(error.errorMsg);
        _onError?.call(_lastError!);
      },
      options: [SpeechToText.androidNoBluetooth],
    );

    print('DEBUG: initialize() result: $_isAvailable');
    if (!_isAvailable) {
      if (kIsWeb) {
        _lastError = 'Browser Anda tidak mendukung Speech Recognition. '
            'Gunakan Google Chrome (Android) atau Safari (iOS) untuk hasil terbaik.';
      } else {
        _lastError ??= 'Speech recognition tidak tersedia di perangkat ini';
      }
    }

    return _isAvailable;
  }

  bool _handleRecoverableError(String code) {
    final canRetry = code == 'error_language_unavailable' ||
        code == 'error_language_not_supported' ||
        code == 'error_client';

    if (!canRetry) return false;

    if (_tryNextLocale()) return true;

    _lastError = _mapErrorMessage(code);
    _onError?.call(_lastError!);
    return true;
  }

  bool _tryNextLocale() {
    if (_onResult == null || _localeFallbackChain.isEmpty) return false;

    _localeFallbackIndex++;
    if (_localeFallbackIndex >= _localeFallbackChain.length) return false;

    final nextLocale = _localeFallbackChain[_localeFallbackIndex];
    _isRetryingLocale = true;

    _listenWithLocale(nextLocale);
    return true;
  }

  String _mapErrorMessage(String raw) {
    switch (raw) {
      case 'error_permission':
        return kIsWeb 
          ? 'Izin mikrofon ditolak oleh browser. Klik ikon gembok di address bar dan aktifkan Microphone.' 
          : 'Izin mikrofon ditolak. Aktifkan di Settings → Apps → ilb → Permissions → Microphone';
      case 'error_network':
        return 'Koneksi internet diperlukan untuk speech recognition';
      case 'error_no_match':
        return 'Suara tidak terdeteksi. Coba bicara lebih dekat ke mic';
      case 'error_busy':
        return 'Mikrofon sedang dipakai app lain. Tutup app lain lalu coba lagi';
      case 'error_client':
        return 'Speech recognition gagal. Pastikan internet aktif, mic tidak dipakai app lain, '
            'dan paket bahasa ${_languageDisplayName(_languageCode)} sudah diunduh di Google app → Voice.';
      case 'error_language_unavailable':
        return _languagePackInstructions(_languageCode);
      case 'error_language_not_supported':
        return _languagePackInstructions(_languageCode);
      default:
        if (raw.toLowerCase().contains('language')) {
          return _languagePackInstructions(_languageCode);
        }
        return raw;
    }
  }

  String _languageDisplayName(String code) {
    switch (code) {
      case 'id':
        return 'Indonesia';
      case 'en':
        return 'English';
      case 'zh':
        return '中文';
      default:
        return code;
    }
  }

  String _languagePackInstructions(String code) {
    final language = _languageDisplayName(code);
    return 'Paket suara $language belum ada di HP. Unduh lewat:\n'
        'Google app → foto profil → Settings → Voice → '
        'Offline speech recognition → $language\n'
        '(Samsung: Settings → Apps → Speech Services by Google → Install voice data)';
  }

  String _normalizeLocale(String locale) =>
      locale.replaceAll('_', '-').toLowerCase();

  String _languageKey(String locale) {
    final normalized = _normalizeLocale(locale);
    final base = normalized.split('-').first;

    if (base == 'in') return 'id';
    if (base == 'cmn' || base == 'yue') return 'zh';
    return base;
  }

  bool _chainHasPreferredLanguage(
    List<String> chain,
    String preferredKey,
  ) {
    for (final locale in chain) {
      if (locale == _autoLocaleToken) continue;
      if (_languageKey(locale) == preferredKey) return true;
    }
    return false;
  }

  Future<List<String>> buildLocaleFallbackChain(String preferredLocale) async {
    final locales = await _speech.locales();
    final preferredKey = _languageKey(preferredLocale);
    final chain = <String>[];
    final seen = <String>{};

    void add(String? localeId) {
      if (localeId == null || localeId.isEmpty || seen.contains(localeId)) {
        return;
      }
      seen.add(localeId);
      chain.add(localeId);
    }

    void addAuto() {
      if (seen.contains(_autoLocaleToken)) return;
      seen.add(_autoLocaleToken);
      chain.add(_autoLocaleToken);
    }

    if (locales.isNotEmpty) {
      for (final locale in locales) {
        if (_normalizeLocale(locale.localeId) ==
            _normalizeLocale(preferredLocale)) {
          add(locale.localeId);
        }
      }

      for (final locale in locales) {
        if (_languageKey(locale.localeId) == preferredKey) {
          add(locale.localeId);
        }
      }

      final system = await _speech.systemLocale();
      if (system != null && _languageKey(system.localeId) == preferredKey) {
        add(system.localeId);
      }

      if (preferredKey == 'en') {
        for (final locale in locales) {
          if (_languageKey(locale.localeId) == 'en') {
            add(locale.localeId);
          }
        }
        add(system?.localeId);
      } else if (!_chainHasPreferredLanguage(chain, preferredKey)) {
        addAuto();
        add(preferredLocale);
        add(preferredLocale.replaceAll('-', '_'));
      }
    } else {
      add(preferredLocale);
      add(preferredLocale.replaceAll('-', '_'));
      addAuto();
    }

    return chain;
  }

  Future<bool> isLocaleAvailable(String preferredLocale) async {
    final chain = await buildLocaleFallbackChain(preferredLocale);
    return chain.isNotEmpty;
  }

  Future<bool> hasLocalLanguagePack(String preferredLocale) async {
    final chain = await buildLocaleFallbackChain(preferredLocale);
    return _chainHasPreferredLanguage(chain, _languageKey(preferredLocale));
  }

  Future<bool> startListening({
    required String localeId,
    required String languageCode,
    required SpeechResultCallback onResult,
    SpeechSoundLevelCallback? onSoundLevel,
  }) async {
    print('DEBUG: startListening() called. locale: $localeId');
    if (!_isAvailable) {
      print('DEBUG: Speech recognition not available');
      _lastError = 'Speech recognition tidak tersedia';
      return false;
    }

    final hasMicPermission = await _speech.hasPermission;
    print('DEBUG: Permission microphone check: $hasMicPermission');
    if (!hasMicPermission) {
      _lastError =
          'Izin mikrofon belum diberikan. Tap mic lagi dan pilih Allow';
      return false;
    }

    _languageCode = languageCode;
    _onResult = onResult;
    _onSoundLevel = onSoundLevel;
    _localeFallbackChain = await buildLocaleFallbackChain(localeId);
    _localeFallbackIndex = 0;
    _isRetryingLocale = false;

    if (_localeFallbackChain.isEmpty) {
      _lastError = _languagePackInstructions(languageCode);
      return false;
    }

    final preferredKey = _languageKey(localeId);
    if (!_chainHasPreferredLanguage(_localeFallbackChain, preferredKey) &&
        !_localeFallbackChain.contains(_autoLocaleToken)) {
      _lastError = _languagePackInstructions(languageCode);
      return false;
    }

    _activeLocale = _resolveActiveLocaleLabel(_localeFallbackChain.first);
    await _listenWithLocale(_localeFallbackChain.first);

    return _speech.isListening;
  }

  String? _resolveActiveLocaleLabel(String localeToken) {
    if (localeToken == _autoLocaleToken) return 'online';
    return localeToken;
  }

  String? _listenLocaleId(String localeToken) {
    if (localeToken == _autoLocaleToken) return null;
    return localeToken;
  }

  Future<void> _listenWithLocale(String localeToken) async {
    if (_speech.isListening) {
      print('DEBUG: Already listening, stopping...');
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    print('DEBUG: Listening started with locale: $localeToken');
    _activeLocale = _resolveActiveLocaleLabel(localeToken);

    print('DEBUG: Calling _speech.listen with options: localeId: ${_listenLocaleId(localeToken)}');
    
    try {
      final success = await _speech.listen(
        onResult: (result) {
          print('DEBUG: [plugin] onResult called. final: ${result.finalResult}, words: "${result.recognizedWords}"');
          if (_onResult == null) {
            print('DEBUG: [plugin] _onResult callback is null!');
            return;
          }
          _handleResult(result, _onResult!);
        },
        onSoundLevelChange: (level) {
          _onSoundLevel?.call(level);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          localeId: _listenLocaleId(localeToken),
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
          cancelOnError: false,
          onDevice: false,
          autoPunctuation: true,
          enableHapticFeedback: true,
        ),
      );
      print('DEBUG: _speech.listen() returned success: $success');
    } catch (e) {
      print('DEBUG: Exception in _speech.listen(): $e');
    }

    if (_isRetryingLocale && _speech.isListening) {

      _isRetryingLocale = false;
      final label = _activeLocale ?? localeToken;
      _onError?.call(
        'Mencoba mode lain ($label). Silakan bicara lagi.',
      );
    }
  }

  void _handleResult(
    SpeechRecognitionResult result,
    SpeechResultCallback onResult,
  ) {
    final raw = SpeechTextProcessor.pickBestText(result);
    print('DEBUG: [handleResult] Raw words: "$raw" (final: ${result.finalResult}, conf: ${result.confidence})');
    if (raw.trim().isEmpty) return;

    final processed = SpeechTextProcessor.postProcess(raw, _languageCode);
    print('DEBUG: [handleResult] Processed words: "$processed"');
    if (processed.isEmpty) return;

    final confidence = result.confidence;

    // Be more permissive with confidence for partial results to ensure responsiveness
    if (!result.finalResult) {
      final hasRating = result.hasConfidenceRating;
      if (hasRating && confidence < 0.05) {
        print('DEBUG: [handleResult] Partial result filtered due to extremely low confidence: $confidence');
        return;
      }
    }

    onResult(
      processed,
      isFinal: result.finalResult,
      confidence: confidence,
    );
  }

  Future<void> stopListening() async {
    print('DEBUG: Listening stopped');
    _onResult = null;
    _onSoundLevel = null;
    _localeFallbackChain = [];
    await _speech.stop();
  }

  Future<void> cancelListening() async {
    _onResult = null;
    _onSoundLevel = null;
    _localeFallbackChain = [];
    await _speech.cancel();
  }
}
