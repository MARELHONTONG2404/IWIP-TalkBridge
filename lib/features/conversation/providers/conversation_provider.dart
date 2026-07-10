import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/translation_service.dart';
import '../../language/data/language_model.dart';

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
  ConversationNotifier() : super(_initialState);

  final TranslationService _translator = TranslationService();
  Timer? _translateDebounce;

  static const speakerPlaceholder = 'Tap mic and start speaking to translate...';
  static const translationPlaceholder = 'Translation will appear here...';

  static const _skipTranslateTexts = {
    'Mendengarkan...',
    'Mulai berbicara...',
    speakerPlaceholder,
    translationPlaceholder,
  };

  static final ConversationState _initialState = ConversationState(
    sourceLanguage: languages.first,
    targetLanguage: languages[1],
    speakerText: speakerPlaceholder,
    translatedText: translationPlaceholder,
    isListening: false,
    isTranslating: false,
    isSpeakerDraft: false,
  );

  void swapLanguage() {
    state = state.copyWith(
      sourceLanguage: state.targetLanguage,
      targetLanguage: state.sourceLanguage,
      translatedText: translationPlaceholder,
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
    _translateDebounce = Timer(const Duration(milliseconds: 700), () {
      translate(text);
    });
  }

  Future<void> translate([String? text]) async {
    _translateDebounce?.cancel();

    final sourceText = (text ?? state.speakerText).trim();

    if (sourceText.isEmpty || _skipTranslateTexts.contains(sourceText)) {
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

    try {
      final translated = await _translator.translate(
        text: sourceText,
        from: state.sourceLanguage.code,
        to: state.targetLanguage.code,
      );

      state = state.copyWith(
        translatedText: translated,
        isSpeakerDraft: false,
      );
    } on TranslationException catch (e) {
      state = state.copyWith(
        translatedText: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        translatedText: 'Terjemahan gagal. Cek koneksi internet.',
      );
    }

    stopTranslating();
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
    super.dispose();
  }
}

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>(
  (ref) => ConversationNotifier(),
);
