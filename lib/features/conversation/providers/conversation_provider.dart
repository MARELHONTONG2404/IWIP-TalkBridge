import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/offline_translation_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../language/data/language_model.dart';
import '../../history/providers/history_provider.dart';
import '../../settings/providers/settings_provider.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

class ConversationState {
  final LanguageModel sourceLanguage;
  final LanguageModel targetLanguage;
  final String speakerText;
  final String translatedText;
  final bool isListening;
  final bool isTranslating;
  final bool isSpeakerDraft;

  const ConversationState({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.speakerText,
    required this.translatedText,
    required this.isListening,
    required this.isTranslating,
    required this.isSpeakerDraft,
  });

  ConversationState copyWith({
    LanguageModel? sourceLanguage,
    LanguageModel? targetLanguage,
    String? speakerText,
    String? translatedText,
    bool? isListening,
    bool? isTranslating,
    bool? isSpeakerDraft,
  }) {
    return ConversationState(
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      speakerText: speakerText ?? this.speakerText,
      translatedText: translatedText ?? this.translatedText,
      isListening: isListening ?? this.isListening,
      isTranslating: isTranslating ?? this.isTranslating,
      isSpeakerDraft: isSpeakerDraft ?? this.isSpeakerDraft,
    );
  }
}

class ConversationNotifier extends StateNotifier<ConversationState> {
  final Ref _ref;

  ConversationNotifier(this._ref) : super(ConversationState(
    sourceLanguage: _getLanguageFromSettings(
      _ref.read(settingsProvider).defaultSourceLang,
      fallbackCode: 'id',
    ),
    targetLanguage: _getLanguageFromSettings(
      _ref.read(settingsProvider).defaultTargetLang,
      fallbackCode: 'en',
    ),
    speakerText: speakerPlaceholder,
    translatedText: translationPlaceholder,
    isListening: false,
    isTranslating: false,
    isSpeakerDraft: false,
  ));

  static LanguageModel _getLanguageFromSettings(String name, {required String fallbackCode}) {
    final nameLower = name.toLowerCase();
    for (final lang in languages) {
      if (lang.name.toLowerCase() == nameLower || lang.nativeName.toLowerCase() == nameLower) {
        return lang;
      }
    }
    if (name == '中文') {
      for (final lang in languages) {
        if (lang.code == 'zh') return lang;
      }
    }
    return languageByCode(fallbackCode);
  }

  final TranslationService _translator = TranslationService();
  final OfflineTranslationService _offlineTranslator =
      OfflineTranslationService();
  Timer? _translateDebounce;

  static const speakerPlaceholder = 'Tap mic and start speaking to translate...';
  static const translationPlaceholder = 'Translation will appear here...';

  static const _skipTranslateTexts = {
    'Mendengarkan...',
    'Mulai berbicara...',
    speakerPlaceholder,
    translationPlaceholder,
  };

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
      translate(sourceText);
    }
  }

  void setSpeakerText(String text, {bool isDraft = false}) {
    state = state.copyWith(
      speakerText: text,
      isSpeakerDraft: isDraft,
    );
  }

  void scheduleTranslate(String text) {
    _translateDebounce?.cancel();
    _translateDebounce = Timer(const Duration(milliseconds: 1000), () {
      translate(text);
    });
  }

  Future<void> translate([String? text]) async {
    _translateDebounce?.cancel();

    final sourceText = (text ?? state.speakerText).trim();

    if (sourceText.isEmpty || _skipTranslateTexts.contains(sourceText)) {
      return;
    }

    if (state.isListening) {
       _log('[Speech Recognition] skip translate — still listening');
      return;
    }

    if (state.sourceLanguage.code == state.targetLanguage.code) {
      state = state.copyWith(
        translatedText: sourceText,
        isSpeakerDraft: false,
      );
      return;
    }

    startTranslating();
     _log(
      '[Translation API] start (${sourceText.length} chars)',
    );

    try {
      final translated = await _translateWithOfflineFallback(sourceText);

      state = state.copyWith(
        translatedText: translated,
        isSpeakerDraft: false,
      );

      // Save to history if enabled in settings
      final settings = _ref.read(settingsProvider);
      if (settings.autoSaveHistory) {
        _ref.read(historyListProvider.notifier).addHistoryItem(
              sourceText,
              translated,
            );
      }
    } on TimeoutException catch (e) {
       _log('[Timeout] $e');
      state = state.copyWith(
        translatedText: 'Terjemahan timeout. Silakan coba lagi.',
      );
    } on TranslationException catch (e) {
       _log('[Translation API] $e');
      state = state.copyWith(
        translatedText: e.message,
      );
    } catch (e) {
      final msg = '$e';
      if (msg.toLowerCase().contains('socketexception') ||
          msg.toLowerCase().contains('failed host lookup')) {
         _log('[Network] $e');
        state = state.copyWith(
          translatedText: 'Terjemahan gagal. Periksa koneksi internet.',
        );
      } else {
         _log('[Translation API] unexpected: $e');
        state = state.copyWith(
          translatedText: 'Terjemahan gagal. Silakan coba lagi.',
        );
      }
    }

    stopTranslating();
  }

  Future<String> _translateWithOfflineFallback(String sourceText) async {
    final from = state.sourceLanguage.code;
    final to = state.targetLanguage.code;

    try {
      return await _translator.translate(
        text: sourceText,
        from: from,
        to: to,
      );
    } catch (onlineError) {
      final offline = await _tryOfflineTranslate(sourceText, from, to);
      if (offline != null) return offline;
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
    state = state.copyWith(
      isListening: true,
      isSpeakerDraft: true,
    );
  }

  void stopListening() {
    state = state.copyWith(
      isListening: false,
      isSpeakerDraft: false,
    );
  }

  void startTranslating() {
    state = state.copyWith(isTranslating: true);
  }

  void stopTranslating() {
    state = state.copyWith(isTranslating: false);
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
