import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/speech_service.dart';
import '../../../../core/services/speech_text_processor.dart';
import '../../../../core/services/tts_service.dart';
import '../../providers/conversation_provider.dart';
import '../../../settings/providers/settings_provider.dart';

import '../widgets/conversation_panel.dart';
import '../widgets/language_selector.dart';
import '../widgets/microphone_button.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  @override
  ConsumerState<ConversationPage> createState() =>
      _ConversationPageState();
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

  bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
        _showMessage(message);
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
        _committedText = SpeechTextProcessor.mergeSession(
          _committedText,
          text,
        );
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
        _languageKey(_activeLocale!) != _languageKey(sourceLanguage.speechCode)) {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationProvider);
    final settings = ref.watch(settingsProvider);
    final micActive = _soundLevel > 1;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final lang = settings.appLanguage;
    final title = lang == 'Indonesia' ? 'Terjemahan Langsung' : (lang == '中文' ? '实时翻译' : 'Live Translation');

    final statusText = state.isListening
        ? micActive
            ? (lang == 'Indonesia' ? 'Mic aktif' : (lang == '中文' ? '麦克风开启' : 'Mic active'))
            : (lang == 'Indonesia' ? 'Mendengarkan...' : (lang == '中文' ? '正在听...' : 'Listening...'))
        : _initializing
            ? (lang == 'Indonesia' ? 'Menyiapkan...' : (lang == '中文' ? '准备中...' : 'Initializing...'))
            : _speechReady
                ? (lang == 'Indonesia' ? 'Tap mic untuk mulai' : (lang == '中文' ? '点击麦克风开始' : 'Tap mic to start'))
                : (lang == 'Indonesia' ? 'Mic tidak siap' : (lang == '中文' ? '麦克风未就绪' : 'Mic not ready'));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w700, color: theme.textTheme.titleLarge?.color),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            children: [
              LanguageSelector(
                sourceLanguage: state.sourceLanguage,
                targetLanguage: state.targetLanguage,
                onSourceChanged: (language) {
                  ref
                      .read(conversationProvider.notifier)
                      .setSourceLanguage(language);
                },
                onTargetChanged: (language) {
                  ref
                      .read(conversationProvider.notifier)
                      .setTargetLanguage(language);
                },
                onSwap: () {
                  ref.read(conversationProvider.notifier).swapLanguage();
                },
              ),
              if (_activeLocale != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Speech engine: $_activeLocale',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ConversationPanel(
                        language: state.sourceLanguage,
                        icon: Icons.mic_rounded,
                        subtitle: 'Recognized speech',
                        text: state.speakerText,
                        accentColor: primary,
                        isDraft: state.isSpeakerDraft,
                        isPlaceholder: _isPlaceholder(state.speakerText),
                      ),
                      const SizedBox(height: 16),
                      ConversationPanel(
                        language: state.targetLanguage,
                        icon: Icons.translate_rounded,
                        subtitle: 'Translated result',
                        text: state.translatedText,
                        accentColor: const Color(0xFF059669),
                        isLoading: state.isTranslating,
                        isPlaceholder: _isPlaceholder(state.translatedText),
                        onSpeak: () {
                          print('DEBUG: TTS started for: "${state.translatedText}"');
                          final settings = ref.read(settingsProvider);

                          // Use settings
                          final rate = settings.speechSpeed == 'Slow' ? 0.3 : (settings.speechSpeed == 'Fast' ? 0.8 : 0.5);

                          _ttsService.speak(
                            state.translatedText,
                            languageCode: state.targetLanguage.code,
                          );
                          print('DEBUG: TTS rate set to: $rate');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (state.isListening)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (_soundLevel / 10).clamp(0.05, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade300,
                      color: primary,
                    ),
                  ),
                ),
              MicrophoneButton(
                isListening: state.isListening,
                onPressed: () async {
                  if (state.isListening) {
                    await _stopListening();
                  } else {
                    await _startListening();
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
