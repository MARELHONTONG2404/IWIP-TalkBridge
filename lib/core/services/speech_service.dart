import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
// Mengganti speech_to_text dengan talk_it (Sesuai instruksi Anda)
// import 'package:talk_it/talk_it.dart'; // Uncomment jika menggunakan package talk_it

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
  // Simulasi instance TalkIt. Sesuaikan dengan API plugin talk_it / manual_speech_to_text Anda
  // final TalkIt _speech = TalkIt();
  
  // Flag simulasi
  bool _isListening = false;
  
  bool _isAvailable = false;
  String? _lastError;
  String _languageCode = 'id';

  SpeechErrorCallback? _onError;
  SpeechStatusCallback? _onStatus;
  SpeechResultCallback? _onResult;
  SpeechSoundLevelCallback? _onSoundLevel;

  bool _manualControl = false;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String? get lastError => _lastError;

  // Hapus fallback/auto locale yang rumit karena mengurangi akurasi
  // Kita akan force menggunakan locale spesifik

  Future<bool> hasPermission() async {
    final permission = await MicPermissionService.ensureGranted();
    return permission.granted;
  }

  Future<bool> initialize({
    SpeechErrorCallback? onError,
    SpeechStatusCallback? onStatus,
  }) async {
    _lastError = null;
    _onError = onError;
    _onStatus = onStatus;

    // TODO: Sesuaikan dengan inisialisasi plugin talk_it / baidu
    // _isAvailable = await _speech.initialize(...);
    
    // Sebagai simulasi sukses inisialisasi:
    _isAvailable = true;

    if (!_isAvailable) {
      if (kIsWeb) {
        _lastError = 'Browser Anda tidak mendukung Speech Recognition.';
      } else {
        _lastError ??= 'Speech recognition tidak tersedia di perangkat ini';
      }
    }

    return _isAvailable;
  }

  Future<bool> startListening({
    required String localeId, // Akan kita paksa ke 'id_ID' atau 'zh_CN'
    required String languageCode,
    required SpeechResultCallback onResult,
    SpeechSoundLevelCallback? onSoundLevel,
    bool autoDetectLanguage = false, // Tidak dipakai lagi
    bool manualControl = false,
    List<String>? sessionLanguageCodes,
  }) async {
    if (!_isAvailable) {
      _lastError = 'Speech recognition tidak diinisialisasi.';
      return false;
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      _lastError = 'Izin mikrofon diperlukan untuk merekam suara';
      return false;
    }

    // PAKSA PENGGUNAAN BAHASA SPESIFIK (Meningkatkan Akurasi)
    // Jika languageCode adalah 'id', pastikan localeId = 'id_ID'
    // Jika languageCode adalah 'zh', pastikan localeId = 'zh_CN'
    String strictLocale = 'id_ID';
    if (languageCode == 'zh') {
      strictLocale = 'zh_CN';
    } else if (languageCode == 'en') {
      strictLocale = 'en_US';
    }

    _languageCode = languageCode;
    _onResult = onResult;
    _onSoundLevel = onSoundLevel;
    _manualControl = manualControl;
    _isListening = true;

    try {
      _onStatus?.call('listening');
      
      // TODO: Panggil fungsi listen dari talk_it atau BaiduSpeechService Anda di sini
      // Contoh dengan talk_it:
      // await _speech.listen(
      //   locale: strictLocale, // <- KUNCI AKURASI: Gunakan strictLocale, jangan auto
      //   onResult: (text, isFinal) {
      //      final processed = SpeechTextProcessor.postProcess(text, _languageCode);
      //      _onResult?.call(processed, isFinal: isFinal, confidence: 1.0);
      //   }
      // );
      
    } catch (e) {
      _lastError = 'Gagal memulai mikrofon: $e';
      _isListening = false;
      return false;
    }

    return true;
  }

  Future<bool> continueManualListening() async {
    if (!_isAvailable || _onResult == null) return false;
    if (_isListening) return true;
    
    // Implementasikan ulang dengan locale terakhir jika engine tiba-tiba mati
    // await startListening(...)
    return true;
  }

  Future<void> stopListening() async {
    _manualControl = false;
    _onSoundLevel = null;
    
    // TODO: await _speech.stop();
    _isListening = false;
    
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _onStatus?.call('done');
    _onResult = null;
  }

  Future<void> cancelListening() async {
    _onResult = null;
    _onSoundLevel = null;
    
    // TODO: await _speech.cancel();
    _isListening = false;
    _onStatus?.call('notListening');
  }

  Future<void> dispose() async {
    _onResult = null;
    _onStatus = null;
    _onError = null;
    _onSoundLevel = null;
    _manualControl = false;
    
    // TODO: Hentikan engine talk_it
  }
}
