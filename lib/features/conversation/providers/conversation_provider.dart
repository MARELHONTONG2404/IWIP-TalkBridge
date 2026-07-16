import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/iwip_glossary_processor.dart';
import '../../../../core/services/language_detector.dart';
import '../../../../core/services/offline_translation_service.dart';
import '../../../../core/services/speech_text_processor.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/services/translation_text_processor.dart';
import '../../language/data/language_model.dart';
import '../../history/providers/history_provider.dart';
import '../../settings/providers/settings_provider.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Status alur kerja: Listening → STT → Detect → Translate → TTS → Selesai.
enum ConversationPhase {
  idle,
  listening,
  recognizing,
  detectingLanguage,
  translating,
  speaking,
  completed,
  error,
}

/// Satu kartu percakapan (mirip Google Translate Conversation).
class ConversationCardItem {
  final String id;
  final LanguageModel sourceLanguage;
  final LanguageModel targetLanguage;
  final String sourceText;
  final String translatedText;
  final DateTime timestamp;
  final String speakerLabel;

  const ConversationCardItem({
    required this.id,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceText,
    required this.translatedText,
    required this.timestamp,
    required this.speakerLabel,
  });
}

class ConversationState {
  final LanguageModel sourceLanguage;
  final LanguageModel targetLanguage;
  final String speakerText;
  final String translatedText;
  final ConversationPhase phase;
  final bool isSpeakerDraft;
  final List<ConversationCardItem> cards;
  final bool twoWayMode;
  final String? errorMessage;
  final String? pendingRetryText;

  const ConversationState({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.speakerText,
    required this.translatedText,
    required this.phase,
    required this.isSpeakerDraft,
    required this.cards,
    required this.twoWayMode,
    this.errorMessage,
    this.pendingRetryText,
  });

  bool get isListening => phase == ConversationPhase.listening;
  bool get isTranslating =>
      phase == ConversationPhase.translating ||
      phase == ConversationPhase.detectingLanguage;
  bool get isSpeaking => phase == ConversationPhase.speaking;
  bool get hasError => phase == ConversationPhase.error;

  ConversationState copyWith({
    LanguageModel? sourceLanguage,
    LanguageModel? targetLanguage,
    String? speakerText,
    String? translatedText,
    ConversationPhase? phase,
    bool? isSpeakerDraft,
    List<ConversationCardItem>? cards,
    bool? twoWayMode,
    String? errorMessage,
    String? pendingRetryText,
    bool clearError = false,
    bool clearRetry = false,
  }) {
    return ConversationState(
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      speakerText: speakerText ?? this.speakerText,
      translatedText: translatedText ?? this.translatedText,
      phase: phase ?? this.phase,
      isSpeakerDraft: isSpeakerDraft ?? this.isSpeakerDraft,
      cards: cards ?? this.cards,
      twoWayMode: twoWayMode ?? this.twoWayMode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingRetryText:
          clearRetry ? null : (pendingRetryText ?? this.pendingRetryText),
    );
  }
}

class ConversationNotifier extends StateNotifier<ConversationState> {
  final Ref _ref;

  ConversationNotifier(this._ref)
      : super(ConversationState(
          sourceLanguage: _getLanguageFromSettings(
            _ref.read(settingsProvider).defaultSourceLang,
            fallbackCode: 'id',
          ),
          targetLanguage: _getLanguageFromSettings(
            _ref.read(settingsProvider).defaultTargetLang,
            fallbackCode: 'zh',
          ),
          speakerText: speakerPlaceholder,
          translatedText: translationPlaceholder,
          phase: ConversationPhase.idle,
          isSpeakerDraft: false,
          cards: const [],
          twoWayMode: true,
        ));

