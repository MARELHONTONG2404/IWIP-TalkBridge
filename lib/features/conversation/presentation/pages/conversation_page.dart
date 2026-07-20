import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/app_colors.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/services/speech_text_processor.dart';
import '../../../../core/services/tts_service.dart';
import '../../providers/conversation_provider.dart';
import '../../../language/data/language_model.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../favorite/providers/favorite_provider.dart';

import '../widgets/language_selector.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();
  final ScrollController _scrollController = ScrollController();

  bool _speechReady = false;
  bool _initializing = true;
  double _soundLevel = 0;
  String _committedText = '';
  String _livePartial = '';
  bool _finalizingSpeech = false;
  bool _manualSessionActive = false;
  bool _userRequestedStop = false;
  double? _lastSpeechConfidence;
  bool _lowVolumeWarned = false;
  bool _earTipShown = false;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _ttsService.setHandlers(
      onStart: () {
        if (!mounted) return;
        ref.read(conversationProvider.notifier).setSpeaking();
        _showEarTipOnce();
      },
      onComplete: () {
        if (!mounted) return;
        ref.read(conversationProvider.notifier).setCompleted();
      },
      onError: (message) {
        if (!mounted) return;
        _log('[TTS] $message');
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
    }

  Future<void> _initializeSpeech() async {
    setState(() => _initializing = true);

    final ready = await _speechService.initialize(
      onError: (message) {
        if (!mounted) return;

        // Retry locale internal — bukan error fatal, abaikan.
        if (message.contains('Mencoba mode lain')) return;

        // Mic masih aktif = engine sedang recovery, jangan ganggu sesi.
        if (_manualSessionActive &&
            (_speechService.isListening || _speechService.isRetryingLocale)) {
          _log('[Speech Recognition] recoverable: $message');
          return;
        }

        ref.read(conversationProvider.notifier).abortListening();
        ref.read(conversationProvider.notifier).setError(
              message,
              retryText: _committedText.trim().isNotEmpty
                  ? _committedText.trim()
                  : _livePartial.trim(),
            );
        _manualSessionActive = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Coba Lagi',
              onPressed: _startListening,
            ),
          ),
        );
      },
      onStatus: (status) {
        if (!mounted) return;

        _log('[Speech Recognition] status=$status');

        if (status == 'listening') {
          if (mounted) setState(() {});
        } else if (status == 'doneNoResult') {
          if (_manualSessionActive && !_userRequestedStop) {
            _continueManualSession();
            return;
          }
          ref.read(conversationProvider.notifier).stopListening();
          _manualSessionActive = false;
          _showMessage(
            'Suara tidak terdeteksi. Bicara lebih jelas, pastikan internet aktif, '
            'atau unduh paket bahasa di Google app → Voice.',
          );
        } else if (status == 'notListening' || status == 'done') {
          if (_manualSessionActive && !_userRequestedStop) {
            _continueManualSession();
            return;
          }
          if (_userRequestedStop) {
            _finalizeSpeechAndTranslate();
          }
        }
      },
    );

    if (!mounted) return;

    setState(() {
      _speechReady = ready;
      _initializing = false;
    });

    if (!ready) {
      _showMessage(_micHelpMessage(_speechService.lastError));
    }
  }

  Future<void> _continueManualSession() async {
    if (!_manualSessionActive || _userRequestedStop) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || !_manualSessionActive || _userRequestedStop) return;
    if (_speechService.isListening) return;

    final ok = await _speechService.continueManualListening();
    if (!mounted) return;
    if (!ok) {
      _log('[Speech Recognition] continue failed — wait Stop');
    }
  }

  String _micHelpMessage(String? error) {
    if (error != null && error.isNotEmpty) return error;

    if (_isMobile) {
      return 'Mikrofon tidak tersedia. Izinkan Microphone untuk app ilb '
          'dan Google app.';
    }

    return 'Mikrofon tidak tersedia. Cek izin mic di pengaturan perangkat.';
  }

  void _showMessage(String message, {VoidCallback? action, String? actionLabel}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: action != null && actionLabel != null
            ? SnackBarAction(label: actionLabel, onPressed: action)
            : null,
      ),
    );
  }

  void _showEarTipOnce() {
    if (_earTipShown) return;
    _earTipShown = true;
    _showMessage(
      'Dekatkan ponsel ke telinga untuk mendengar hasil terjemahan.',
    );
  }

  void _checkLowVolume() {
    if (_lowVolumeWarned || !mounted) return;
    if (_soundLevel > 0 && _soundLevel < 0.8) {
      _lowVolumeWarned = true;
      _showMessage('Volume terlalu rendah. Bicara lebih dekat ke mikrofon.');
    }
  }

  void _onSpeechResult(
    String text, {
    required bool isFinal,
    double confidence = 0,
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final notifier = ref.read(conversationProvider.notifier);

      if (isFinal) {
        if (confidence > 0) {
          _lastSpeechConfidence = confidence;
        }
        _committedText = SpeechTextProcessor.mergeSession(_committedText, text);
        _livePartial = '';
        notifier.setSpeakerText(_committedText, isDraft: true);
        _log(
          '[Speech Recognition] final (${_committedText.length} chars) '
          'conf=${confidence.toStringAsFixed(2)}',
        );
      } else {
        _livePartial = text;
        final preview = SpeechTextProcessor.mergeSession(
          _committedText,
          _livePartial,
        );
        notifier.setSpeakerText(preview, isDraft: true);
      }
      _checkLowVolume();
    });
  }

  void _onSoundLevel(double level) {
    if (!mounted) return;
    setState(() => _soundLevel = level);
    _checkLowVolume();
  }

  Future<void> _startListening() async {
    if (_initializing) {
      _showMessage('Menyiapkan mikrofon...');
      return;
    }

    if (!_speechReady) {
      await _initializeSpeech();
      if (!_speechReady) {
        _showMessage(
          _micHelpMessage(_speechService.lastError),
          actionLabel: 'Coba Lagi',
          action: _startListening,
        );
        return;
      }
    }

    if (_speechService.isListening || _manualSessionActive) return;

    final notifier = ref.read(conversationProvider.notifier);

    setState(() {
      _soundLevel = 0;
      _committedText = '';
      _livePartial = '';
      _lastSpeechConfidence = null;
      _userRequestedStop = false;
      _manualSessionActive = true;
      _lowVolumeWarned = false;
    });

    notifier.startListening();
    setState(() {});

    final started = await _speechService.startListening(
      localeId: 'id-ID',
      languageCode: 'auto',
      onResult: _onSpeechResult,
      onSoundLevel: _onSoundLevel,
      autoDetectLanguage: true,
      manualControl: true,
    );

    if (!mounted) return;

    if (!started) {
      _manualSessionActive = false;
      _userRequestedStop = false;
      final msg = _micHelpMessage(_speechService.lastError);
      notifier.abortListening();
      notifier.setError(msg);
      setState(() {});

      final blocked = msg.toLowerCase().contains('diblokir') ||
          msg.toLowerCase().contains('ditolak');
      _showMessage(
        msg,
        actionLabel: blocked ? 'Buka Settings' : 'Coba Lagi',
        action: blocked ? openAppSettings : _startListening,
      );
    } else {
      setState(() {});
    }
  }

  Future<void> _stopListening() async {
    if (!_manualSessionActive && !_speechService.isListening) return;

    _userRequestedStop = true;
    _manualSessionActive = false;
    ref.read(conversationProvider.notifier).stopListening();
    await _speechService.stopListening();
    await _finalizeSpeechAndTranslate();
  }

  Future<void> _finalizeSpeechAndTranslate() async {
    if (_finalizingSpeech) return;
    _finalizingSpeech = true;

    try {
      final notifier = ref.read(conversationProvider.notifier);

      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      var finalText = _committedText.trim().isNotEmpty
          ? _committedText.trim()
          : _livePartial.trim();

      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      final settled = _committedText.trim().isNotEmpty
          ? _committedText.trim()
          : _livePartial.trim();
      if (settled.length >= finalText.length) {
        finalText = settled;
      }

      if (!mounted) return;
      setState(() {
        _soundLevel = 0;
        _manualSessionActive = false;
      });

      if (finalText.isEmpty ||
          finalText == 'Mendengarkan...' ||
          finalText == ConversationNotifier.speakerPlaceholder) {
        _log('[Speech Recognition] done with empty text — skip translate');
        notifier.setCompleted();
        return;
      }

      final conf = _lastSpeechConfidence;
      if (conf != null && conf > 0 && conf < 0.45) {
        notifier.setSpeakerText(finalText, isDraft: false);
        notifier.setError('Silakan ulangi ucapan', retryText: finalText);
        _showMessage('Silakan ulangi ucapan');
        _log('[Speech Recognition] low confidence=$conf — skip translate');
        return;
      }

      notifier.setSpeakerText(finalText, isDraft: false);
      _log(
        '[Speech Recognition] done (${finalText.length} chars) → detect+translate',
      );

      await notifier.translate(text: finalText, detectSource: true);

      if (!mounted) return;
      final state = ref.read(conversationProvider);
      final translatedText = state.translatedText;
      final looksLikeError = translatedText.startsWith('Terjemahan timeout') ||
          translatedText.startsWith('Terjemahan gagal') ||
          translatedText.startsWith('Limit terjemahan');
      if (translatedText.isNotEmpty &&
          translatedText != ConversationNotifier.translationPlaceholder &&
          !looksLikeError &&
          ref.read(settingsProvider).autoPlayTranslation) {
        _scrollToBottom();
        await _speakTranslation(translatedText, state.targetLanguage);
      }
    } finally {
      _finalizingSpeech = false;
      _userRequestedStop = false;
    }
  }

  bool _isPlaceholder(String text) {
    return text == ConversationNotifier.speakerPlaceholder ||
        text == ConversationNotifier.translationPlaceholder ||
        text == 'Mendengarkan...';
  }

  Future<void> _speakTranslation(
    String text,
    LanguageModel language, {
    bool notifyOnError = false,
  }) async {
    await _ttsService.speak(
      text,
      languageCode: language.code,
      speechCode: language.speechCode,
      notifyOnError: notifyOnError,
    );
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showMessage('Disalin');
  }

  void _shareCard(ConversationCardItem card) {
    final time = DateFormat('dd/MM/yyyy HH:mm').format(card.timestamp);
    final payload =
        '[${card.speakerLabel}] $time\n'
        '${card.sourceLanguage.nativeName}: ${card.sourceText}\n'
        '${card.targetLanguage.nativeName}: ${card.translatedText}';
    Clipboard.setData(ClipboardData(text: payload));
    _showMessage('Teks siap dibagikan (disalin)');
  }

  String _phaseLabel(ConversationPhase phase, String lang) {
    switch (phase) {
      case ConversationPhase.listening:
        return lang == 'Indonesia'
            ? 'Mendengarkan...'
            : (lang == '中文' ? '正在听...' : 'Listening...');
      case ConversationPhase.recognizing:
        return lang == 'Indonesia'
            ? 'Mengenali suara...'
            : (lang == '中文' ? '识别中...' : 'Recognizing...');
      case ConversationPhase.detectingLanguage:
        return lang == 'Indonesia'
            ? 'Mendeteksi bahasa...'
            : (lang == '中文' ? '检测语言...' : 'Detecting language...');
      case ConversationPhase.translating:
        return lang == 'Indonesia'
            ? 'Menerjemahkan...'
            : (lang == '中文' ? '翻译中...' : 'Translating...');
      case ConversationPhase.speaking:
        return lang == 'Indonesia'
            ? 'Membacakan...'
            : (lang == '中文' ? '朗读中...' : 'Speaking...');
      case ConversationPhase.completed:
        return lang == 'Indonesia'
            ? 'Selesai'
            : (lang == '中文' ? '完成' : 'Done');
      case ConversationPhase.error:
        return lang == 'Indonesia'
            ? 'Terjadi kesalahan'
            : (lang == '中文' ? '出错' : 'Error');
      case ConversationPhase.idle:
        return lang == 'Indonesia'
            ? 'Siap'
            : (lang == '中文' ? '就绪' : 'Ready');
    }
  }

  void _showTextInputDialog() {
    final controller = TextEditingController(
      text: _isPlaceholder(ref.read(conversationProvider).speakerText)
          ? ''
          : ref.read(conversationProvider).speakerText,
    );
    showDialog(
      context: context,
      builder: (context) {
        final settings = ref.read(settingsProvider);
        final lang = settings.appLanguage;
        final title = lang == 'Indonesia'
            ? 'Ketik Teks'
            : (lang == '中文' ? '输入文本' : 'Type Text');
        final hint = lang == 'Indonesia'
            ? 'Masukkan teks untuk diterjemahkan...'
            : (lang == '中文' ? '输入要翻译的文本...' : 'Enter text to translate...');

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                lang == 'Indonesia'
                    ? 'Batal'
                    : (lang == '中文' ? '取消' : 'Cancel'),
              ),
            ),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim();
                Navigator.pop(context);
                if (text.isEmpty) return;

                final notifier = ref.read(conversationProvider.notifier);
                notifier.setSpeakerText(text, isDraft: false);
                await notifier.translate(text: text, detectSource: true);
                if (!mounted) return;

                final translatedText =
                    ref.read(conversationProvider).translatedText;
                final looksLikeError =
                    translatedText.startsWith('Terjemahan timeout') ||
                        translatedText.startsWith('Terjemahan gagal') ||
                        translatedText.startsWith('Limit terjemahan');
                if (translatedText.isNotEmpty &&
                    translatedText !=
                        ConversationNotifier.translationPlaceholder &&
                    !looksLikeError) {
                  _scrollToBottom();
                  await _speakTranslation(
                    translatedText,
                    ref.read(conversationProvider).targetLanguage,
                  );
                }
              },
              child: Text(
                lang == 'Indonesia'
                    ? 'Terjemahkan'
                    : (lang == '中文' ? '翻译' : 'Translate'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationProvider);
    final settings = ref.watch(settingsProvider);
    final isListening = state.isListening || _manualSessionActive;
    final lang = settings.appLanguage;

    // Auto-scroll saat kartu baru ditambahkan.
    ref.listen(conversationProvider.select((s) => s.cards.length), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) _scrollToBottom();
    });

    return Theme(
      data: Theme.of(context).copyWith(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.translateBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accentBlue,
          brightness: Brightness.dark,
          surface: AppColors.card,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.translateBg,
        body: SafeArea(
          child: Column(
            children: [
              _TranslateHeader(
                lang: lang,
                detectedSource: state.sourceLanguage,
                targetLanguage: state.targetLanguage,
                onTargetChanged: (language) => ref
                    .read(conversationProvider.notifier)
                    .setTargetLanguage(language),
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                onType: _showTextInputDialog,
                onCamera: () => context.push('/camera'),
                onFavorites: () => context.push('/favorite'),
                onClear: state.cards.isNotEmpty
                    ? () => ref.read(conversationProvider.notifier).clearCards()
                    : null,
              ),

              if (state.hasError && state.errorMessage != null)
                _ErrorBanner(
                  message: state.errorMessage!,
                  onRetry: () async {
                    await ref
                        .read(conversationProvider.notifier)
                        .retryLastTranslation();
                    if (!mounted) return;
                    final translated =
                        ref.read(conversationProvider).translatedText;
                    if (translated.isNotEmpty &&
                        !translated.startsWith('Terjemahan')) {
                      _scrollToBottom();
                      await _speakTranslation(
                        translated,
                        ref.read(conversationProvider).targetLanguage,
                      );
                    }
                  },
                  onDismiss: () =>
                      ref.read(conversationProvider.notifier).clearError(),
                ),

              Expanded(
                child: state.cards.isEmpty && !isListening
                    ? _EmptyState(
                        lang: lang,
                        onType: _showTextInputDialog,
                      )
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        children: [
                          ...state.cards.map((card) {
                            final isFav = ref
                                .watch(favoriteProvider.notifier)
                                .isFavorite(
                                  card.sourceText,
                                  card.translatedText,
                                );
                            return _ConversationResultCard(
                              card: card,
                              isFavorite: isFav,
                              onSpeak: () => _speakTranslation(
                                card.translatedText,
                                card.targetLanguage,
                              ),
                              onCopy: () => _copyText(card.translatedText),
                              onCopySource: () => _copyText(card.sourceText),
                              onShare: () => _shareCard(card),
                              onFavorite: () => ref
                                  .read(favoriteProvider.notifier)
                                  .toggleFavorite(
                                    sourceLang: card.sourceLanguage.name,
                                    targetLang: card.targetLanguage.name,
                                    originalText: card.sourceText,
                                    translatedText: card.translatedText,
                                  ),
                              onDelete: () => ref
                                  .read(conversationProvider.notifier)
                                  .removeCard(card.id),
                            );
                          }),
                          if (isListening || state.isSpeakerDraft)
                            _LivePreviewCard(
                              text: state.speakerText,
                              isListening: isListening,
                            ),
                          if (state.isTranslating)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accentBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _phaseLabel(state.phase, lang),
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),

              _BottomControls(
                lang: lang,
                isListening: isListening,
                isInitializing: _initializing,
                soundLevel: _soundLevel,
                phaseLabel: _phaseLabel(state.phase, lang),
                lowVolume: _lowVolumeWarned && isListening,
                onListen: _startListening,
                onStop: _stopListening,
                onCancel: () async {
                  _userRequestedStop = true;
                  _manualSessionActive = false;
                  await _speechService.stopListening();
                  ref.read(conversationProvider.notifier).abortListening();
                  setState(() {
                    _soundLevel = 0;
                    _committedText = '';
                    _livePartial = '';
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _TranslateHeader extends StatelessWidget {
  const _TranslateHeader({
    required this.lang,
    required this.detectedSource,
    required this.targetLanguage,
    required this.onTargetChanged,
    required this.onBack,
    required this.onType,
    required this.onCamera,
    required this.onFavorites,
    this.onClear,
  });

  final String lang;
  final LanguageModel detectedSource;
  final LanguageModel targetLanguage;
  final ValueChanged<LanguageModel> onTargetChanged;
  final VoidCallback onBack;
  final VoidCallback onType;
  final VoidCallback onCamera;
  final VoidCallback onFavorites;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.translateBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: onBack,
              tooltip: 'Kembali',
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CompactHeaderLanguageBar(
                  detectedSource: detectedSource,
                  targetLanguage: targetLanguage,
                  onTargetChanged: onTargetChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textPrimary,
              ),
              color: AppColors.cardElevated,
              onSelected: (value) {
                switch (value) {
                  case 'type': onType();
                  case 'camera': onCamera();
                  case 'favorite': onFavorites();
                  case 'clear': onClear?.call();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'type',
                  child: Text(lang == 'Indonesia' ? 'Ketik teks' : 'Type text'),
                ),
                PopupMenuItem(
                  value: 'camera',
                  child: Text(lang == 'Indonesia' ? 'Kamera' : 'Camera'),
                ),
                PopupMenuItem(
                  value: 'favorite',
                  child: Text(lang == 'Indonesia' ? 'Favorit' : 'Favorites'),
                ),
                if (onClear != null)
                  PopupMenuItem(
                    value: 'clear',
                    child: Text(
                      lang == 'Indonesia' ? 'Hapus riwayat' : 'Clear history',
                      style: const TextStyle(color: AppColors.accentRed),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.accentRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Coba Lagi',
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textMuted,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
class _EmptyState extends StatelessWidget {
  final String lang;
  final VoidCallback onType;

  const _EmptyState({
    required this.lang,
    required this.onType,
  });

  @override
  Widget build(BuildContext context) {
    final hint = lang == 'Indonesia'
        ? 'Tekan Mendengarkan, bicara, lalu tekan jeda merah.\nBahasa akan terdeteksi otomatis.'
        : (lang == '中文'
              ? '点击聆听，说话，然后按红色暂停。\n语言将自动检测。'
              : 'Tap Listen, speak, then tap the red pause.\nLanguage is auto-detected.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 42,
                color: AppColors.accentBlue.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
              fontSize: 16,
                height: 1.55,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onType,
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(lang == 'Indonesia' ? 'Ketik teks' : 'Type text'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePreviewCard extends StatelessWidget {
  final String text;
  final bool isListening;

  const _LivePreviewCard({
    required this.text,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isListening ? 'Mendengarkan...' : 'Preview',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text.isEmpty ? '...' : text,
            style: TextStyle(
              fontSize: 24,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withValues(
                alpha: isListening ? 0.85 : 1,
              ),
              fontStyle: isListening ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
class _ConversationResultCard extends StatefulWidget {
  const _ConversationResultCard({
    required this.card,
    required this.isFavorite,
    required this.onSpeak,
    required this.onCopy,
    required this.onCopySource,
    required this.onShare,
    required this.onFavorite,
    required this.onDelete,
  });

  final ConversationCardItem card;
  final bool isFavorite;
  final VoidCallback onSpeak;
  final VoidCallback onCopy;
  final VoidCallback onCopySource;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  State<_ConversationResultCard> createState() =>
      _ConversationResultCardState();
}

class _ConversationResultCardState extends State<_ConversationResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final pairLabel =
        '${card.sourceLanguage.nativeName} → ${card.targetLanguage.nativeName}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pairLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.25,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                tooltip: 'Dengarkan terjemahan',
                onPressed: widget.onSpeak,
                icon: const Icon(
                  Icons.volume_up_rounded,
                  size: 20,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textMuted,
                ),
                color: AppColors.cardElevated,
                onSelected: (value) {
                  switch (value) {
                    case 'expand':
                      setState(() => _expanded = !_expanded);
                    case 'favorite':
                      widget.onFavorite();
                    case 'copy':
                      widget.onCopy();
                    case 'copy_source':
                      widget.onCopySource();
                    case 'share':
                      widget.onShare();
                    case 'delete':
                      widget.onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'expand',
                    child: Text(
                      _expanded ? 'Sembunyikan asli' : 'Tampilkan asli',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(
                      widget.isFavorite ? 'Hapus favorit' : 'Favorit',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Text(
                      'Salin terjemahan',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_source',
                    child: Text(
                      'Salin teks asli',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Text(
                      'Bagikan',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Hapus',
                      style: TextStyle(color: AppColors.accentRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_expanded) ...[
            Text(
              card.sourceText,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(
                height: 1,
                color: AppColors.divider,
              ),
            ),
          ],
          Text(
            card.translatedText,
            style: const TextStyle(
              fontSize: 20,
              height: 1.28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.lang,
    required this.isListening,
    required this.isInitializing,
    required this.soundLevel,
    required this.phaseLabel,
    required this.lowVolume,
    required this.onListen,
    required this.onStop,
    required this.onCancel,
  });

  final String lang;
  final bool isListening;
  final bool isInitializing;
  final double soundLevel;
  final String phaseLabel;
  final bool lowVolume;
  final VoidCallback onListen;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.translateBg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isListening) ...[
            _AudioGlowBar(level: soundLevel),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  lowVolume ? Icons.volume_off_rounded : Icons.graphic_eq_rounded,
                  size: 14,
                  color: lowVolume
                      ? AppColors.accentRed
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  lowVolume
                      ? (lang == 'Indonesia' ? 'Volume rendah' : 'Low volume')
                      : phaseLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: lowVolume
                        ? AppColors.accentRed
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: Material(
                  color: isListening
                      ? AppColors.cardElevated
                      : AppColors.pillBg,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: isListening ? null : onListen,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isListening
                                ? Icons.hearing_rounded
                                : Icons.mic_none_rounded,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isListening
                                ? (lang == 'Indonesia'
                                      ? 'Mendengarkan'
                                      : 'Listening')
                                : (lang == 'Indonesia' ? 'Mendengarkan' : 'Listen'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: AppColors.accentRed,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: isListening ? onStop : onListen,
                  onLongPress: isListening ? onCancel : null,
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Icon(
                      isListening ? Icons.pause_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _AudioGlowBar extends StatelessWidget {
  const _AudioGlowBar({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final intensity = (level / 10).clamp(0.15, 1.0);
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: LinearGradient(
          colors: [
            Color.lerp(const Color(0xFF00E5FF), Colors.white, intensity * 0.3)!,
            Color.lerp(const Color(0xFFE040FB), Colors.white, intensity * 0.2)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.35 * intensity),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
