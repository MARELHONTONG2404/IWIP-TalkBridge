import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/baidu_ocr_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../favorite/providers/favorite_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../language/data/language_model.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../../core/services/text_quality_validator.dart';
import '../../../../core/services/image_enhancement_service.dart';
import 'widgets/language_selector_camera.dart';

const String _kOcrFailMessage = 'Teks tidak dapat dikenali.\nSilakan arahkan kamera lebih dekat.';
const String _kChineseFallbackMessage = 'Tulisan Mandarin belum terbaca.\nCoba foto lebih dekat dan jelas.';
const String _kBaiduNoKeyMessage = 'OCR Mandarin butuh Baidu API key.\nJalankan app dengan:\n--dart-define=BAIDU_OCR_API_KEY=YOUR_KEY\n--dart-define=BAIDU_OCR_SECRET_KEY=YOUR_SECRET';
const String _kBaiduDisabledMessage = 'Baidu API limit/disabled.\nCek kuota Baidu API Anda.';

class CameraTranslatePage extends ConsumerStatefulWidget {
  const CameraTranslatePage({super.key});

  @override
  ConsumerState<CameraTranslatePage> createState() => _CameraTranslatePageState();
}

class _CameraTranslatePageState extends ConsumerState<CameraTranslatePage> {
  // --- Camera Engine State ---
  CameraController? _cameraController;
  final ValueNotifier<bool> _isCameraInitialized = ValueNotifier(false);
  final ValueNotifier<bool> _isFlashOn = ValueNotifier(false);
  
  // --- UI State ---
  final ValueNotifier<int> _currentModeIndex = ValueNotifier(1); // 0: Instant, 1: Scan, 2: Import
  final ValueNotifier<String> _recognizedText = ValueNotifier('');
  final ValueNotifier<String> _translatedText = ValueNotifier('');
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  LanguageModel _sourceLang = LanguageSelectorCamera.autoDetect;
  LanguageModel _targetLang = languageByCode('zh');

  // --- Services ---
  TextRecognizer? _textRecognizer;
  final _translationService = TranslationService();
  final _ttsService = TtsService();
  final _picker = ImagePicker();
  final _baiduOcr = BaiduOcrService();

