import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/services/translation_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../language/data/language_model.dart';
import 'widgets/language_selector_camera.dart';

class CameraTranslatePage extends ConsumerStatefulWidget {
  const CameraTranslatePage({super.key});

  @override
  ConsumerState<CameraTranslatePage> createState() =>
      _CameraTranslatePageState();
}

class _CameraTranslatePageState extends ConsumerState<CameraTranslatePage> {
  CameraController? _cameraController;
  TextRecognizer? _textRecognizer;
  final _translationService = TranslationService();
  final _ttsService = TtsService();

  String _recognizedText = '';
  String _translatedText = '';
  bool _isRecognizing = false;
  bool _isTranslating = false;
  String _errorMessage = '';
  
  LanguageModel _sourceLang = languageByCode('id');
  LanguageModel _targetLang = languageByCode('en');

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _updateTextRecognizer();
  }

  void _updateTextRecognizer() {
    _textRecognizer?.close();
    
    // Map language code to ML Kit script
    TextRecognitionScript script;
    switch (_sourceLang.code) {
      case 'zh':
        script = TextRecognitionScript.chinese;
        break;
      case 'ja':
        script = TextRecognitionScript.japanese;
        break;
      case 'ko':
        script = TextRecognitionScript.korean;
        break;
      default:
        script = TextRecognitionScript.latin;
    }
    _textRecognizer = TextRecognizer(script: script);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'Kamera tidak ditemukan.');
        return;
      }
      _cameraController = CameraController(cameras[0], ResolutionPreset.high);
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer?.close();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_textRecognizer == null) return;
    
    setState(() {
      _isRecognizing = true;
      _errorMessage = '';
    });

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await _textRecognizer!.processImage(inputImage);
      final text = recognized.text.trim();

      if (text.isEmpty) {
        setState(() {
          _recognizedText = '';
          _translatedText = '';
          _errorMessage = 'Tidak ada teks yang terdeteksi.';
        });
        return;
      }

      setState(() => _recognizedText = text);
      await _translate(text);
    } catch (e) {
      setState(() => _errorMessage = 'OCR error: $e');
    } finally {
      setState(() => _isRecognizing = false);
    }
  }

  Future<void> _translate(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    try {
      final result = await _translationService.translate(
        text: text,
        from: _sourceLang.code,
        to: _targetLang.code,
      );
      setState(() => _translatedText = result);
    } catch (e) {
      setState(() => _translatedText = 'Terjemahan gagal: $e');
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  void _retranslate() {
    if (_recognizedText.isNotEmpty) {
      _translate(_recognizedText);
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      _updateTextRecognizer();
    });
    _retranslate();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                  if (lang == _targetLang) {
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

            Expanded(
              child: _cameraController == null || !_cameraController!.value.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCameraPreview(colors),
            ),

            if (_recognizedText.isNotEmpty || _translatedText.isNotEmpty)
              _buildResultPanel(colors),

            _buildActionButtons(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(ColorScheme colors) {
    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        Center(
          child: Container(
            width: 250,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultPanel(ColorScheme colors) {
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
              child: CircularProgressIndicator(),
            )
          else if (_recognizedText.isNotEmpty)
            Text('Teks Terdeteksi: $_recognizedText', style: const TextStyle(fontSize: 14)),
          
          const SizedBox(height: 8),
          
          if (_isTranslating)
            const CircularProgressIndicator()
          else if (_translatedText.isNotEmpty)
            Text('Terjemahan: $_translatedText', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.primary)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _captureAndProcess,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Teks'),
      ),
    );
  }
}
