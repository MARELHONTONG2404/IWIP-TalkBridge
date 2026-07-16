import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

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

  bool _isFatalSpeechError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('izin mikrofon') ||
        lower.contains('permission') ||
        lower.contains('diblokir') ||
        lower.contains('ditolak') ||
        lower.contains('dipakai app lain') ||
        lower.contains('busy') ||
        lower.contains('tidak tersedia');
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

        // Error non-fatal saat sesi aktif (locale/network sementara).
        if (_manualSessionActive && !_isFatalSpeechError(message)) {
          _log('[Speech Recognition] non-fatal during session: $message');
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

  Future<void> _shareCard(ConversationCardItem card) async {
    final time = DateFormat('dd/MM/yyyy HH:mm').format(card.timestamp);
    final payload =
        '[${card.speakerLabel}] $time\n'
        '${card.sourceLanguage.nativeName}: ${card.sourceText}\n'
        '${card.targetLanguage.nativeName}: ${card.translatedText}';
    await Share.share(payload);
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
    final isListening = state.isListening || _manualSessionActive;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lang = settings.appLanguage;
    final statusLabel = _phaseLabel(state.phase, lang);

    ref.listen(conversationProvider.select((s) => s.cards.length), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surfaceContainerLowest,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          lang == 'Indonesia' ? 'Terjemahan' : (lang == '中文' ? '翻译' : 'Translate'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: colors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          if (state.cards.isNotEmpty)
            IconButton(
              tooltip: lang == 'Indonesia' ? 'Hapus riwayat' : 'Clear',
              onPressed: () => ref.read(conversationProvider.notifier).clearCards(),
              icon: Icon(Icons.delete_outline_rounded, color: colors.onSurfaceVariant, size: 22),
            ),
          IconButton(
            tooltip: 'Favorit',
            onPressed: () => context.push('/favorite'),
            icon: Icon(Icons.star_outline_rounded, color: colors.onSurfaceVariant, size: 22),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.hasError && state.errorMessage != null)
            _MinimalErrorStrip(
              message: state.errorMessage!,
              onRetry: () async {
                await ref.read(conversationProvider.notifier).retryLastTranslation();
                if (!mounted) return;
                final translated = ref.read(conversationProvider).translatedText;
                if (translated.isNotEmpty && !translated.startsWith('Terjemahan')) {
                  _scrollToBottom();
                  await _ttsService.speak(
                    translated,
                    languageCode: ref.read(conversationProvider).targetLanguage.code,
                  );
                }
              },
              onDismiss: () => ref.read(conversationProvider.notifier).clearError(),
            ),

          Expanded(
            child: state.cards.isEmpty && !isListening && !state.isSpeakerDraft
                ? _EmptyState(
                    lang: lang,
                    speechReady: _speechReady,
                    initializing: _initializing,
                    onType: _showTextInputDialog,
                    onRetryMic: _initializeSpeech,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    itemCount: state.cards.length +
                        (isListening || state.isSpeakerDraft ? 1 : 0) +
                        (state.isTranslating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < state.cards.length) {
                        final card = state.cards[index];
                        final isFav = ref
                            .watch(favoriteProvider.notifier)
                            .isFavorite(card.sourceText, card.translatedText);
                        return _ConversationResultCard(
                          card: card,
                          isFavorite: isFav,
                          onSpeak: () => _ttsService.speak(
                            card.translatedText,
                            languageCode: card.targetLanguage.code,
                          ),
                          onCopy: () => _copyText(card.translatedText),
                          onShare: () => _shareCard(card),
                          onFavorite: () => ref.read(favoriteProvider.notifier).toggleFavorite(
                                sourceLang: card.sourceLanguage.name,
                                targetLang: card.targetLanguage.name,
                                originalText: card.sourceText,
                                translatedText: card.translatedText,
                              ),
                          onDelete: () =>
                              ref.read(conversationProvider.notifier).removeCard(card.id),
                        );
                      }

                      final liveIndex = state.cards.length;
                      if ((isListening || state.isSpeakerDraft) && index == liveIndex) {
                        return _LivePreviewCard(
                          text: state.speakerText,
                          isListening: isListening,
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom dock — minimal & fokus mic
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TargetLanguageSelector(
                      detectedSource: state.sourceLanguage,
                      targetLanguage: state.targetLanguage,
                      twoWayMode: state.twoWayMode,
                      onTargetChanged: (l) =>
                          ref.read(conversationProvider.notifier).setTargetLanguage(l),
                      onTwoWayChanged: (v) =>
                          ref.read(conversationProvider.notifier).setTwoWayMode(v),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isListening ? colors.primary : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SideIconButton(
                          icon: Icons.keyboard_rounded,
                          onTap: _showTextInputDialog,
                        ),
                        const SizedBox(width: 28),
                        _MicButton(
                          isListening: isListening,
                          isInitializing: _initializing,
                          soundLevel: _soundLevel,
                          onTap: isListening ? _stopListening : _startListening,
                        ),
                        const SizedBox(width: 28),
                        if (isListening)
                          _SideIconButton(
                            icon: Icons.close_rounded,
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
                          _SideIconButton(
                            icon: Icons.document_scanner_outlined,
                            onTap: () => context.push('/camera'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Minimal UI widgets ───────────────────────────────────────────────────────

class _MinimalErrorStrip extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _MinimalErrorStrip({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: colors.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: colors.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Coba', style: TextStyle(fontSize: 12, color: colors.onErrorContainer)),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close, size: 16, color: colors.onErrorContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String lang;
  final bool speechReady;
  final bool initializing;
  final VoidCallback onType;
  final VoidCallback onRetryMic;

  const _EmptyState({
    required this.lang,
    required this.speechReady,
    required this.initializing,
    required this.onType,
    required this.onRetryMic,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer.withValues(alpha: 0.4),
              ),
              child: Icon(
                speechReady ? Icons.translate_rounded : Icons.mic_off_outlined,
                size: 32,
                color: speechReady ? colors.primary : colors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              lang == 'Indonesia' ? 'Mulai percakapan' : 'Start conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang == 'Indonesia'
                  ? 'Tekan tombol mikrofon di bawah,\nbicara, lalu tap lagi untuk selesai.'
                  : 'Tap the mic below, speak,\nthen tap again when done.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (!speechReady && !initializing) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetryMic, child: const Text('Aktifkan mikrofon')),
            ],
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onType,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(lang == 'Indonesia' ? 'Atau ketik teks' : 'Or type text'),
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

  const _LivePreviewCard({required this.text, required this.isListening});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isListening)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 8, right: 10),
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                text.isEmpty ? '...' : text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  color: colors.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationResultCard extends StatelessWidget {
  const _ConversationResultCard({
    required this.card,
    required this.isFavorite,
    required this.onSpeak,
    required this.onCopy,
    required this.onShare,
    required this.onFavorite,
    required this.onDelete,
  });

  final ConversationCardItem card;
  final bool isFavorite;
  final VoidCallback onSpeak;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timeStr = DateFormat('HH:mm').format(card.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '${card.speakerLabel} · $timeStr',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ),
          _Bubble(text: card.sourceText, isSource: true),
          const SizedBox(height: 8),
          _Bubble(
            text: card.translatedText,
            isSource: false,
            subtitle: card.targetLanguage.nativeName,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _CardAction(icon: Icons.volume_up_rounded, onTap: onSpeak),
              _CardAction(
                icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                onTap: onFavorite,
                active: isFavorite,
              ),
              _CardAction(icon: Icons.copy_rounded, onTap: onCopy),
              _CardAction(icon: Icons.share_outlined, onTap: onShare),
              const Spacer(),
              _CardAction(icon: Icons.delete_outline_rounded, onTap: onDelete, danger: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isSource;
  final String? subtitle;

  const _Bubble({
    required this.text,
    required this.isSource,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isSource
            ? colors.surface
            : colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        boxShadow: isSource
            ? [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: colors.primary,
                ),
              ),
            ),
          Text(
            text,
            style: TextStyle(
              fontSize: isSource ? 15 : 16,
              height: 1.45,
              fontWeight: isSource ? FontWeight.w400 : FontWeight.w500,
              color: isSource ? colors.onSurface : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  const _CardAction({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = danger
        ? colors.error.withValues(alpha: 0.7)
        : active
            ? colors.primary
            : colors.onSurfaceVariant.withValues(alpha: 0.7);
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isListening;
  final bool isInitializing;
  final double soundLevel;
  final VoidCallback onTap;

  const _MicButton({
    required this.isListening,
    required this.isInitializing,
    required this.soundLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeColor = isListening ? colors.error : colors.primary;
    final scale = isListening ? 1.0 + (soundLevel / 10).clamp(0.0, 0.12) : 1.0;

    return GestureDetector(
      onTap: isInitializing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72 * scale,
        height: 72 * scale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activeColor,
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.35),
              blurRadius: isListening ? 20 : 12,
              spreadRadius: isListening ? 2 : 0,
            ),
          ],
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          color: colors.onPrimary,
          size: 32,
        ),
      ),
    );
  }
}

class _SideIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SideIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
