import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/translation_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../favorite/providers/favorite_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../language/data/language_model.dart';
import '../../settings/providers/settings_provider.dart';
import 'widgets/language_selector_camera.dart';

/// Mode stabil: foto (image_picker) → crop area scan → OCR → bersih → translate.
/// Tidak memakai stream/preview CameraX untuk OCR.
const double _kScanAspect = 280 / 168;
const String _kOcrFailMessage =
    'Teks tidak dapat dikenali. Silakan ambil foto yang lebih jelas.';

class CameraTranslatePage extends ConsumerStatefulWidget {
  const CameraTranslatePage({super.key});

  @override
  ConsumerState<CameraTranslatePage> createState() =>
      _CameraTranslatePageState();
}

class _CameraTranslatePageState extends ConsumerState<CameraTranslatePage> {
  TextRecognizer? _textRecognizer;
  final _translationService = TranslationService();
  final _ttsService = TtsService();
  final _picker = ImagePicker();

  String _recognizedText = '';
  String _translatedText = '';
  bool _isRecognizing = false;
  bool _isTranslating = false;
  bool _busy = false;
  String _errorMessage = '';

  LanguageModel _sourceLang = LanguageSelectorCamera.autoDetect;
  LanguageModel _targetLang = languageByCode('en');

  @override
  void initState() {
    super.initState();
    _updateTextRecognizer();
  }

  TextRecognitionScript _scriptFor(LanguageModel lang) {
    switch (lang.code) {
      case 'zh':
        return TextRecognitionScript.chinese;
      case 'ja':
        return TextRecognitionScript.japanese;
      case 'ko':
        return TextRecognitionScript.korean;
      default:
        return TextRecognitionScript.latin;
    }
  }

  void _updateTextRecognizer() {
    final prev = _textRecognizer;
    _textRecognizer = TextRecognizer(script: _scriptFor(_sourceLang));
    prev?.close();
  }