  // --- Optimization Caches ---
  BaiduOcrFailure _lastBaiduFailure = BaiduOcrFailure.none;
  String _lastOcrHash = '';
  Timer? _instantModeTimer;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    
    _currentModeIndex.addListener(() {
      if (_currentModeIndex.value == 0) {
        _startInstantTimer();
      } else {
        _stopInstantTimer();
        _recognizedText.value = '';
        _translatedText.value = '';
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Back Camera Default
        final backCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras[0],
        );
        
        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        
        await _cameraController!.initialize();
        
        // Auto Focus & Exposure defaults
        await _cameraController!.setFocusMode(FocusMode.auto);
        await _cameraController!.setExposureMode(ExposureMode.auto);
        
        _minAvailableZoom = await _cameraController!.getMinZoomLevel();
        _maxAvailableZoom = await _cameraController!.getMaxZoomLevel();

        if (mounted) {
          _isCameraInitialized.value = true;
        }
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _stopInstantTimer();
    _cameraController?.dispose();
    _textRecognizer?.close();
    _isCameraInitialized.dispose();
    _isFlashOn.dispose();
    _currentModeIndex.dispose();
    _recognizedText.dispose();
    _translatedText.dispose();
    _busy.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  // --- Instant Mode Timer (Battery Optimized) ---
  void _startInstantTimer() {
    _instantModeTimer?.cancel();
    // Run every 2 seconds to balance responsiveness and battery/performance
    _instantModeTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentModeIndex.value == 0 && !_busy.value && _isCameraInitialized.value) {
        _captureAndProcess(source: ImageSource.camera, isInstant: true);
      }
    });
  }
  
  void _stopInstantTimer() {
    _instantModeTimer?.cancel();
  }

  // --- OCR Pipeline: Text Cleaning & Validation ---
  Future<void> _closeTextRecognizer() async {
    final prev = _textRecognizer;
    _textRecognizer = null;
    if (prev != null) {
      try {
        await prev.close();
      } catch (_) {}
    }
  }

  bool _isJunkOcrText(String text) {
    final lower = text.toLowerCase();
    const markers = ['camerax', 'camera2', 'androidx.camera', 'exception', 'stacktrace', 'fatal exception'];
    for (final m in markers) {
      if (lower.contains(m)) return true;
    }
    return false;
  }

  String _cleanOcrText(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Remove unprintable characters except newlines
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    // Replace multiple spaces (excluding newlines) with a single space
    text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '';
    
    return lines.join('\n');
  }

  // Heuristic OCR Confidence Validation
  bool _isValidOcrText(String text, [double? confidence]) {
    if (text.isEmpty) return false;
    if (_isJunkOcrText(text)) return false;
    
    return TextQualityValidator.isValid(text: text, confidence: confidence);
  }

  // Auto Crop based on Bounding Box (Extracted implicitly via block sorting)
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

  Future<String> _ocrWithScript(String path, TextRecognitionScript script) async {
    await _closeTextRecognizer();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final recognizer = TextRecognizer(script: script);
    _textRecognizer = recognizer;
    try {
      // InputImage.fromFilePath handles EXIF orientation automatically
      final recognized = await recognizer.processImage(InputImage.fromFilePath(path));
      return _cleanOcrText(_extractOcrText(recognized));
    } finally {
      await _closeTextRecognizer();
    }
  }

  String _messageForBaiduFailure(BaiduOcrFailure failure) {
    return switch (failure) {
      BaiduOcrFailure.noApiKey => _kBaiduNoKeyMessage,
      BaiduOcrFailure.apiDisabled => _kBaiduDisabledMessage,
      BaiduOcrFailure.imageTooLarge => 'Foto terlalu besar. Ambil ulang lebih dekat.',
      BaiduOcrFailure.network => 'Gagal koneksi. Cek internet, lalu coba lagi.',
      _ => _kChineseFallbackMessage,
    };
  }

  Future<String?> _ocrBaidu(String path) async {
    final result = await _baiduOcr.recognizeFile(
      path,
      clean: _cleanOcrText,
      isValid: _isValidOcrText,
    );
    _lastBaiduFailure = result.failure;
    return result.isOk ? result.text : null;
  }

  Future<String> _runOcrOnFile(String path) async {
    _lastBaiduFailure = BaiduOcrFailure.none;

    // Apply image enhancement before OCR
    final enhancedFile = await ImageEnhancementService.enhanceImage(File(path));
    final enhancedPath = enhancedFile.path;

    final needsCjk = _sourceLang.code == 'zh' || _sourceLang.code == 'ja' || _sourceLang.code == 'ko';

    if (needsCjk) {
      if (_sourceLang.code == 'zh') {
        final baidu = await _ocrBaidu(enhancedPath);
        if (baidu != null && baidu.isNotEmpty) return baidu;
        // Fallback to ML Kit Chinese
        return await _ocrWithScript(enhancedPath, TextRecognitionScript.chinese);
      } else {
        final script = _sourceLang.code == 'ja' ? TextRecognitionScript.japanese : 
                       _sourceLang.code == 'ko' ? TextRecognitionScript.korean : 
                       TextRecognitionScript.chinese;
        return await _ocrWithScript(enhancedPath, script);
      }
    }

    if (_sourceLang.code == 'auto') {
      final latin = await _ocrWithScript(enhancedPath, TextRecognitionScript.latin);
      if (_isValidOcrText(latin)) return latin;

      final baidu = await _ocrBaidu(enhancedPath);
      if (baidu != null && baidu.isNotEmpty) return baidu;
      
      return await _ocrWithScript(enhancedPath, TextRecognitionScript.chinese);
    }
    return _ocrWithScript(enhancedPath, TextRecognitionScript.latin);
  }


  // --- Main Processing Pipeline ---
  Future<void> _captureAndProcess({required ImageSource source, bool isInstant = false}) async {
    if (_busy.value) return;

    _busy.value = true;
    if (!isInstant) {
      _recognizedText.value = '';
      _translatedText.value = '';
    }

    try {
      String? imagePath;
      if (source == ImageSource.camera && _currentModeIndex.value != 2) {
        if (_cameraController != null && _cameraController!.value.isInitialized) {
          // Pre-enhancement: Trigger Auto Focus just before capture if possible
          try {
             await _cameraController!.setFocusMode(FocusMode.auto);
          } catch (_) {}
          
          final XFile file = await _cameraController!.takePicture();
          imagePath = file.path;
        } else {
           final picked = await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1200, // High quality for OCR
            imageQuality: 85,
            preferredCameraDevice: CameraDevice.rear,
          );
          imagePath = picked?.path;
        }
      } else {
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          imageQuality: 85,
        );
        imagePath = picked?.path;
      }

      if (!mounted) return;

      if (imagePath == null) {
        if (!isInstant) _showErrorSnackBar('Scan dibatalkan.');
        return;
      }

      if (!isInstant) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (!mounted) return;

      // Pipeline: OCR -> Cleaning -> Extraction
      final cleaned = await _runOcrOnFile(imagePath);

      if (!mounted) return;

      // Pipeline: Confidence Check
      if (!_isValidOcrText(cleaned)) {
        if (!isInstant) {
          final needsCjk = _sourceLang.code == 'zh' || _sourceLang.code == 'ja' || _sourceLang.code == 'ko' || _sourceLang.code == 'auto';
          final msg = needsCjk && _lastBaiduFailure != BaiduOcrFailure.none
                ? _messageForBaiduFailure(_lastBaiduFailure)
                : _kOcrFailMessage; // Silakan arahkan kamera lebih dekat.
                
          _showErrorSnackBar(msg);
        }
        return;
      }

      // Optimization: Duplicate OCR Prevention & Cache
      final hash = cleaned.hashCode.toString() + _sourceLang.code + _targetLang.code;
      if (isInstant && hash == _lastOcrHash && _translatedText.value.isNotEmpty) {
        return; // Skip identical repeated OCR in instant mode
      }
      _lastOcrHash = hash;

      _recognizedText.value = cleaned;
      
      // Pipeline: Translation & Industrial Glossary
      await _translate(cleaned, isInstant: isInstant);
      
      if (mounted && !isInstant && _translatedText.value.isNotEmpty) {
         _showResultBottomSheet();
      }
      
    } catch (_) {
      if (mounted && !isInstant) {
        _showErrorSnackBar('Terjadi kesalahan. Silakan coba lagi.');
      }
    } finally {
      _busy.value = false;
      await _closeTextRecognizer();
    }
  }

  Future<void> _translate(String text, {bool isInstant = false}) async {
    try {
      final from = _sourceLang.code == 'auto' ? 'auto' : _sourceLang.code;
      
      // TranslationService handles Glossary and Grammar Correction via its pipeline
      final result = await _translationService.translate(
        text: text,
        from: from,
        to: _targetLang.code,
      );

      if (!mounted) return;

      if (result.trim().isEmpty) {
        if (!isInstant) _showErrorSnackBar(_kOcrFailMessage);
        return;
      }

      _translatedText.value = result;
      
      if (!isInstant) {
         if (ref.read(settingsProvider).autoSaveHistory) {
           ref.read(historyListProvider.notifier).addHistoryItem(text, result);
         }
      }
      
      // Auto-TTS for Scan Mode only
      if (!isInstant) {
        _playTts(result, _targetLang.code);
      }
    } catch (_) {
      if (mounted && !isInstant) {
        _showErrorSnackBar('Terjemahan gagal. Periksa koneksi internet.');
      }
    }
  }

  void _playTts(String text, String targetCode) {
    _ttsService.setHandlers(
      onError: (message, {isMissingVoice = false}) {
        if (!mounted) return;
        if (isMissingVoice) {
          _showMissingVoiceDialog(message);
        } else {
          _showErrorSnackBar(message);
        }
      },
    );

    final ttsCode = switch (targetCode) {
      'zh' => 'zh-CN',
      'id' => 'id-ID',
      'en' => 'en-US',
      _ => targetCode,
    };

    unawaited(
      _ttsService.speak(text, languageCode: ttsCode, notifyOnError: true).catchError((_) => false),
    );
  }

  void _showMissingVoiceDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paket Suara Tidak Tersedia'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _retranslate() {
    final text = _recognizedText.value;
    if (_isValidOcrText(text)) {
      _busy.value = true;
      _translate(text).then((_) {
         _busy.value = false;
         if (mounted && _translatedText.value.isNotEmpty && _currentModeIndex.value != 0) {
            _showResultBottomSheet();
         }
      });
    }
  }

  void _swapLanguages() {
    setState(() {
      if (_sourceLang.code == 'auto') {
        final prevTarget = _targetLang;
        _targetLang = languageByCode('id');
        _sourceLang = prevTarget;
      } else {
        final temp = _sourceLang;
        _sourceLang = _targetLang;
        _targetLang = temp;
      }
    });
    // Invalidate cache
    _lastOcrHash = '';
    _retranslate();
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disalin ke clipboard'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
    );
  }

  void _shareResult() {
    final text = _translatedText.value.isNotEmpty ? '${_recognizedText.value}\n\n${_translatedText.value}' : _recognizedText.value;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teks siap dibagikan (disalin)'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final newState = !_isFlashOn.value;
      _isFlashOn.value = newState;
      await _cameraController!.setFlashMode(newState ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  // --- Camera Gesture Handlers (Tap to Focus, Pinch to Zoom) ---
  void _onScaleStart(ScaleStartDetails details) {
    _baseZoomLevel = _currentZoomLevel;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_cameraController == null) return;
    final zoom = (_baseZoomLevel * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
    try {
      await _cameraController!.setZoomLevel(zoom);
      _currentZoomLevel = zoom;
    } catch (_) {}
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) async {
    if (_cameraController == null) return;
    final double x = details.localPosition.dx / constraints.maxWidth;
    final double y = details.localPosition.dy / constraints.maxHeight;
    try {
      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
    } catch (e) {
      debugPrint('Focus error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // The entire UI avoids setState for volatile tasks.
    // We only use ValueListenableBuilder for parts that change often.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Engine (Non-rebuilding)
          ValueListenableBuilder<bool>(
            valueListenable: _isCameraInitialized,
            builder: (context, isInit, child) {
              if (isInit && _cameraController != null) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onTapDown: (details) => _onTapDown(details, constraints),
                      child: CameraPreview(_cameraController!),
                    );
                  },
                );
              }
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            },
          ),

          // 2. Scanner Overlay
          CustomPaint(painter: _ScannerOverlayPainter()),

          // 3. UI Overlay
          SafeArea(
            child: Column(
              children: [
                // Header Sederhana (Logo IWIP, IWIP TalkBridge, Industrial Translator)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/iwip_logo_v2.jpg',
                          height: 36,
                          width: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IWIP TalkBridge',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Industrial Translator',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Language Selector
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
                        _lastOcrHash = '';
                      }
                    },
                    onTargetChanged: (lang) {
                      if (lang == _sourceLang) {
                        _swapLanguages();
                      } else {
                        setState(() => _targetLang = lang);
                        _lastOcrHash = '';
                      }
                    },
                    onSwap: _swapLanguages,
                  ),
                ),
                
                const Spacer(),

                // Busy Indicator
                ValueListenableBuilder<bool>(
                  valueListenable: _busy,
                  builder: (context, busy, child) {
                    if (busy) return const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white));
                    return const SizedBox.shrink();
                  },
                ),

                // Instant Mode Result Panel (Bottom Panel)
                ValueListenableBuilder<int>(
                  valueListenable: _currentModeIndex,
                  builder: (context, modeIndex, child) {
                    if (modeIndex == 0) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _translatedText,
                        builder: (context, translated, child) {
                          if (translated.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(200),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ValueListenableBuilder<String>(
                                      valueListenable: _recognizedText,
                                      builder: (context, recognized, _) => Text(
                                        recognized,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      translated,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Mode Selector
                ValueListenableBuilder<int>(
                  valueListenable: _currentModeIndex,
                  builder: (context, modeIndex, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildModeButton(0, 'Instant', modeIndex),
                        const SizedBox(width: 24),
                        _buildModeButton(1, 'Scan', modeIndex),
                        const SizedBox(width: 24),
                        _buildModeButton(2, 'Import', modeIndex),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Bottom Buttons (Gallery, Capture, Flash)
                Padding(
                  padding: const EdgeInsets.only(bottom: 32.0, left: 32.0, right: 32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Gallery
                      ValueListenableBuilder<bool>(
                        valueListenable: _busy,
                        builder: (context, busy, _) => IconButton(
                          icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                          onPressed: busy ? null : () {
                            _currentModeIndex.value = 2;
                            _captureAndProcess(source: ImageSource.gallery);
                          },
                        ),
                      ),
                      // Capture
                      ValueListenableBuilder<bool>(
                        valueListenable: _busy,
                        builder: (context, busy, _) => GestureDetector(
                          onTap: busy ? null : () {
                            _currentModeIndex.value = 1;
                            _captureAndProcess(source: ImageSource.camera);
                          },
                          child: Container(
                            height: 72,
                            width: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: Colors.white.withAlpha(76),
                            ),
                            child: Center(
                              child: Container(
                                height: 54,
                                width: 54,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Flash
                      ValueListenableBuilder<bool>(
                        valueListenable: _isFlashOn,
                        builder: (context, isFlashOn, _) => IconButton(
                          icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 28),
                          onPressed: _toggleFlash,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(int index, String title, int currentIndex) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => _currentModeIndex.value = index,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected ? BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)) : null,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // --- Modern Bottom Sheet for Scan/Import Modes ---
  void _showResultBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBottomSheetContent(),
    );
  }

  Widget _buildBottomSheetContent() {
    return Consumer(
      builder: (context, ref, _) {
        final colors = Theme.of(context).colorScheme;
        final favorites = ref.watch(favoriteProvider);
        
        final recognized = _recognizedText.value;
        final translated = _translatedText.value;
        
        final isFav = favorites.any(
          (f) => f.originalText.trim().toLowerCase() == recognized.trim().toLowerCase() &&
                 f.translatedText.trim().toLowerCase() == translated.trim().toLowerCase(),
        );

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).padding.bottom + 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                
                // OCR Result Label
                Row(
                  children: [
                    Icon(Icons.image_search, size: 16, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Hasil OCR:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    recognized,
                    style: TextStyle(fontSize: 16, color: colors.onSurfaceVariant, height: 1.5),
                    textAlign: TextAlign.left,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Translation Result Label
                Row(
                  children: [
                    Icon(Icons.translate, size: 16, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Terjemahan:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: SelectableText(
                    translated,
                    style: TextStyle(fontSize: 18, color: colors.onSurface, fontWeight: FontWeight.w500, height: 1.5),
                    textAlign: TextAlign.left,
                  ),
                ),
                
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(Icons.copy_rounded, 'Copy', () => _copyText(translated), colors),
                    _buildActionButton(Icons.volume_up_rounded, 'Speak', () => _playTts(translated, _targetLang.code), colors),
                    _buildActionButton(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      'Favorite',
                      () => ref.read(favoriteProvider.notifier).toggleFavorite(
                            sourceLang: _sourceLang.name, targetLang: _targetLang.name,
                            originalText: recognized, translatedText: translated,
                          ),
                      colors,
                      color: isFav ? colors.primary : null,
                    ),
                    _buildActionButton(Icons.share_rounded, 'Share', _shareResult, colors),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, ColorScheme colors, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? colors.onSurfaceVariant, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color ?? colors.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black54;
    final windowWidth = size.width * 0.8;
    final windowHeight = size.height * 0.5;
    final clearRect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: windowWidth, height: windowHeight);
    
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(clearRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, backgroundPaint);

    final cornerPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3.0;
    const cornerLength = 30.0;
    final r = clearRect;

    canvas.drawPath(Path()..moveTo(r.left, r.top + cornerLength)..lineTo(r.left, r.top)..lineTo(r.left + cornerLength, r.top), cornerPaint);
    canvas.drawPath(Path()..moveTo(r.right - cornerLength, r.top)..lineTo(r.right, r.top)..lineTo(r.right, r.top + cornerLength), cornerPaint);
    canvas.drawPath(Path()..moveTo(r.left, r.bottom - cornerLength)..lineTo(r.left, r.bottom)..lineTo(r.left + cornerLength, r.bottom), cornerPaint);
    canvas.drawPath(Path()..moveTo(r.right - cornerLength, r.bottom)..lineTo(r.right, r.bottom)..lineTo(r.right, r.bottom - cornerLength), cornerPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
