import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/speech_service.dart';
import '../../../../core/services/speech_text_processor.dart';
import '../../../../core/services/tts_service.dart';
import '../../providers/conversation_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../favorite/providers/favorite_provider.dart';

import '../widgets/language_selector.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();
  bool _speechReady = false;
  bool _initializing = true;
  double _soundLevel = 0;
  String? _activeLocale;
  String _committedText = '';
  String _livePartial = '';

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    setState(() => _initializing = true);

    final ready = await _speechService.initialize(
      onError: (message) {
        if (!mounted) return;

        ref.read(conversationProvider.notifier).stopListening();

        // Show clearer error and suggest retry
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                _startListening();
              },
            ),
          ),
        );
      },
      onStatus: (status) {
        if (!mounted) return;

        if (status == 'doneNoResult') {
          ref.read(conversationProvider.notifier).stopListening();
          _showMessage(
            'Suara tidak terdeteksi. Bicara lebih jelas, pastikan internet aktif, '
            'atau unduh paket bahasa di Google app → Voice.',
          );
        } else if (status == 'notListening' || status == 'done') {
          ref.read(conversationProvider.notifier).stopListening();
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

  String _micHelpMessage(String? error) {
    if (error != null && error.isNotEmpty) return error;

    if (_isMobile) {
      return 'Mikrofon tidak tersedia. Izinkan Microphone untuk app ilb '
          'dan Google app.';
    }

    return 'Mikrofon tidak tersedia. Cek izin mic di pengaturan perangkat.';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
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
        _committedText = SpeechTextProcessor.mergeSession(_committedText, text);
        _livePartial = '';
        notifier.setSpeakerText(_committedText, isDraft: false);
        notifier.translate(_committedText);
      } else {
        _livePartial = text;
        final preview = SpeechTextProcessor.mergeSession(
          _committedText,
          _livePartial,
        );
        notifier.setSpeakerText(preview, isDraft: true);
      }
    });
  }

  void _onSoundLevel(double level) {
    if (!mounted) return;
    setState(() => _soundLevel = level);
  }

  Future<void> _startListening() async {
    if (_initializing) {
      _showMessage('Menyiapkan mikrofon...');
      return;
    }

    if (!_speechReady) {
      await _initializeSpeech();
      if (!_speechReady) return;
    }

    if (_speechService.isListening) return;

    final notifier = ref.read(conversationProvider.notifier);
    final localeId = ref.read(conversationProvider).sourceLanguage.speechCode;

    setState(() {
      _soundLevel = 0;
      _activeLocale = null;
      _committedText = '';
      _livePartial = '';
    });

    notifier.startListening();
    notifier.setSpeakerText('Mendengarkan...', isDraft: true);

    final started = await _speechService.startListening(
      localeId: localeId,
      languageCode: ref.read(conversationProvider).sourceLanguage.code,
      onResult: _onSpeechResult,
      onSoundLevel: _onSoundLevel,
    );

    if (!mounted) return;

    final sourceLanguage = ref.read(conversationProvider).sourceLanguage;
    setState(() => _activeLocale = _speechService.activeLocale);

    if (!started) {
      notifier.stopListening();
      _showMessage(_micHelpMessage(_speechService.lastError));
    } else if (_activeLocale == 'online') {
      _showMessage(
        'Paket suara ${sourceLanguage.nativeName} belum terinstall. '
        'Mencoba mode online — unduh paket bahasa di Google app → Voice '
        'agar hasil lebih akurat.',
      );
    } else if (_activeLocale != null &&
        _normalizeLocaleId(_activeLocale!) !=
            _normalizeLocaleId(sourceLanguage.speechCode) &&
        _languageKey(_activeLocale!) !=
            _languageKey(sourceLanguage.speechCode)) {
      _showMessage(
        'Speech engine: $_activeLocale. '
        'Unduh ${sourceLanguage.nativeName} di Google app → Voice jika teks salah.',
      );
    }
  }

  String _normalizeLocaleId(String locale) =>
      locale.replaceAll('_', '-').toLowerCase();

  String _languageKey(String locale) {
    final base = _normalizeLocaleId(locale).split('-').first;
    if (base == 'in') return 'id';
    if (base == 'cmn' || base == 'yue') return 'zh';
    return base;
  }

  Future<void> _stopListening() async {
    print('DEBUG: _stopListening() called');
    await _speechService.stopListening();

    final notifier = ref.read(conversationProvider.notifier);
    final finalText = _committedText.trim().isNotEmpty
        ? _committedText
        : _livePartial.trim();
    notifier.stopListening();

    if (finalText.isNotEmpty &&
        finalText != 'Mendengarkan...' &&
        finalText != ConversationNotifier.speakerPlaceholder) {
      notifier.setSpeakerText(finalText, isDraft: false);
      print('DEBUG: Translation started for: "$finalText"');
      await notifier.translate(finalText);
      print('DEBUG: Translation success');
    }

    if (!mounted) return;
    setState(() => _soundLevel = 0);
  }

  bool _isPlaceholder(String text) {
    return text == ConversationNotifier.speakerPlaceholder ||
        text == ConversationNotifier.translationPlaceholder ||
        text == 'Mendengarkan...';
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
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context);
                if (text.isNotEmpty) {
                  final notifier = ref.read(conversationProvider.notifier);
                  notifier.setSpeakerText(text, isDraft: false);
                  notifier.translate(text);
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
    final micActive = _soundLevel > 1;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final panelColor = colors.surface;
    final textColor = colors.onSurface;
    final mutedTextColor = colors.onSurfaceVariant;
    final lang = settings.appLanguage;
    final title = lang == 'Indonesia'
        ? 'Terjemahan'
        : (lang == '中文' ? '翻译' : 'Translate');
    final inputHint = lang == 'Indonesia'
        ? 'Terjemahkan teks'
        : (lang == '中文' ? '翻译文本' : 'Translate text');
    final conversationLabel = lang == 'Indonesia'
        ? 'Percakapan'
        : (lang == '中文' ? '对话' : 'Conversation');
    final cameraLabel = lang == 'Indonesia'
        ? 'Kamera'
        : (lang == '中文' ? '相机' : 'Camera');

    final statusText = state.isListening
        ? micActive
              ? (lang == 'Indonesia'
                    ? 'Mic aktif'
                    : (lang == '中文' ? '麦克风开启' : 'Mic active'))
              : (lang == 'Indonesia'
                    ? 'Mendengarkan...'
                    : (lang == '中文' ? '正在听...' : 'Listening...'))
        : _initializing
        ? (lang == 'Indonesia'
              ? 'Menyiapkan...'
              : (lang == '中文' ? '准备中...' : 'Initializing...'))
        : _speechReady
        ? (lang == 'Indonesia'
              ? 'Tap mic untuk mulai'
              : (lang == '中文' ? '点击麦克风开始' : 'Tap mic to start'))
        : (lang == 'Indonesia'
              ? 'Mic tidak siap'
              : (lang == '中文' ? '麦克风未就绪' : 'Mic not ready'));

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
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(34),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _showTextInputDialog,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _isPlaceholder(state.speakerText)
                                    ? inputHint
                                    : state.speakerText,
                                style: TextStyle(
                                  fontSize: _isPlaceholder(state.speakerText)
                                      ? 34
                                      : 28,
                                  height: 1.18,
                                  color: _isPlaceholder(state.speakerText)
                                      ? mutedTextColor
                                      : textColor,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit_note_rounded,
                              color: mutedTextColor,
                              size: 34,
                            ),
                          ],
                        ),
                        if (state.isListening) ...[
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (_soundLevel / 10).clamp(0.05, 1.0),
                              minHeight: 5,
                              backgroundColor: colors.surfaceContainerHighest,
                              color: colors.primary,
                            ),
                          ),
                        ],
                        if (!_isPlaceholder(state.translatedText)) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(
                              color: colors.outlineVariant,
                              height: 1,
                            ),
                          ),
                          if (state.isTranslating)
                            Center(
                              child: CircularProgressIndicator(
                                color: colors.primary,
                              ),
                            )
                          else ...[
                            Text(
                              state.translatedText,
                              style: TextStyle(
                                fontSize: 27,
                                height: 1.25,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _ttsService.speak(
                                    state.translatedText,
                                    languageCode: state.targetLanguage.code,
                                  ),
                                  icon: Icon(
                                    Icons.volume_up_rounded,
                                    color: mutedTextColor,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => ref
                                      .read(favoriteProvider.notifier)
                                      .toggleFavorite(
                                        sourceLang: state.sourceLanguage.name,
                                        targetLang: state.targetLanguage.name,
                                        originalText: state.speakerText,
                                        translatedText: state.translatedText,
                                      ),
                                  icon: Icon(
                                    ref
                                            .watch(favoriteProvider.notifier)
                                            .isFavorite(
                                              state.speakerText,
                                              state.translatedText,
                                            )
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
              child: LanguageSelector(
                sourceLanguage: state.sourceLanguage,
                targetLanguage: state.targetLanguage,
                onSourceChanged: (language) => ref
                    .read(conversationProvider.notifier)
                    .setSourceLanguage(language),
                onTargetChanged: (language) => ref
                    .read(conversationProvider.notifier)
                    .setTargetLanguage(language),
                onSwap: () =>
                    ref.read(conversationProvider.notifier).swapLanguage(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.people_alt_outlined,
                      label: conversationLabel,
                      onTap: _showTextInputDialog,
                    ),
                  ),
                  Expanded(
                    child: _ActionButton(
                      icon: state.isListening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      label: statusText,
                      isPrimary: true,
                      isActive: state.isListening || micActive,
                      onTap: () async {
                        if (state.isListening) {
                          await _stopListening();
                        } else {
                          await _startListening();
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.document_scanner_outlined,
                      label: cameraLabel,
                      onTap: () => _showMessage(
                        lang == 'Indonesia'
                            ? 'Terjemahan dari kamera akan segera tersedia.'
                            : 'Camera translation will be available soon.',
                      ),
                    ),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isPrimary
        ? (isActive ? colors.error : colors.primary)
        : colors.secondary;
    final size = isPrimary ? 88.0 : 60.0;
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
                size: isPrimary ? 36 : 28,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurface, fontSize: 14),
        ),
      ],
    );
  }
}
