import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

enum BaiduOcrFailure {
  none,
  noApiKey,
  apiDisabled,
  imageTooLarge,
  network,
  unknown,
}

class BaiduOcrResult {
  final String text;
  final BaiduOcrFailure failure;

  const BaiduOcrResult({
    this.text = '',
    this.failure = BaiduOcrFailure.none,
  });

  bool get isOk => failure == BaiduOcrFailure.none && text.isNotEmpty;
}

class BaiduOcrService {
  static const String _apiKey = String.fromEnvironment('BAIDU_OCR_API_KEY');
  static const String _secretKey = String.fromEnvironment('BAIDU_OCR_SECRET_KEY');
  
  static const String _tokenUrl = 'https://aip.baidubce.com/oauth/2.0/token';
  static const String _ocrUrl = 'https://aip.baidubce.com/rest/2.0/ocr/v1/accurate_basic';

  String? _accessToken;
  DateTime? _tokenExpiry;

  bool get hasApiKey => _apiKey.isNotEmpty && _secretKey.isNotEmpty;

  Future<String?> _getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    if (!hasApiKey) return null;

    try {
      final response = await http.post(
        Uri.parse('$_tokenUrl?grant_type=client_credentials&client_id=$_apiKey&client_secret=$_secretKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('access_token')) {
          _accessToken = data['access_token'];
          // Token typically expires in 30 days, we set it safely to 29 days
          _tokenExpiry = DateTime.now().add(const Duration(days: 29));
          return _accessToken;
        }
      }
    } catch (e) {
      debugPrint('Baidu OCR Auth Error: $e');
    }
    return null;
  }

  Future<BaiduOcrResult> recognizeFile(
    String filePath, {
    String Function(String)? clean,
    bool Function(String, [double?])? isValid,
  }) async {
    if (!hasApiKey) {
      return const BaiduOcrResult(failure: BaiduOcrFailure.noApiKey);
    }

    final token = await _getAccessToken();
    if (token == null) {
      return const BaiduOcrResult(failure: BaiduOcrFailure.network); // Could be auth failure but let's call it network
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const BaiduOcrResult(failure: BaiduOcrFailure.unknown);
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Baidu OCR requires URL-encoded base64 string for the image
      final response = await http.post(
        Uri.parse('$_ocrUrl?access_token=$token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'image': base64Image,
          'language_type': 'CHN_ENG',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data.containsKey('error_code')) {
          final errorCode = data['error_code'];
          debugPrint('Baidu OCR Error: $errorCode - ${data['error_msg']}');
          if (errorCode == 17 || errorCode == 18) { // Open API daily limit reached or QPS limit
            return const BaiduOcrResult(failure: BaiduOcrFailure.apiDisabled);
          }
          if (errorCode == 216201) { // image format error
            return const BaiduOcrResult(failure: BaiduOcrFailure.unknown);
          }
          if (errorCode == 216202) { // image size error
            return const BaiduOcrResult(failure: BaiduOcrFailure.imageTooLarge);
          }
          return const BaiduOcrResult(failure: BaiduOcrFailure.unknown);
        }

        if (data.containsKey('words_result')) {
          final results = data['words_result'] as List;
          final buffer = StringBuffer();
          
          for (var item in results) {
            final word = item['words']?.toString() ?? '';
            if (word.isNotEmpty) {
              buffer.writeln(word);
            }
          }

          var extractedText = buffer.toString().trim();
          
          if (clean != null) {
            extractedText = clean(extractedText);
          }

          if (isValid != null && !isValid(extractedText)) {
            return const BaiduOcrResult(failure: BaiduOcrFailure.unknown);
          }

          return BaiduOcrResult(text: extractedText);
        }
      } else {
         debugPrint('Baidu OCR HTTP Error: ${response.statusCode}');
         if (response.statusCode == 413) {
            return const BaiduOcrResult(failure: BaiduOcrFailure.imageTooLarge);
         }
      }
    } on SocketException catch (_) {
      return const BaiduOcrResult(failure: BaiduOcrFailure.network);
    } catch (e) {
      debugPrint('Baidu OCR Exception: $e');
    }

    return const BaiduOcrResult(failure: BaiduOcrFailure.unknown);
  }
}