  static LanguageModel _getLanguageFromSettings(
    String name, {
    required String fallbackCode,
  }) {
    final nameLower = name.toLowerCase();
    if (nameLower == 'indonesian' || nameLower == 'indonesia') {
      return languageByCode('id');
    }
    if (nameLower == 'chinese' || name == '中文') {
      return languageByCode('zh');
    }
    for (final lang in languages) {
      if (lang.name.toLowerCase() == nameLower ||
          lang.nativeName.toLowerCase() == nameLower) {
        return lang;
      }
    }
    return languageByCode(fallbackCode);
  }

  final TranslationService _translator = TranslationService();
  final OfflineTranslationService _offlineTranslator =
      OfflineTranslationService();
  Timer? _translateDebounce;
  String? _lastTranslatedSource;

  static const speakerPlaceholder = 'Tap mic and start speaking to translate...';
  static const translationPlaceholder = 'Translation will appear here...';

  static const _skipTranslateTexts = {
    'Mendengarkan...',
    'Mulai berbicara...',
    'Silakan ulangi ucapan',
    speakerPlaceholder,
    translationPlaceholder,
  };

  static const _translateDebounceMs = 800;
  static const _homeLanguageCode = 'id';

  void toggleTwoWayMode() {
    state = state.copyWith(twoWayMode: !state.twoWayMode);
  }

  void setTwoWayMode(bool enabled) {
    state = state.copyWith(twoWayMode: enabled);
  }

  void swapLanguage() {
    state = state.copyWith(
      sourceLanguage: state.targetLanguage,
      targetLanguage: state.sourceLanguage,
      translatedText: translationPlaceholder,
    );
  }

  void reset() {
    state = state.copyWith(
      speakerText: speakerPlaceholder,
      translatedText: translationPlaceholder,
      isSpeakerDraft: false,
      phase: ConversationPhase.idle,
      clearError: true,
      clearRetry: true,
    );
  }

  void setSourceLanguage(LanguageModel language) {
    if (language == state.targetLanguage) {
      swapLanguage();
      return;
    }

    state = state.copyWith(
      sourceLanguage: language,
      speakerText: speakerPlaceholder,
      translatedText: translationPlaceholder,
      isSpeakerDraft: false,
    );
  }

  void setTargetLanguage(LanguageModel language) {
    if (language == state.sourceLanguage) {
      swapLanguage();
      return;
    }

    state = state.copyWith(
      targetLanguage: language,
      translatedText: translationPlaceholder,
    );

    final sourceText = state.speakerText.trim();
    if (sourceText.isNotEmpty && !_skipTranslateTexts.contains(sourceText)) {
      translate(text: sourceText, detectSource: true);
    }
  }

  void setSpeakerText(String text, {bool isDraft = false}) {
    state = state.copyWith(
      speakerText: text,
      isSpeakerDraft: isDraft,
    );
  }

  void setPhase(ConversationPhase phase) {
    state = state.copyWith(phase: phase);
  }

  void setSpeaking() {
    state = state.copyWith(phase: ConversationPhase.speaking);
  }

  void setCompleted() {
    state = state.copyWith(
      phase: ConversationPhase.completed,
      clearError: true,
      clearRetry: true,
    );
  }

  void setError(String message, {String? retryText}) {
    state = state.copyWith(
      phase: ConversationPhase.error,
      errorMessage: message,
      pendingRetryText: retryText,
    );
  }

  void clearError() {
    state = state.copyWith(
      phase: ConversationPhase.idle,
      clearError: true,
      clearRetry: true,
    );
  }

  void removeCard(String id) {
    state = state.copyWith(
      cards: state.cards.where((c) => c.id != id).toList(),
    );
  }

  void clearCards() {
    state = state.copyWith(cards: const []);
  }

  void scheduleTranslate(String text) {
    _translateDebounce?.cancel();
    _translateDebounce = Timer(
      const Duration(milliseconds: _translateDebounceMs),
      () => translate(text: text, detectSource: true),
    );
  }

  Future<void> retryLastTranslation() async {
    final text = state.pendingRetryText;
    if (text == null || text.trim().isEmpty) return;
    await translate(text: text, detectSource: true);
  }

