import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/language_detector.dart';
import '../../../../core/services/offline_translation_service.dart';
import '../../../../core/services/speech_text_processor.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/services/translation_text_processor.dart';
import '../../language/data/language_model.dart';
import '../../history/providers/history_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/entities/interpreter_session_model.dart';

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

/// Job satu ucapan yang menunggu diproses dalam antrian.
///
/// Digunakan oleh mekanisme sequential queue agar tidak ada ucapan
/// yang hilang atau tumpang tindih selama sesi panjang (2–4 jam).
class _SpeechJob {
  final String text;
  final String detectedFromCode;

  const _SpeechJob({required this.text, required this.detectedFromCode});
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

  /// Session interpreter yang aktif. Null jika bukan mode interpreter.
  final InterpreterSessionModel? activeSession;

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
    this.activeSession,
  });

  bool get isListening => phase == ConversationPhase.listening;
  bool get isTranslating =>
      phase == ConversationPhase.translating ||
      phase == ConversationPhase.detectingLanguage;
  bool get isSpeaking => phase == ConversationPhase.speaking;
  bool get hasError => phase == ConversationPhase.error;

  /// True jika sedang berjalan dalam mode Auto Interpreter.
  bool get isInterpreterMode => activeSession != null;

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
    InterpreterSessionModel? activeSession,
    bool clearError = false,
    bool clearRetry = false,
    bool clearSession = false,
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
      activeSession:
          clearSession ? null : (activeSession ?? this.activeSession),
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

  // ── Sequential Speech Queue ───────────────────────────────────────────────
  // Antrian ini memastikan setiap ucapan diproses satu per satu:
  // STT → Detect → Translate → TTS → lanjut ke ucapan berikutnya.
  // Tidak ada ucapan yang hilang, tidak ada yang tumpang tindih.
  // Mendukung sesi panjang (2–4 jam) tanpa memory leak.
  final Queue<_SpeechJob> _speechQueue = Queue<_SpeechJob>();
  bool _isProcessingQueue = false;

  static const speakerPlaceholder =
      'Tap mic and start speaking to translate...';
  static const translationPlaceholder = 'Translation will appear here...';

  static const _skipTranslateTexts = {
    'Mendengarkan...',
    'Mulai berbicara...',
    'Silakan ulangi ucapan',
    speakerPlaceholder,
    translationPlaceholder,
  };

  // 1400ms memberikan waktu STT online menyelesaikan proses final recognition.
  // Terlalu pendek (800ms) menyebabkan translate dari partial result.
  static const _translateDebounceMs = 1400;

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

  // ── Session Management ────────────────────────────────────────────────────

  /// Mulai sesi Auto Interpreter dengan pasangan bahasa yang dikunci.
  ///
  /// Setelah dipanggil, [languageA] dan [languageB] tidak dapat diubah
  /// tanpa memanggil [endInterpreterSession].
  void startInterpreterSession(InterpreterSessionModel session) {
    _speechQueue.clear();
    _isProcessingQueue = false;
    _lastTranslatedSource = null;

    state = state.copyWith(
      activeSession: session,
      sourceLanguage: session.languageA,
      targetLanguage: session.languageB,
      speakerText: speakerPlaceholder,
      translatedText: translationPlaceholder,
      cards: const [],
      twoWayMode: true,
      phase: ConversationPhase.idle,
      clearError: true,
      clearRetry: true,
    );

    _log('[Interpreter] Sesi dimulai: ${session.displayLabel}');
  }

  /// Akhiri sesi interpreter dan kembalikan ke mode normal.
  void endInterpreterSession() {
    _speechQueue.clear();
    _isProcessingQueue = false;
    _lastTranslatedSource = null;

    state = state.copyWith(
      clearSession: true,
      speakerText: speakerPlaceholder,
      translatedText: translationPlaceholder,
      cards: const [],
      phase: ConversationPhase.idle,
      clearError: true,
      clearRetry: true,
    );

    _log('[Interpreter] Sesi diakhiri');
  }

  // ── Sequential Queue Processing ───────────────────────────────────────────

  /// Tambahkan ucapan baru ke antrian untuk diproses secara berurutan.
  ///
  /// Jika tidak ada job yang sedang berjalan, langsung mulai memproses.
  /// Jika ada job yang sedang berjalan, ucapan baru akan menunggu gilirannya.
  /// Tidak ada ucapan yang hilang, tidak ada yang tumpang tindih.
  void enqueueSpeechJob(String text, {required String detectedFromCode}) {
    final raw = text.trim();
    if (raw.isEmpty || _skipTranslateTexts.contains(raw)) return;

    _speechQueue.addLast(_SpeechJob(text: raw, detectedFromCode: detectedFromCode));
    _log('[Queue] Job ditambahkan. Antrian: ${_speechQueue.length}');

    if (!_isProcessingQueue) {
      _processNextJob();
    }
  }

  /// Proses satu job dari antrian.
  ///
  /// Setelah selesai (berhasil atau gagal dengan recovery), job berikutnya
  /// diproses secara rekursif. Dengan cara ini antrian berjalan tanpa
  /// memerlukan timer atau polling, dan tidak ada memory leak.
  Future<void> _processNextJob() async {
    if (_speechQueue.isEmpty) {
      _isProcessingQueue = false;
      return;
    }

    _isProcessingQueue = true;
    final job = _speechQueue.removeFirst();
    _log('[Queue] Memproses job: "${job.text.substring(0, job.text.length.clamp(0, 40))}..."');

    try {
      await _executeJob(job);
    } catch (e) {
      // Recovery: error apapun tidak menghentikan antrian.
      // Job berikutnya tetap akan diproses.
      _log('[Queue] Job gagal (recovery aktif): $e');
    } finally {
      // Jika ada job berikutnya, proses segera tanpa delay.
      if (_speechQueue.isNotEmpty) {
        // Gunakan Future.microtask agar tidak memblokir UI thread.
        Future.microtask(_processNextJob);
      } else {
        _isProcessingQueue = false;
      }
    }
  }

  /// Eksekusi satu speech job: translate + push card.
  ///
  /// TTS tidak dieksekusi di sini — TTS dipanggil oleh ConversationPage
  /// setelah menerima state `completed`, sehingga UI tetap mengontrol
  /// output audio dan sequential queue tidak perlu menunggu TTS selesai.
  Future<void> _executeJob(_SpeechJob job) async {
    if (!mounted) return;

    final session = state.activeSession;
    final fromCode = job.detectedFromCode;
    final toCode = session != null
        ? _resolveTargetLanguageForSession(fromCode, session)
        : _resolveTargetLanguage(fromCode);

    final prepared = SpeechTextProcessor.postProcess(job.text, fromCode);
    final sourceText = TranslationTextProcessor.prepare(prepared, fromCode);

    if (sourceText.isEmpty ||
        !TranslationTextProcessor.isSafeToTranslate(sourceText)) {
      _log('[Queue] Job dilewati — teks tidak aman: "$sourceText"');
      setCompleted();
      return;
    }

    // Cek duplikat — hindari terjemah ulang teks yang sama.
    if (sourceText == _lastTranslatedSource &&
        state.translatedText.isNotEmpty &&
        state.translatedText != translationPlaceholder &&
        !state.translatedText.startsWith('Terjemahan')) {
      setCompleted();
      return;
    }

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
    _log('[Queue] Terjemahkan: $fromCode → $toCode (${sourceText.length} chars)');

    try {
      final translated = await _translateWithOfflineFallback(
        sourceText,
        from: fromCode,
        to: toCode,
      );

      if (!mounted) return;

      _lastTranslatedSource = sourceText;
      state = state.copyWith(
        speakerText: sourceText,
        translatedText: translated,
        isSpeakerDraft: false,
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
      _log('[Queue] Timeout: $e');
      if (!mounted) return;
      const msg = 'Terjemahan timeout. Silakan coba lagi.';
      setError(msg, retryText: sourceText);
      state = state.copyWith(translatedText: msg);
    } on TranslationException catch (e) {
      _log('[Queue] Translation error: $e');
      if (!mounted) return;
      setError(e.message, retryText: sourceText);
      state = state.copyWith(translatedText: e.message);
    } catch (e) {
      if (!mounted) return;
      final msg = '$e';
      if (msg.toLowerCase().contains('socketexception') ||
          msg.toLowerCase().contains('failed host lookup')) {
        _log('[Queue] Network error: $e');
        const networkMsg = 'Terjemahan gagal. Periksa koneksi internet.';
        setError(networkMsg, retryText: sourceText);
        state = state.copyWith(translatedText: networkMsg);
      } else {
        _log('[Queue] Unexpected error: $e');
        const failMsg = 'Terjemahan gagal. Silakan coba lagi.';
        setError(failMsg, retryText: sourceText);
        state = state.copyWith(translatedText: failMsg);
      }
    }
  }

  // ── Legacy translate() — dipertahankan untuk backward compatibility ────────

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
  ///
  /// Di mode interpreter, ucapan sebaiknya dikirim via [enqueueSpeechJob]
  /// agar diproses secara berurutan. [translate] dipertahankan untuk:
  /// - Input teks manual (keyboard)
  /// - Retry dari error banner
  /// - Backward compatibility dengan mode non-interpreter
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
    }

    final prepared = SpeechTextProcessor.postProcess(raw, fromCode);
    final sourceText = TranslationTextProcessor.prepare(prepared, fromCode);
    if (sourceText.isEmpty ||
        !TranslationTextProcessor.isSafeToTranslate(sourceText)) {
      _log('[Translation API] skip — invalid / unsafe source');
      setCompleted();
      return;
    }

    final session = state.activeSession;
    final toCode = session != null
        ? _resolveTargetLanguageForSession(fromCode, session)
        : _resolveTargetLanguage(fromCode);

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

      _lastTranslatedSource = sourceText;
      state = state.copyWith(
        speakerText: sourceText,
        translatedText: translated,
        isSpeakerDraft: false,
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

  // ── Language Resolution ───────────────────────────────────────────────────

  /// Resolusi bahasa tujuan untuk mode interpreter.
  ///
  /// Logika: jika speaker bicara bahasa A → terjemahkan ke B, dan sebaliknya.
  /// Jika bahasa tidak dikenal dalam sesi, default ke bahasa B.
  /// Tidak ada hardcode 'id' — mendukung semua pasangan bahasa.
  String _resolveTargetLanguageForSession(
    String fromCode,
    InterpreterSessionModel session,
  ) {
    if (fromCode == session.languageA.code) return session.languageB.code;
    if (fromCode == session.languageB.code) return session.languageA.code;
    // Bahasa lain terdeteksi → default ke bahasa B (target utama sesi).
    return session.languageB.code;
  }

  /// Resolusi bahasa tujuan untuk mode normal (non-interpreter).
  ///
  /// Perilaku sama dengan implementasi asli — backward compatible.
  String _resolveTargetLanguage(String fromCode) {
    if (!state.twoWayMode) return state.targetLanguage.code;

    final preferred = state.targetLanguage.code;
    final source = state.sourceLanguage.code;
    if (fromCode == preferred) return source;
    if (fromCode == source) return preferred;
    // Bahasa lain → terjemahkan ke bahasa tujuan yang dipilih.
    return preferred;
  }

  String _speakerLabel(String fromCode) {
    final lang = languageByCode(fromCode);
    return '${lang.flag} ${lang.nativeName}';
  }

  Future<String> _resolveSourceLanguage(String text) async {
    final session = state.activeSession;

    // Mode interpreter: gunakan deteksi yang sadar sesi.
    if (session != null) {
      final local = LanguageDetector.detectForSession(
        text,
        langACode: session.languageA.code,
        langBCode: session.languageB.code,
        defaultCode: session.languageA.code,
      );
      if (local != null) return local;

      // Fallback ke API online.
      try {
        final detected = await _translator.detectLanguage(text);
        if (detected.isNotEmpty && detected != 'auto') {
          // Pastikan hasil API cocok dengan salah satu bahasa sesi.
          if (detected == session.languageA.code) return session.languageA.code;
          if (detected == session.languageB.code) return session.languageB.code;
          // Tidak cocok dengan sesi → default ke bahasa A.
          return session.languageA.code;
        }
      } catch (_) {}

      return session.languageA.code;
    }

    // Mode normal — logika asli dipertahankan.
    final current = state.sourceLanguage.code;
    final local = LanguageDetector.detectLocal(text);
    if (local != null) return local;

    try {
      final detected = await _translator.detectLanguage(text);
      if (detected.isNotEmpty && detected != 'auto') {
        return detected;
      }
    } catch (_) {}

    return current;
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
    // Bersihkan semua resource — penting untuk sesi panjang (2–4 jam).
    _translateDebounce?.cancel();
    _translateDebounce = null;
    _speechQueue.clear();
    _isProcessingQueue = false;
    _offlineTranslator.dispose();
    super.dispose();
  }
}

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>(
  (ref) => ConversationNotifier(ref),
);
