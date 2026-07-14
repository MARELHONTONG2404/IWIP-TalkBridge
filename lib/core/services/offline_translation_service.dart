import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Maps ISO language codes to ML Kit TranslateLanguage enums
final Map<String, TranslateLanguage> _mlKitLanguages = {
  'id': TranslateLanguage.indonesian,
  'en': TranslateLanguage.english,
  'zh': TranslateLanguage.chinese,
  'ja': TranslateLanguage.japanese,
  'ko': TranslateLanguage.korean,
  'ar': TranslateLanguage.arabic,
  'fr': TranslateLanguage.french,
  'de': TranslateLanguage.german,
  'es': TranslateLanguage.spanish,
  'ru': TranslateLanguage.russian,
  'pt': TranslateLanguage.portuguese,
  'hi': TranslateLanguage.hindi,
  'th': TranslateLanguage.thai,
  'vi': TranslateLanguage.vietnamese,
};

class OfflineTranslationService {
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  /// Cached translators to avoid recreating them repeatedly
  final Map<String, OnDeviceTranslator> _translatorCache = {};

  TranslateLanguage? _getLanguage(String code) => _mlKitLanguages[code];

  bool isLanguageSupported(String code) =>
      _mlKitLanguages.containsKey(code);

  /// Check whether the model for [languageCode] is downloaded on this device
  Future<bool> isModelDownloaded(String languageCode) async {
    final lang = _getLanguage(languageCode);
    if (lang == null) return false;
    return await _modelManager.isModelDownloaded(lang.bcpCode);
  }

  /// Download the translation model for [languageCode].
  /// Provide [onProgress] callback (0.0–1.0) to track progress.
  Future<void> downloadModel(
    String languageCode, {
    void Function(double progress)? onProgress,
  }) async {
    final lang = _getLanguage(languageCode);
    if (lang == null) {
      throw Exception('Bahasa "$languageCode" tidak didukung offline.');
    }

    // Simulate incremental progress since ML Kit doesn't expose progress natively
    onProgress?.call(0.05);
    await _modelManager.downloadModel(lang.bcpCode, isWifiRequired: false);
    onProgress?.call(1.0);
  }

  /// Delete a downloaded model to free storage
  Future<void> deleteModel(String languageCode) async {
    final lang = _getLanguage(languageCode);
    if (lang == null) return;
    await _modelManager.deleteModel(lang.bcpCode);
    // Remove any cached translator for this language
    _translatorCache.removeWhere(
      (key, _) => key.contains(languageCode),
    );
  }

  /// Translate [text] from [from] to [to] entirely on-device (no internet needed).
  /// The relevant models must be downloaded first.
  Future<String> translate({
    required String text,
    required String from,
    required String to,
  }) async {
    if (text.trim().isEmpty) return '';
    if (from == to) return text;

    final sourceLang = _getLanguage(from);
    final targetLang = _getLanguage(to);

    if (sourceLang == null || targetLang == null) {
      throw Exception(
        'Bahasa "$from" atau "$to" tidak didukung untuk terjemahan offline.',
      );
    }

    final cacheKey = '${from}_$to';
    _translatorCache[cacheKey] ??= OnDeviceTranslator(
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
    );

    final translator = _translatorCache[cacheKey]!;
    final result = await translator.translateText(text);
    return result;
  }

  /// Close all cached translators and free resources
  Future<void> dispose() async {
    for (final translator in _translatorCache.values) {
      translator.close();
    }
    _translatorCache.clear();
  }
}
