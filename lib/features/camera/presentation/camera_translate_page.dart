import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/cloud_vision_ocr_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../favorite/providers/favorite_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../language/data/language_model.dart';
import '../../settings/providers/settings_provider.dart';
import 'widgets/language_selector_camera.dart';

/// Mode stabil A14:
/// - Latin (ID/EN): ML Kit on-device
/// - Mandarin/CJK: Cloud Vision (hindari model Chinese lokal yang OOM/crash)
const String _kOcrFailMessage =
    'Teks tidak dapat dikenali. Silakan ambil foto yang lebih jelas.';
const String _kChineseFallbackMessage =
    'Tulisan Mandarin belum terbaca.\n'
    'Coba foto lebih jelas, atau ketik/tempel di menu Translate.';
const String _kVisionNoKeyMessage =
    'OCR Mandarin butuh Google API key (Cloud Vision).\n'
    'Jalankan app dengan:\n'
    '--dart-define=GOOGLE_TRANSLATE_API_KEY=YOUR_KEY\n'
    'Atau ketik/tempel teks di menu Translate.';
const String _kVisionDisabledMessage =
    'Cloud Vision API belum aktif untuk API key ini.\n'
    'Aktifkan Vision API di Google Cloud, lalu coba lagi.\n'
    'Sementara: ketik/tempel di menu Translate.';

class CameraTranslatePage extends ConsumerStatefulWidget {
  const CameraTranslatePage({super.key});

  @override
  ConsumerState<CameraTranslatePage> createState() =>
      _CameraTranslatePageState();
}

class _CameraTranslatePageState extends ConsumerState<CameraTranslatePage> {
  TextRecognizer? _latinRecognizer;
  final _translationService = TranslationService();
  final _ttsService = TtsService();
  final _picker = ImagePicker();
  final _cloudOcr = CloudVisionOcrService();

  String _recognizedText = '';
  String _translatedText = '';
  bool _isRecognizing = false;
  bool _isTranslating = false;
  bool _busy = false;
  String _errorMessage = '';
  CloudVisionOcrFailure _lastCloudFailure = CloudVisionOcrFailure.none;

  LanguageModel _sourceLang = LanguageSelectorCamera.autoDetect;
  // Default tujuan 中文 — cocok untuk interaksi dengan pekerja China di IWIP.
  LanguageModel _targetLang = languageByCode('zh');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _latinRecognizer?.close();
    _latinRecognizer = null;
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _closeLatinRecognizer() async {
    final prev = _latinRecognizer;
    _latinRecognizer = null;
    if (prev != null) {
      try {
        await prev.close();
      } catch (_) {}
    }
  }

  bool _isJunkOcrText(String text) {
    final lower = text.toLowerCase();
    const markers = [
      'camerax',
      'camera2',
      'androidx.camera',
      'exception',
      'stacktrace',
      'stack trace',
      'fatal exception',
    ];
    for (final m in markers) {
      if (lower.contains(m)) return true;
    }
    return false;
  }

