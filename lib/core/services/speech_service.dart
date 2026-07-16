import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'mic_permission_service.dart';
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
  bool _manualControl = false;

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
    _lastError = null;
    _onError = onError;
    _onStatus = onStatus;

    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        _onStatus?.call(status);
      },
      onError: (error) {
        if (error.errorMsg == 'error_no_match') return;

        if (_handleRecoverableError(error.errorMsg)) return;

        _lastError = _mapErrorMessage(error.errorMsg);
        _onError?.call(_lastError!);
      },
      options: [SpeechToText.androidNoBluetooth],
    );

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

  /// Tunggu engine STT benar-benar aktif (hindari false-negative langsung setelah listen).
  Future<bool> _waitUntilListening({int attempts = 8}) async {
    for (var i = 0; i < attempts; i++) {
      if (_speech.isListening) return true;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return _speech.isListening;
  }

  Future<bool> startListening({
    required String localeId,
    required String languageCode,
    required SpeechResultCallback onResult,
    SpeechSoundLevelCallback? onSoundLevel,
    /// Auto-detect: jangan kunci ke bahasa picker user (mirip Google Translate).
    bool autoDetectLanguage = false,
    /// Manual mic: jangan auto-stop karena jeda singkat.
    bool manualControl = false,
  }) async {
    if (!_isAvailable) {
      if (!kIsWeb && Platform.isAndroid) {
        _lastError =
            'Speech recognition tidak tersedia. Pastikan Google app terpasang, '
            'internet aktif, dan Speech Services by Google sudah di-update.';
      } else {
        _lastError = 'Speech recognition tidak tersedia';
      }
      return false;
    }

    final permission = await MicPermissionService.ensureGranted();
    if (!permission.granted) {
      _lastError = permission.message ??
          'Izin mikrofon diperlukan untuk merekam suara';
      return false;
    }

    final hadPermission = await _speech.hasPermission;

    _languageCode = autoDetectLanguage ? 'auto' : languageCode;
    _onResult = onResult;
    _onSoundLevel = onSoundLevel;
    _manualControl = manualControl;

    if (autoDetectLanguage) {
      _localeFallbackChain = await _buildAutoDetectLocaleChain();
    } else {
      // Paksa locale baku: id-ID / en-US / zh-CN.
      final preferredLocale = _canonicalLocale(languageCode, localeId);
      _localeFallbackChain = await buildLocaleFallbackChain(preferredLocale);
    }
    _localeFallbackIndex = 0;
    _isRetryingLocale = false;

    if (_localeFallbackChain.isEmpty) {
      _lastError = _languagePackInstructions(
        autoDetectLanguage ? 'id' : languageCode,
      );
      return false;
    }

    if (!autoDetectLanguage) {
      final preferredKey = _languageKey(
        _canonicalLocale(languageCode, localeId),
      );
      if (!_chainHasPreferredLanguage(_localeFallbackChain, preferredKey) &&
          !_localeFallbackChain.contains(_autoLocaleToken)) {
        _lastError = _languagePackInstructions(languageCode);
        return false;
      }
    }

    _activeLocale = _resolveActiveLocaleLabel(_localeFallbackChain.first);

    // Coba tiap locale sampai mic benar-benar menyala (umum di HP Android).
    for (var i = 0; i < _localeFallbackChain.length; i++) {
      _localeFallbackIndex = i;
      final token = _localeFallbackChain[i];
      _activeLocale = _resolveActiveLocaleLabel(token);
      await _listenWithLocale(token);

      final listening = await _waitUntilListening(attempts: 12);
      if (listening) return true;
    }

    final hasPermissionNow = await _speech.hasPermission;
    if (!hadPermission && !hasPermissionNow) {
      _lastError =
          'Izin mikrofon ditolak. Aktifkan di Settings → Apps → ilb → Permissions → Microphone';
      return false;
    }
    if (!hasPermissionNow) {
      _lastError =
          'Izin mikrofon belum diberikan. Tap Dengarkan lagi dan pilih Allow';
      return false;
    }

    _lastError ??= _languagePackInstructions(
      autoDetectLanguage ? 'id' : languageCode,
    );
    return false;
  }

  /// Lanjutkan sesi manual setelah engine berhenti sendiri (bukan Stop user).
  Future<bool> continueManualListening() async {
    if (!_isAvailable || _onResult == null) return false;
    if (_speech.isListening) return true;
    if (_localeFallbackChain.isEmpty) return false;
    final token = _localeFallbackChain[
        _localeFallbackIndex.clamp(0, _localeFallbackChain.length - 1)];
    await _listenWithLocale(token);
    return _waitUntilListening();
  }

  Future<List<String>> _buildAutoDetectLocaleChain() async {
    final locales = await _speech.locales();
    final chain = <String>[];
    final seen = <String>{};

    void add(String? localeId) {
      if (localeId == null || localeId.isEmpty || seen.contains(localeId)) {
        return;
      }
      seen.add(localeId);
      chain.add(localeId);
    }

    void addPreferredLocales() {
      for (final preferred in ['id-ID', 'en-US', 'zh-CN']) {
        for (final locale in locales) {
          if (_normalizeLocale(locale.localeId) ==
              _normalizeLocale(preferred)) {
            add(locale.localeId);
          }
        }
        for (final locale in locales) {
          if (_languageKey(locale.localeId) == _languageKey(preferred)) {
            add(locale.localeId);
          }
        }
        add(preferred);
        add(preferred.replaceAll('-', '_'));
      }
    }

    // HP Android sering gagal jika locale null (online auto) dipakai pertama.
    if (!kIsWeb && Platform.isAndroid) {
      addPreferredLocales();
      add(_autoLocaleToken);
    } else {
      add(_autoLocaleToken);
      addPreferredLocales();
    }
    return chain;
  }

  String _canonicalLocale(String languageCode, String localeId) {
    switch (languageCode) {
      case 'id':
        return 'id-ID';
      case 'en':
        return 'en-US';
      case 'zh':
        return 'zh-CN';
      default:
        return localeId;
    }
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
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _activeLocale = _resolveActiveLocaleLabel(localeToken);

    
    try {
      await _speech.listen(
        onResult: (result) {
          if (_onResult == null) {
            return;
          }
          _handleResult(result, _onResult!);
        },
        onSoundLevelChange: (level) {
          _onSoundLevel?.call(level);
        },
        listenOptions: SpeechListenOptions(
          // Partial hanya untuk preview UI — translate menunggu final (mirip Google Translate).
          partialResults: true,
          listenMode: ListenMode.dictation,
          localeId: _listenLocaleId(localeToken),
          listenFor: _manualControl
              ? const Duration(minutes: 30)
              : const Duration(seconds: 120),
          // Manual: jangan auto-stop karena jeda singkat saat masih sesi mic.
          pauseFor: _manualControl
              ? const Duration(minutes: 5)
              : const Duration(seconds: 3),
          cancelOnError: false,
          onDevice: false,
          autoPunctuation: true,
          enableHapticFeedback: true,
        ),
      );
    } catch (e) {
      _lastError = 'Gagal memulai mikrofon: $e';
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
    if (raw.trim().isEmpty) return;

    final processed = SpeechTextProcessor.postProcess(raw, _languageCode);
    if (processed.isEmpty) return;

    final confidence = result.confidence;
    final hasRating = result.hasConfidenceRating;

    // Partial: toleran. Final berkepuasan rendah tetap dikirim; UI tolak translate.
    if (!result.finalResult) {
      if (hasRating && confidence > 0 && confidence < 0.05) {
        return;
      }
    }

    onResult(
      processed,
      isFinal: result.finalResult,
      confidence: hasRating ? confidence : -1,
    );
  }

  Future<void> stopListening() async {
    _manualControl = false;
    _onSoundLevel = null;
    _localeFallbackChain = [];
    // Jangan clear _onResult sebelum stop — final STT sering datang setelah stop().
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _onResult = null;
  }

  Future<void> cancelListening() async {
    _onResult = null;
    _onSoundLevel = null;
    _localeFallbackChain = [];
    await _speech.cancel();
  }
}