  /// [detectSource] true = deteksi bahasa dari teks (STT/typing), bukan picker.
  Future<void> translate({String? text, bool detectSource = true}) async {
    _translateDebounce?.cancel();

    final raw = (text ?? state.speakerText).trim();
    if (raw.isEmpty || _skipTranslateTexts.contains(raw)) {
      return;
    }

    if (state.phase == ConversationPhase.listening) {
      _log('[Speech Recognition] skip translate — still listening');
      return;
    }

    state = state.copyWith(
      phase: ConversationPhase.detectingLanguage,
      clearError: true,
      pendingRetryText: raw,
    );

    // Auto-detect bahasa sumber dari teks final.
    var fromCode = state.sourceLanguage.code;
    if (detectSource) {
      fromCode = await _resolveSourceLanguage(raw);
      final detected = languageByCode(fromCode);
      if (detected.code != state.sourceLanguage.code) {
        state = state.copyWith(sourceLanguage: detected);
      }
    }

    final glossaryNormalized =
        IwipGlossaryProcessor.normalizeSource(raw, fromCode);
    final prepared = SpeechTextProcessor.postProcess(glossaryNormalized, fromCode);
    final sourceText = TranslationTextProcessor.prepare(prepared, fromCode);
    if (sourceText.isEmpty ||
        !TranslationTextProcessor.isSafeToTranslate(sourceText)) {
      _log('[Translation API] skip — invalid / unsafe source');
      setCompleted();
      return;
    }

    final toCode = _resolveTargetLanguage(fromCode);

    if (sourceText == _lastTranslatedSource &&
        state.translatedText.isNotEmpty &&
        state.translatedText != translationPlaceholder &&
        !state.translatedText.startsWith('Terjemahan')) {
      setCompleted();
      return;
    }

    // Bahasa sama → jangan translate.
    if (fromCode == toCode) {
      _lastTranslatedSource = sourceText;
      state = state.copyWith(
        speakerText: sourceText,
        translatedText: sourceText,
        isSpeakerDraft: false,
      );
      _pushCard(
        sourceText: sourceText,
        translatedText: sourceText,
        fromCode: fromCode,
        toCode: toCode,
      );
      setCompleted();
      return;
    }

    state = state.copyWith(phase: ConversationPhase.translating);
    _log(
      '[Translation API] detect=$fromCode → $toCode (${sourceText.length} chars)',
    );

    try {
      var translated = await _translateWithOfflineFallback(
        sourceText,
        from: fromCode,
        to: toCode,
      );

      translated = IwipGlossaryProcessor.applyToTranslation(
        source: sourceText,
        translated: translated,
        from: fromCode,
        to: toCode,
      );

      _lastTranslatedSource = sourceText;
      state = state.copyWith(
        speakerText: sourceText,
        translatedText: translated,
        isSpeakerDraft: false,
        targetLanguage: languageByCode(toCode),
      );

      _pushCard(
        sourceText: sourceText,
        translatedText: translated,
        fromCode: fromCode,
        toCode: toCode,
      );

      final settings = _ref.read(settingsProvider);
      if (settings.autoSaveHistory) {
        _ref.read(historyListProvider.notifier).addHistoryItem(
              sourceText,
              translated,
            );
      }

      setCompleted();
    } on TimeoutException catch (e) {
      _log('[Timeout] $e');
      setError('Terjemahan timeout. Silakan coba lagi.', retryText: sourceText);
      state = state.copyWith(
        translatedText: 'Terjemahan timeout. Silakan coba lagi.',
      );
    } on TranslationException catch (e) {
      _log('[Translation API] $e');
      setError(e.message, retryText: sourceText);
      state = state.copyWith(translatedText: e.message);
    } catch (e) {
      final msg = '$e';
      if (msg.toLowerCase().contains('socketexception') ||
          msg.toLowerCase().contains('failed host lookup')) {
        _log('[Network] $e');
        const networkMsg = 'Terjemahan gagal. Periksa koneksi internet.';
        setError(networkMsg, retryText: sourceText);
        state = state.copyWith(translatedText: networkMsg);
      } else {
        _log('[Translation API] unexpected: $e');
        const failMsg = 'Terjemahan gagal. Silakan coba lagi.';
        setError(failMsg, retryText: sourceText);
        state = state.copyWith(translatedText: failMsg);
      }
    }
  }