  String _cleanOcrText(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) {
          final meaningful = RegExp(
            r'[A-Za-z0-9\u00C0-\u024F\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]',
          ).allMatches(line).length;
          return meaningful >= 1;
        })
        .toList();

    return lines.join('\n').trim();
  }

  bool _isValidOcrText(String text) {
    if (text.isEmpty) return false;
    if (_isJunkOcrText(text)) return false;

    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return false;

    final meaningful = RegExp(
      r'[A-Za-z0-9\u00C0-\u024F\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]',
    ).allMatches(compact).length;
    if (meaningful < 1) return false;
    if (meaningful / compact.length < 0.25) return false;
    return true;
  }

  String _extractOcrText(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) return recognized.text;

    final blocks = [...recognized.blocks]..sort((a, b) {
      final topDiff = (a.boundingBox.top - b.boundingBox.top).abs();
      if (topDiff > 16) {
        return a.boundingBox.top.compareTo(b.boundingBox.top);
      }
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });

    final linesOut = <String>[];
    for (final block in blocks) {
      final lines = [...block.lines]
        ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
      for (final line in lines) {
        final t = line.text.trim();
        if (t.isNotEmpty) linesOut.add(t);
      }
    }

    if (linesOut.isEmpty) return recognized.text;
    return linesOut.join('\n');
  }

  /// OCR Latin ringan — aman di A14.
  Future<String> _ocrLatin(String path) async {
    await _closeLatinRecognizer();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final recognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    _latinRecognizer = recognizer;
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(path));
      return _cleanOcrText(_extractOcrText(recognized));
    } finally {
      await _closeLatinRecognizer();
    }
  }

  String _messageForCloudFailure(CloudVisionOcrFailure failure) {
    return switch (failure) {
      CloudVisionOcrFailure.noApiKey => _kVisionNoKeyMessage,
      CloudVisionOcrFailure.apiDisabled => _kVisionDisabledMessage,
      CloudVisionOcrFailure.imageTooLarge =>
        'Foto terlalu besar untuk OCR cloud. Ambil ulang lebih dekat/ringan.',
      CloudVisionOcrFailure.network =>
        'Gagal koneksi OCR cloud. Cek internet, lalu coba lagi.',
      _ => _kChineseFallbackMessage,
    };
  }

  /// OCR Mandarin/CJK lewat Cloud Vision — tidak memuat model Chinese lokal.
  Future<String?> _ocrCloudVision(String path) async {
    final result = await _cloudOcr.recognizeFile(
      path,
      clean: _cleanOcrText,
      isValid: _isValidOcrText,
    );
    _lastCloudFailure = result.failure;
    return result.isOk ? result.text : null;
  }

  Future<String> _runOcrOnFile(String path) async {
    _lastCloudFailure = CloudVisionOcrFailure.none;
    final needsCjk = _sourceLang.code == 'zh' ||
        _sourceLang.code == 'ja' ||
        _sourceLang.code == 'ko';

    // Jangan pernah load TextRecognitionScript.chinese di A14 (crash OOM).
    if (needsCjk) {
      final cloud = await _ocrCloudVision(path);
      return cloud ?? '';
    }

    if (_sourceLang.code == 'auto') {
      final latin = await _ocrLatin(path);
      if (_isValidOcrText(latin)) return latin;

      // Latin gagal → coba cloud (bisa Mandarin), tanpa model Chinese lokal.
      final cloud = await _ocrCloudVision(path);
      return cloud ?? '';
    }

    // id / en / dll → Latin saja
    return _ocrLatin(path);
  }

  Future<void> _captureAndProcess({required ImageSource source}) async {
    if (_busy) return;

    _busy = true;
    setState(() {
      _isRecognizing = true;
      _errorMessage = '';
      _recognizedText = '';
      _translatedText = '';
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 65,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (!mounted) return;

      if (picked == null) {
        setState(() => _errorMessage = 'Scan dibatalkan.');
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      final cleaned = await _runOcrOnFile(picked.path);

      if (!mounted) return;

      if (!_isValidOcrText(cleaned)) {
        final needsCjk = _sourceLang.code == 'zh' ||
            _sourceLang.code == 'ja' ||
            _sourceLang.code == 'ko' ||
            _sourceLang.code == 'auto';
        setState(() {
          _recognizedText = '';
          _translatedText = '';
          _errorMessage = needsCjk
              ? _messageForCloudFailure(_lastCloudFailure)
              : _kOcrFailMessage;
        });
        return;
      }

      setState(() {
        _isRecognizing = false;
        _recognizedText = cleaned;
      });
      await _translate(cleaned);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = _kOcrFailMessage;
          _recognizedText = '';
          _translatedText = '';
        });
      }
    } finally {
      _busy = false;
      await _closeLatinRecognizer();
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  Future<void> _translate(String text) async {
    final cleaned = _cleanOcrText(text);
    if (!_isValidOcrText(cleaned)) {
      if (mounted) {
        setState(() {
          _translatedText = '';
          _errorMessage = _kOcrFailMessage;
        });
      }
      return;
    }

    setState(() {
      _isTranslating = true;
      _translatedText = '';
      _errorMessage = '';
    });

    try {
      final from = _sourceLang.code == 'auto' ? 'auto' : _sourceLang.code;
      final result = await _translationService.translate(
        text: cleaned,
        from: from,
        to: _targetLang.code,
      );

      if (!mounted) return;

      if (result.trim().isEmpty) {
        setState(() => _errorMessage = _kOcrFailMessage);
        return;
      }

      setState(() => _translatedText = result);
      if (ref.read(settingsProvider).autoSaveHistory) {
        ref.read(historyListProvider.notifier).addHistoryItem(cleaned, result);
      }
      // TTS opsional — jangan await (aman memori).
      final ttsCode = switch (_targetLang.code) {
        'zh' => 'zh-CN',
        'id' => 'id-ID',
        'en' => 'en-US',
        _ => _targetLang.code,
      };
      unawaited(
        _ttsService.speak(result, languageCode: ttsCode).catchError((_) => false),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _translatedText = '';
          _errorMessage = 'Terjemahan gagal. Periksa koneksi internet.';
        });
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _retranslate() {
    if (_isValidOcrText(_recognizedText)) {
      _translate(_recognizedText);
    }
  }

  void _swapLanguages() {
    if (_sourceLang.code == 'auto') {
      setState(() {
        final prevTarget = _targetLang;
        _targetLang = languageByCode('id');
        _sourceLang = prevTarget;
      });
      _retranslate();
      return;
    }

    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
    });
    _retranslate();
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disalin ke clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareResult() {
    final text = _translatedText.isNotEmpty
        ? '$_recognizedText\n\n$_translatedText'
        : _recognizedText;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teks siap dibagikan (disalin)'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final mutedTextColor = colors.onSurfaceVariant;
    final busy = _busy || _isRecognizing || _isTranslating;
    final hasResult = _errorMessage.isNotEmpty ||
        _recognizedText.isNotEmpty ||
        _translatedText.isNotEmpty ||
        _isRecognizing ||
        _isTranslating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Translate'),
        elevation: 0,
        backgroundColor: colors.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LanguageSelectorCamera(
                sourceLang: _sourceLang,
                targetLang: _targetLang,
                onSourceChanged: (lang) {
                  if (lang.code != 'auto' && lang == _targetLang) {
                    _swapLanguages();
                  } else {
                    setState(() => _sourceLang = lang);
                    _retranslate();
                  }
                },
                onTargetChanged: (lang) {
                  if (lang == _sourceLang) {
                    _swapLanguages();
                  } else {
                    setState(() => _targetLang = lang);
                    _retranslate();
                  }
                },
                onSwap: _swapLanguages,
              ),
            ),
            Expanded(
              child: hasResult
                  ? _buildTranslateStyleResult(colors, textColor, mutedTextColor)
                  : _buildScanPanel(colors, busy),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _captureAndProcess(
                                source: ImageSource.gallery,
                              ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeri'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _captureAndProcess(
                                source: ImageSource.camera,
                              ),
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: Text(busy ? 'Memproses...' : 'Scan'),
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

  Widget _buildScanPanel(ColorScheme colors, bool busy) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Container(
              width: 280,
              height: 168,
              decoration: BoxDecoration(
                border: Border.all(color: colors.primary, width: 2.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 36,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Mode stabil Samsung A14\n'
                            'Tekan Scan → foto teks → terjemahan otomatis',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                              height: 1.35,
                            ),
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

  /// Tampilkan hasil seperti halaman Translate: teks sumber besar + terjemahan.
  Widget _buildTranslateStyleResult(
    ColorScheme colors,
    Color textColor,
    Color mutedTextColor,
  ) {
    final favorites = ref.watch(favoriteProvider);
    final canAct = _recognizedText.isNotEmpty &&
        _translatedText.isNotEmpty &&
        !_isTranslating;
    final isFav = canAct &&
        favorites.any(
          (f) =>
              f.originalText.trim().toLowerCase() ==
                  _recognizedText.trim().toLowerCase() &&
              f.translatedText.trim().toLowerCase() ==
                  _translatedText.trim().toLowerCase(),
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.3,
                    color: colors.error,
                  ),
                ),
              ),
            if (_isRecognizing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Mengenali teks...',
                style: TextStyle(fontSize: 22, color: mutedTextColor),
              ),
            ] else if (_recognizedText.isNotEmpty) ...[
              Text(
                _recognizedText,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.18,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
              ),
            ],
            if (_recognizedText.isNotEmpty || _isTranslating) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Divider(color: colors.outlineVariant, height: 1),
              ),
            ],
            if (_isTranslating)
              Center(
                child: CircularProgressIndicator(color: colors.primary),
              )
            else if (_translatedText.isNotEmpty) ...[
              Text(
                _translatedText,
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
                    tooltip: 'Speak',
                    onPressed: () => _ttsService.speak(
                      _translatedText,
                      languageCode: _targetLang.code,
                    ),
                    icon: Icon(
                      Icons.volume_up_rounded,
                      color: mutedTextColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () => _copyText(_translatedText),
                    icon: Icon(Icons.copy_rounded, color: mutedTextColor),
                  ),
                  IconButton(
                    tooltip: 'Favorite',
                    onPressed: () {
                      ref.read(favoriteProvider.notifier).toggleFavorite(
                            sourceLang: _sourceLang.name,
                            targetLang: _targetLang.name,
                            originalText: _recognizedText,
                            translatedText: _translatedText,
                          );
                    },
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: colors.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'History',
                    onPressed: () {
                      ref.read(historyListProvider.notifier).addHistoryItem(
                            _recognizedText,
                            _translatedText,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Disimpan ke riwayat'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(Icons.history_rounded, color: mutedTextColor),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: _shareResult,
                    icon: Icon(Icons.share_rounded, color: mutedTextColor),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

