import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/speech_service.dart';
import '../../../../core/services/speech_text_processor.dart';
import '../../../../core/services/tts_service.dart';
import '../../providers/conversation_provider.dart';
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

        ref.read(conversationProvider.notifier).stopListening();
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
          _micHelpMessage(_speechService.lastError) ??
              'Mikrofon tidak siap. Pastikan Google app terpasang di HP.',
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
      final msg = _micHelpMessage(_speechService.lastError) ?? 'Mic gagal';
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
          !looksLikeError) {
        _scrollToBottom();
        await _ttsService.speak(
          translatedText,
          languageCode: state.targetLanguage.code,
        );
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
                  await _ttsService.speak(
                    translatedText,
                    languageCode:
                        ref.read(conversationProvider).targetLanguage.code,
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
    final micActive = _soundLevel > 0.3;
    final isListening = state.isListening || _manualSessionActive;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final panelColor = colors.surface;
    final textColor = colors.onSurface;
    final mutedTextColor = colors.onSurfaceVariant;
    final lang = settings.appLanguage;
    final title = lang == 'Indonesia'
        ? 'Percakapan'
        : (lang == '中文' ? '对话' : 'Conversation');
    final cameraLabel = lang == 'Indonesia'
        ? 'Kamera'
        : (lang == '中文' ? '相机' : 'Camera');

    // Auto-scroll saat kartu baru ditambahkan.
    ref.listen(conversationProvider.select((s) => s.cards.length), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: panelColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
        ),
        centerTitle: true,
        actions: [
          if (state.cards.isNotEmpty)
            IconButton(
              tooltip: lang == 'Indonesia' ? 'Hapus riwayat' : 'Clear',
              onPressed: () {
                ref.read(conversationProvider.notifier).clearCards();
              },
              icon: Icon(Icons.delete_sweep_outlined, color: mutedTextColor),
            ),
          IconButton(
            tooltip: lang == 'Indonesia' ? 'Favorit' : 'Favorites',
            onPressed: () => context.push('/favorite'),
            icon: Icon(Icons.star_border_rounded, color: textColor),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            _StatusBar(
              phase: state.phase,
              label: _phaseLabel(state.phase, lang),
              colors: colors,
              isListening: isListening,
              soundLevel: _soundLevel,
            ),

            // Error banner
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
                    await _ttsService.speak(
                      translated,
                      languageCode:
                          ref.read(conversationProvider).targetLanguage.code,
                    );
                  }
                },
                onDismiss: () =>
                    ref.read(conversationProvider.notifier).clearError(),
              ),

            // Conversation cards + live preview
            Expanded(
              child: Container(
                width: double.infinity,
                color: panelColor,
                child: state.cards.isEmpty && !isListening
                    ? _EmptyState(
                        lang: lang,
                        mutedTextColor: mutedTextColor,
                        onType: _showTextInputDialog,
                      )
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                              mutedTextColor: mutedTextColor,
                              textColor: textColor,
                              isFavorite: isFav,
                              onSpeak: () => _ttsService.speak(
                                card.translatedText,
                                languageCode: card.targetLanguage.code,
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
                              soundLevel: _soundLevel,
                              mutedTextColor: mutedTextColor,
                              textColor: textColor,
                            ),
                          if (state.isTranslating)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _phaseLabel(state.phase, lang),
                                      style: TextStyle(color: mutedTextColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),

            // Target language selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TargetLanguageSelector(
                detectedSource: state.sourceLanguage,
                targetLanguage: state.targetLanguage,
                twoWayMode: state.twoWayMode,
                onTargetChanged: (language) => ref
                    .read(conversationProvider.notifier)
                    .setTargetLanguage(language),
                onTwoWayChanged: (v) => ref
                    .read(conversationProvider.notifier)
                    .setTwoWayMode(v),
              ),
            ),

            // Control buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ActionButton(
                    icon: Icons.edit_note_rounded,
                    label: lang == 'Indonesia' ? 'Ketik' : 'Type',
                    onTap: _showTextInputDialog,
                  ),
                  if (isListening)
                    _ActionButton(
                      icon: Icons.check_circle_rounded,
                      label: lang == 'Indonesia' ? 'Selesai' : 'Done',
                      isPrimary: true,
                      isActive: true,
                      accentColor: colors.primary,
                      onTap: _stopListening,
                    )
                  else
                    _ActionButton(
                      icon: Icons.mic_rounded,
                      label: _initializing
                          ? (lang == 'Indonesia' ? 'Menyiapkan...' : 'Wait...')
                          : (lang == 'Indonesia' ? 'Dengarkan' : 'Listen'),
                      isPrimary: true,
                      isActive: micActive,
                      accentColor: colors.primary,
                      onTap: _startListening,
                    ),
                  if (isListening)
                    _ActionButton(
                      icon: Icons.stop_rounded,
                      label: lang == 'Indonesia' ? 'Stop' : 'Stop',
                      isPrimary: true,
                      accentColor: colors.error,
                      onTap: () async {
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
                    )
                  else
                    _ActionButton(
                      icon: Icons.document_scanner_outlined,
                      label: cameraLabel,
                      onTap: () => context.push('/camera'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final ConversationPhase phase;
  final String label;
  final ColorScheme colors;
  final bool isListening;
  final double soundLevel;

  const _StatusBar({
    required this.phase,
    required this.label,
    required this.colors,
    required this.isListening,
    required this.soundLevel,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    switch (phase) {
      case ConversationPhase.listening:
        icon = Icons.mic_rounded;
        iconColor = colors.error;
      case ConversationPhase.recognizing:
        icon = Icons.hearing_rounded;
        iconColor = colors.tertiary;
      case ConversationPhase.detectingLanguage:
        icon = Icons.language_rounded;
        iconColor = colors.secondary;
      case ConversationPhase.translating:
        icon = Icons.translate_rounded;
        iconColor = colors.primary;
      case ConversationPhase.speaking:
        icon = Icons.volume_up_rounded;
        iconColor = colors.primary;
      case ConversationPhase.error:
        icon = Icons.error_outline_rounded;
        iconColor = colors.error;
      case ConversationPhase.completed:
        icon = Icons.check_circle_outline_rounded;
        iconColor = colors.primary;
      case ConversationPhase.idle:
        icon = Icons.chat_bubble_outline_rounded;
        iconColor = colors.onSurfaceVariant;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
          if (isListening)
            SizedBox(
              width: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (soundLevel / 10).clamp(0.05, 1.0),
                  minHeight: 4,
                  backgroundColor: colors.surfaceContainerHighest,
                  color: colors.primary,
                ),
              ),
            ),
        ],
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
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Coba Lagi',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: colors.onErrorContainer),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String lang;
  final Color mutedTextColor;
  final VoidCallback onType;

  const _EmptyState({
    required this.lang,
    required this.mutedTextColor,
    required this.onType,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hint = lang == 'Indonesia'
        ? 'Tekan Dengarkan, bicara, lalu tekan Selesai.\nBahasa akan terdeteksi otomatis.'
        : (lang == '中文'
              ? '点击聆听，说话，然后点完成。\n语言将自动检测。'
              : 'Tap Listen, speak, then tap Done.\nLanguage is auto-detected.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: colors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: mutedTextColor,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onType,
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(lang == 'Indonesia' ? 'Ketik teks' : 'Type text'),
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
  final double soundLevel;
  final Color mutedTextColor;
  final Color textColor;

  const _LivePreviewCard({
    required this.text,
    required this.isListening,
    required this.soundLevel,
    required this.mutedTextColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
        color: colors.primaryContainer.withValues(alpha: 0.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isListening)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              if (isListening) const SizedBox(width: 8),
              Text(
                isListening ? 'Live' : 'Preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text.isEmpty ? '...' : text,
            style: TextStyle(
              fontSize: 17,
              height: 1.35,
              color: textColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (isListening) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (soundLevel / 10).clamp(0.05, 1.0),
                minHeight: 4,
                backgroundColor: colors.surfaceContainerHighest,
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationResultCard extends StatelessWidget {
  const _ConversationResultCard({
    required this.card,
    required this.mutedTextColor,
    required this.textColor,
    required this.isFavorite,
    required this.onSpeak,
    required this.onCopy,
    required this.onCopySource,
    required this.onShare,
    required this.onFavorite,
    required this.onDelete,
  });

  final ConversationCardItem card;
  final Color mutedTextColor;
  final Color textColor;
  final bool isFavorite;
  final VoidCallback onSpeak;
  final VoidCallback onCopy;
  final VoidCallback onCopySource;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(card.timestamp);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
        color: colors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: speaker + timestamp
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  card.speakerLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '→ ${card.targetLanguage.nativeName}',
                  style: TextStyle(fontSize: 12, color: mutedTextColor),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: mutedTextColor),
                ),
              ],
            ),
          ),

          // Source text
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.sourceLanguage.nativeName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mutedTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.sourceText,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colors.outlineVariant),

          // Translated text
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.targetLanguage.nativeName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.translatedText,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.35,
                          color: colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Row(
            children: [
              IconButton(
                tooltip: 'Speaker',
                onPressed: onSpeak,
                icon: Icon(Icons.volume_up_rounded, color: mutedTextColor),
              ),
              IconButton(
                tooltip: 'Favorit',
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite ? colors.primary : mutedTextColor,
                ),
              ),
              IconButton(
                tooltip: 'Salin terjemahan',
                onPressed: onCopy,
                icon: Icon(Icons.copy_rounded, color: mutedTextColor),
              ),
              IconButton(
                tooltip: 'Salin asli',
                onPressed: onCopySource,
                icon: Icon(Icons.content_copy_outlined, color: mutedTextColor),
              ),
              IconButton(
                tooltip: 'Bagikan',
                onPressed: onShare,
                icon: Icon(Icons.share_rounded, color: mutedTextColor),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Hapus',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isActive = false,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isActive;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = accentColor ??
        (isPrimary
            ? (isActive ? colors.error : colors.primary)
            : colors.secondary);
    final size = isPrimary ? 72.0 : 52.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: isPrimary ? 32 : 24,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurface, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