  @override
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
    _ttsService.dispose();
    super.dispose();
  }

  bool _isJunkOcrText(String text) {
    final lower = text.toLowerCase();
    const markers = [
      'camerax',
      'camera2',
      'androidx.camera',
      'camera_device',
      'flutter.',
      'exception',
      'stack trace',
      'stacktrace',
      'fatal exception',
    ];
    for (final m in markers) {
      if (lower.contains(m)) return true;
    }
    return false;
  }

  /// Bersihkan hasil OCR sebelum dikirim ke TranslationService.
  String _cleanOcrText(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) {
          // Buang baris yang hampir hanya simbol/noise.
          final meaningful = RegExp(
            r'[A-Za-z0-9\u00C0-\u024F\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]',
          ).allMatches(line).length;
          return meaningful >= 1;
        })
        .toList();

    return lines.join('\n').trim();
  }

  /// Tolak OCR kosong / junk / kualitas rendah agar tidak ikut ditranslate.
  bool _isValidOcrText(String text) {
    if (text.isEmpty) return false;
    if (_isJunkOcrText(text)) return false;

    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 2) return false;

    final meaningful = RegExp(
      r'[A-Za-z0-9\u00C0-\u024F\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]',
    ).allMatches(compact).length;
    if (meaningful < 2) return false;

    // Rasio karakter bermakna terlalu rendah → hasil OCR jelek.
    if (meaningful / compact.length < 0.35) return false;

    return true;
  }

  /// Susun teks OCR dari blok/baris berurutan (lebih akurat dari raw `.text`).
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

  /// Crop pusat sesuai rasio kotak scan (bukan seluruh frame foto).
  Future<String> _cropScanArea(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      // Cap decode untuk Samsung A14 agar tetap akurat tanpa OOM.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1600,
      );
      final frame = await codec.getNextFrame();
      final src = frame.image;

      try {
        final imageW = src.width.toDouble();
        final imageH = src.height.toDouble();

        double cropW;
        double cropH;
        if (imageW / imageH > _kScanAspect) {
          cropH = imageH * 0.72;
          cropW = cropH * _kScanAspect;
        } else {
          cropW = imageW * 0.72;
          cropH = cropW / _kScanAspect;
        }

        cropW = math.min(cropW, imageW);
        cropH = math.min(cropH, imageH);
        final cropX = ((imageW - cropW) / 2).round().clamp(0, src.width - 1);
        final cropY = ((imageH - cropH) / 2).round().clamp(0, src.height - 1);
        final outW = cropW.round().clamp(1, src.width - cropX);
        final outH = cropH.round().clamp(1, src.height - cropY);

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final paint = Paint()..filterQuality = FilterQuality.high;
        canvas.drawImageRect(
          src,
          Rect.fromLTWH(
            cropX.toDouble(),
            cropY.toDouble(),
            outW.toDouble(),
            outH.toDouble(),
          ),
          Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
          paint,
        );

        final cropped = await recorder.endRecording().toImage(outW, outH);
        final byteData =
            await cropped.toByteData(format: ui.ImageByteFormat.png);
        cropped.dispose();
        if (byteData == null) return imagePath;

        final outPath =
            '${Directory.systemTemp.path}${Platform.pathSeparator}'
            'iwip_ocr_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(outPath).writeAsBytes(byteData.buffer.asUint8List());
        return outPath;
      } finally {
        src.dispose();
      }
    } catch (_) {
      return imagePath;
    }
  }

  Future<String> _runOcrOnFile(String path) async {
    // Auto Detect: latin dulu (ID/EN), jika gagal/ada CJK coba Chinese — bergiliran (aman A14).
    if (_sourceLang.code == 'auto') {
      final latin = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final a = await latin.processImage(InputImage.fromFilePath(path));
        final textA = _cleanOcrText(_extractOcrText(a));
        final hasCjk = RegExp(r'[\u4e00-\u9fff]').hasMatch(textA);

        if (_isValidOcrText(textA) && !hasCjk) {
          return textA;
        }

        final chinese = TextRecognizer(script: TextRecognitionScript.chinese);
        try {
          final b =
              await chinese.processImage(InputImage.fromFilePath(path));
          final textB = _cleanOcrText(_extractOcrText(b));

          if (!_isValidOcrText(textA)) return textB;
          if (!_isValidOcrText(textB)) return textA;

          final cjkA = RegExp(r'[\u4e00-\u9fff]').allMatches(textA).length;
          final cjkB = RegExp(r'[\u4e00-\u9fff]').allMatches(textB).length;
          if (cjkB > cjkA) return textB;
          return textA.length >= textB.length ? textA : textB;
        } finally {
          await chinese.close();
        }
      } finally {
        await latin.close();
      }
    }

    final recognizer =
        _textRecognizer ?? TextRecognizer(script: _scriptFor(_sourceLang));
    _textRecognizer = recognizer;
    final recognized =
        await recognizer.processImage(InputImage.fromFilePath(path));
    return _cleanOcrText(_extractOcrText(recognized));
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

    String? cropPath;

    try {
      // Foto berkualitas (file hasil capture, bukan preview stream).
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (!mounted) return;

      if (picked == null) {
        setState(() => _errorMessage = 'Scan dibatalkan.');
        return;
      }

      // Tunggu kamera sistem tutup, lalu crop area scan → OCR file tersebut.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      cropPath = await _cropScanArea(picked.path);
      final cleaned = await _runOcrOnFile(cropPath);

      if (!mounted) return;

      if (!_isValidOcrText(cleaned)) {
        setState(() {
          _recognizedText = '';
          _translatedText = '';
          _errorMessage = _kOcrFailMessage;
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
      if (mounted) setState(() => _isRecognizing = false);
      if (cropPath != null && cropPath.endsWith('.png')) {
        try {
          final f = File(cropPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _translate(String text) async {
    final cleaned = _cleanOcrText(text);
    // Hanya teks OCR valid yang boleh masuk TranslationService.
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
        _targetLang = languageByCode('en');
        _sourceLang = prevTarget;
        _updateTextRecognizer();
      });
      _retranslate();
      return;
    }

    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      _updateTextRecognizer();
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
    final busy = _busy || _isRecognizing || _isTranslating;

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
                    _updateTextRecognizer();
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
            Expanded(child: _buildScanPanel(colors, busy)),
            if (_errorMessage.isNotEmpty ||
                _recognizedText.isNotEmpty ||
                _translatedText.isNotEmpty ||
                _isRecognizing ||
                _isTranslating)
              _buildResultPanel(colors),
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

  Widget _buildResultPanel(ColorScheme colors) {
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_errorMessage, style: TextStyle(color: colors.error)),
            ),
          if (_isRecognizing)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            )
          else if (_recognizedText.isNotEmpty)
            Text(
              _recognizedText,
              style: const TextStyle(fontSize: 14),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          if (_isTranslating)
            const LinearProgressIndicator()
          else if (_translatedText.isNotEmpty)
            Text(
              _translatedText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          if (canAct) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Speak',
                  onPressed: () => _ttsService.speak(
                    _translatedText,
                    languageCode: _targetLang.code,
                  ),
                  icon: Icon(Icons.volume_up_rounded, color: colors.primary),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () => _copyText(_translatedText),
                  icon: Icon(Icons.copy_rounded, color: colors.primary),
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
                  icon: Icon(Icons.history_rounded, color: colors.primary),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: _shareResult,
                  icon: Icon(Icons.share_rounded, color: colors.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
