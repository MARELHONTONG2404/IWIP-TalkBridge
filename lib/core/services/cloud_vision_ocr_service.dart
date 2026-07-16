import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum CloudVisionOcrFailure {
  none,
  noApiKey,
  imageTooLarge,
  httpError,
  apiDisabled,
  empty,
  network,
}

class CloudVisionOcrResult {
  final String? text;
  final CloudVisionOcrFailure failure;
  final int? statusCode;

  const CloudVisionOcrResult.ok(this.text)
      : failure = CloudVisionOcrFailure.none,
        statusCode = null;

  const CloudVisionOcrResult.fail(
    this.failure, {
    this.statusCode,
  }) : text = null;

  bool get isOk => failure == CloudVisionOcrFailure.none &&
      text != null &&
      text!.trim().isNotEmpty;
}

/// OCR teks (termasuk Mandarin) lewat Cloud Vision.
/// Key sama dengan Translate: `--dart-define=GOOGLE_TRANSLATE_API_KEY=...`
/// Pastikan **Cloud Vision API** aktif di project Google Cloud untuk key tersebut.
class CloudVisionOcrService {
  static const apiKey = String.fromEnvironment('GOOGLE_TRANSLATE_API_KEY');

  /// DOCUMENT_TEXT_DETECTION lebih baik untuk rambu / dokumen / spanduk.
  Future<CloudVisionOcrResult> recognizeFile(
    String path, {
    required String Function(String raw) clean,
    required bool Function(String cleaned) isValid,
  }) async {
    if (apiKey.isEmpty) {
      return const CloudVisionOcrResult.fail(CloudVisionOcrFailure.noApiKey);
    }

    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        return const CloudVisionOcrResult.fail(CloudVisionOcrFailure.empty);
      }
      // Soft limit ~4MB base64 payload; Vision hard limit ~20MB.
      if (bytes.length > 4 * 1024 * 1024) {
        return const CloudVisionOcrResult.fail(
          CloudVisionOcrFailure.imageTooLarge,
        );
      }

      final response = await http
          .post(
            Uri.parse(
              'https://vision.googleapis.com/v1/images:annotate?key=$apiKey',
            ),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'requests': [
                {
                  'image': {'content': base64Encode(bytes)},
                  'features': [
                    {
                      'type': 'DOCUMENT_TEXT_DETECTION',
                      'maxResults': 1,
                    },
                  ],
                  'imageContext': {
                    'languageHints': ['zh', 'zh-CN', 'id', 'en'],
                  },
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        final body = response.body.toLowerCase();
        final disabled = body.contains('vision.googleapis.com') ||
            body.contains('cloud vision api') ||
            body.contains('has not been used') ||
            body.contains('is disabled') ||
            body.contains('permission_denied');
        return CloudVisionOcrResult.fail(
          disabled
              ? CloudVisionOcrFailure.apiDisabled
              : CloudVisionOcrFailure.httpError,
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        return const CloudVisionOcrResult.fail(CloudVisionOcrFailure.empty);
      }

      final responses = data['responses'];
      if (responses is! List || responses.isEmpty) {
        return const CloudVisionOcrResult.fail(CloudVisionOcrFailure.empty);
      }

      final first = responses.first;
      if (first is! Map) {
        return const CloudVisionOcrResult.fail(CloudVisionOcrFailure.empty);
      }

      // Error object di dalam response (HTTP 200 tapi API error).
      final err = first['error'];
      if (err is Map) {
        final msg = (err['message'] ?? '').toString().toLowerCase();
        final disabled = msg.contains('permission') ||
            msg.contains('not been used') ||
            msg.contains('disabled') ||
            msg.contains('forbidden');
        return CloudVisionOcrResult.fail(
          disabled
              ? CloudVisionOcrFailure.apiDisabled
              : CloudVisionOcrFailure.httpError,
          statusCode: err['code'] is int ? err['code'] as int : null,
        );
      }

      // fullTextAnnotation lebih lengkap untuk DOCUMENT_TEXT_DETECTION.
      String? raw;
      final full = first['fullTextAnnotation'];
      if (full is Map && full['text'] is String) {
        raw = full['text'] as String;
      } else {
        final annotations = first['textAnnotations'];
        if (annotations is List && annotations.isNotEmpty) {
          final description = annotations.first['description'];
          if (description is String) raw = description;
        }
      }

      if (raw == null || raw.trim().isEmpty) {
        return const CloudVisionOcrResult.fail(CloudVisionOcrFailure.empty);
      }

      final cleaned = clean(raw);
      if (!isValid(cleaned)) {
        return const CloudVisionOcrResult.fail(CloudVisionOcrFailure.empty);
      }
      return CloudVisionOcrResult.ok(cleaned);
    } catch (_) {
      return const CloudVisionOcrResult.fail(CloudVisionOcrFailure.network);
    }
  }
}