  String _resolveTargetLanguage(String fromCode) {
    if (!state.twoWayMode) return state.targetLanguage.code;

    final preferred = state.targetLanguage.code;
    if (fromCode == preferred) return _homeLanguageCode;
    if (fromCode == _homeLanguageCode) return preferred;
    // Bahasa lain (mis. Inggris) → terjemahkan ke bahasa tujuan yang dipilih.
    return preferred;
  }

  String _speakerLabel(String fromCode) {
    switch (fromCode) {
      case 'id':
        return '🇮🇩 Indonesia';
      case 'zh':
        return '🇨🇳 中文';
      case 'en':
        return '🇺🇸 English';
      default:
        return languageByCode(fromCode).nativeName;
    }
  }

  Future<String> _resolveSourceLanguage(String text) async {
    final local = LanguageDetector.detectLocal(text);
    if (local != null) return local;
    try {
      return await _translator.detectLanguage(text);
    } catch (_) {
      return state.sourceLanguage.code;
    }
  }

  void _pushCard({
    required String sourceText,
    required String translatedText,
    required String fromCode,
    required String toCode,
  }) {
    final card = ConversationCardItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourceLanguage: languageByCode(fromCode),
      targetLanguage: languageByCode(toCode),
      sourceText: sourceText,
      translatedText: translatedText,
      timestamp: DateTime.now(),
      speakerLabel: _speakerLabel(fromCode),
    );
    // Urutan kronologis — kartu baru di bawah (auto-scroll).
    state = state.copyWith(cards: [...state.cards, card]);
  }

  Future<String> _translateWithOfflineFallback(
    String sourceText, {
    required String from,
    required String to,
  }) async {
    try {
      return await _translator.translate(
        text: sourceText,
        from: from,
        to: to,
      );
    } catch (onlineError) {
      final offline = await _tryOfflineTranslate(sourceText, from, to);
      if (offline != null) return offline;
      if (from != 'auto') {
        try {
          return await _translator.translate(
            text: sourceText,
            from: 'auto',
            to: to,
          );
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<String?> _tryOfflineTranslate(
    String text,
    String from,
    String to,
  ) async {
    if (!_offlineTranslator.isLanguageSupported(from) ||
        !_offlineTranslator.isLanguageSupported(to)) {
      return null;
    }

    final fromReady = await _offlineTranslator.isModelDownloaded(from);
    final toReady = await _offlineTranslator.isModelDownloaded(to);
    if (!fromReady || !toReady) return null;

    return _offlineTranslator.translate(
      text: text,
      from: from,
      to: to,
    );
  }

  void startListening() {
    _lastTranslatedSource = null;
    state = state.copyWith(
      phase: ConversationPhase.listening,
      isSpeakerDraft: true,
      speakerText: 'Mendengarkan...',
      translatedText: translationPlaceholder,
      clearError: true,
    );
  }

  void stopListening() {
    state = state.copyWith(
      phase: ConversationPhase.recognizing,
      isSpeakerDraft: false,
    );
  }

  /// Batalkan sesi mic tanpa lanjut ke tahap recognizing (mis. gagal start).
  void abortListening() {
    state = state.copyWith(
      phase: ConversationPhase.idle,
      isSpeakerDraft: false,
      speakerText: speakerPlaceholder,
      translatedText: translationPlaceholder,
    );
  }

  @override
  void dispose() {
    _translateDebounce?.cancel();
    _offlineTranslator.dispose();
    super.dispose();
  }
}

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>(
  (ref) => ConversationNotifier(ref),
);
