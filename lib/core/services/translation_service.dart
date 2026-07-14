import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'translation_text_processor.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

class TranslationException implements Exception {
  final String message;

  const TranslationException(this.message);

  @override
  String toString() => message;
}

class TranslationService {
  /// Official Google Cloud Translation API key (optional).
  /// Pass at build/run: `--dart-define=GOOGLE_TRANSLATE_API_KEY=your_key`
  static const _cloudApiKey = String.fromEnvironment('GOOGLE_TRANSLATE_API_KEY');

  static const _cloudUrl =
      'https://translation.googleapis.com/language/translate/v2';
  static const _googleUrl = 'https://translate.googleapis.com/translate_a/single';
  static const _myMemoryUrl = 'https://api.mymemory.translated.net/get';
  static const _postLengthThreshold = 180;
  static const _chunkSize = 500;
  static const _requestTimeout = Duration(seconds: 30);

  static const Map<String, String> _googleCodes = {
    'zh': 'zh-CN',
  };

  static const Map<String, String> _myMemoryCodes = {
    'zh': 'zh-CN',
    'en': 'en-US',
    'id': 'id-ID',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'ar': 'ar-SA',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'es': 'es-ES',
    'ru': 'ru-RU',
  };

  String _googleCode(String code) => _googleCodes[code] ?? code;

  String _myMemoryCode(String code) => _myMemoryCodes[code] ?? code;

  Future<String> translate({
    required String text,
    required String from,
    required String to,
  }) async {
    final input = TranslationTextProcessor.prepare(text, from);
    if (input.isEmpty) return '';

    if (from == to) return input;

    if (input.length > _chunkSize) {
       _log(
        '[Translation API] chunking ${input.length} chars into parts of ~$_chunkSize',
      );
      return _translateChunked(input, from, to);
    }

    return _translateWithRetry(input, from, to);
  }

  Future<String> _translateChunked(
    String input,
    String from,
    String to,
  ) async {
    final chunks = _splitIntoChunks(input, _chunkSize);
     _log('[Translation API] ${chunks.length} chunk(s)');
    final parts = <String>[];
    for (var i = 0; i < chunks.length; i++) {
       _log(
        '[Translation API] chunk ${i + 1}/${chunks.length} '
        '(${chunks[i].length} chars)',
      );
      parts.add(await _translateWithRetry(chunks[i], from, to));
    }
    return parts.join(' ');
  }

  List<String> _splitIntoChunks(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];
    var remaining = text.trim();

    while (remaining.length > maxLen) {
      var cut = remaining.lastIndexOf(RegExp(r'[.!?。！？\n]'), maxLen);
      if (cut < maxLen ~/ 2) {
        cut = remaining.lastIndexOf(' ', maxLen);
      }
      if (cut < maxLen ~/ 2) {
        cut = maxLen;
      } else {
        cut += 1;
      }

      chunks.add(remaining.substring(0, cut).trim());
      remaining = remaining.substring(cut).trim();
    }

    if (remaining.isNotEmpty) {
      chunks.add(remaining);
    }
    return chunks;
  }

  /// One full provider cascade with a single retry on failure.
  Future<String> _translateWithRetry(
    String input,
    String from,
    String to,
  ) async {
    TranslationException? lastError;

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
         _log(
          '[Translation API] attempt $attempt/2 '
          '(${input.length} chars, $from->$to)',
        );
        return await _translateOnce(input, from, to);
      } on TimeoutException catch (e) {
         _log('[Timeout] Translation API: $e');
        lastError = const TranslationException(
          'Terjemahan timeout. Silakan coba lagi.',
        );
      } on TranslationException catch (e) {
         _log('[Translation API] failed: $e');
        lastError = e;
        if (_isNetworkError(e.message)) {
           _log('[Network] ${e.message}');
        }
      } catch (e) {
         _log('[Translation API] unexpected: $e');
        if (_isNetworkError('$e')) {
           _log('[Network] $e');
          lastError = const TranslationException(
            'Terjemahan gagal. Periksa koneksi internet.',
          );
        } else {
          lastError = TranslationException('Terjemahan gagal: $e');
        }
      }

      if (attempt == 1) {
         _log('[Translation API] retrying once...');
      }
    }

    throw lastError ??
        const TranslationException('Terjemahan gagal. Silakan coba lagi.');
  }

  Future<String> _translateOnce(
    String input,
    String from,
    String to,
  ) async {
    TranslationException? lastError;

    final attempts = <Future<String> Function()>[
      if (_cloudApiKey.isNotEmpty) () => _translateCloudOfficial(input, from, to),
      () => _translateGoogle(input, from, to),
      if (from != 'auto') () => _translateGoogle(input, 'auto', to),
      () => _translateMyMemory(input, from, to),
    ];

    if (_cloudApiKey.isNotEmpty) {
       _log('[Translation API] using Cloud Translation (official) first');
    }

    for (final attempt in attempts) {
      try {
        final translated = await attempt().timeout(_requestTimeout);
        if (_isUsableTranslation(input, translated, from, to)) {
          return translated;
        }
      } on TimeoutException {
         _log('[Timeout] provider request exceeded 30s');
        rethrow;
      } on TranslationException catch (e) {
        lastError = e;
      } catch (e) {
        if (_isNetworkError('$e')) {
           _log('[Network] $e');
          rethrow;
        }
        lastError = TranslationException('$e');
      }
    }

    throw lastError ??
        const TranslationException('Terjemahan gagal. Silakan coba lagi.');
  }

  Future<String> _translateCloudOfficial(
    String text,
    String from,
    String to,
  ) async {
    final uri = Uri.parse(_cloudUrl).replace(
      queryParameters: {'key': _cloudApiKey},
    );

    final body = <String, dynamic>{
      'q': text,
      'target': _googleCode(to),
      'format': 'text',
    };
    if (from != 'auto') {
      body['source'] = _googleCode(from);
    }

    final response = await http
        .post(
          uri,
          headers: {
            ..._requestHeaders,
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw TranslationException(
        'Cloud Translation error (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final translations =
        (data['data'] as Map<String, dynamic>?)?['translations'] as List?;
    if (translations == null || translations.isEmpty) {
      throw const TranslationException('Cloud Translation: hasil kosong');
    }

    final translated = _decodeHtmlEntities(
      (translations.first as Map<String, dynamic>)['translatedText']
              ?.toString()
              .trim() ??
          '',
    );

    if (translated.isEmpty) {
      throw const TranslationException('Cloud Translation: hasil kosong');
    }

    return translated;
  }

  bool _isNetworkError(String value) {
    final lower = value.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset');
  }

  bool _isUsableTranslation(
    String source,
    String translated,
    String from,
    String to,
  ) {
    final normalizedSource = source.trim().toLowerCase();
    final normalizedTranslated = translated.trim().toLowerCase();

    if (normalizedTranslated.isEmpty) return false;
    if (normalizedTranslated.contains('MYMEMORY WARNING')) return false;

    if (from != to &&
        normalizedSource == normalizedTranslated &&
        !_isSameScript(source, translated)) {
      return false;
    }

    return true;
  }

  bool _isSameScript(String a, String b) {
    bool hasLatin(String value) => RegExp(r'[A-Za-z]').hasMatch(value);
    bool hasCjk(String value) =>
        RegExp(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]').hasMatch(value);

    return hasLatin(a) == hasLatin(b) && hasCjk(a) == hasCjk(b);
  }

  Future<String> _translateGoogle(
    String text,
    String from,
    String to,
  ) async {
    final params = {
      'client': 'gtx',
      'sl': _googleCode(from),
      'tl': _googleCode(to),
      'hl': _googleCode(to),
      'dt': 't',
      'ie': 'UTF-8',
      'oe': 'UTF-8',
    };

    final http.Response response;
    if (text.length >= _postLengthThreshold) {
      final uri = Uri.parse(_googleUrl).replace(queryParameters: params);
      response = await http
          .post(
            uri,
            headers: _requestHeaders,
            body: {'q': text},
            encoding: utf8,
          )
          .timeout(_requestTimeout);
    } else {
      final uri = Uri.parse(_googleUrl).replace(
        queryParameters: {
          ...params,
          'q': text,
        },
      );
      response = await http
          .get(uri, headers: _requestHeaders)
          .timeout(_requestTimeout);
    }

    if (response.statusCode != 200) {
      throw TranslationException(
        'Google Translate error (${response.statusCode})',
      );
    }

    return _parseGoogleResponse(response.body);
  }

  String _parseGoogleResponse(String body) {
    final data = jsonDecode(body);
    if (data is! List || data.isEmpty || data.first is! List) {
      throw TranslationException('Format terjemahan tidak valid');
    }

    final segments = data.first as List;
    final translated = segments
        .whereType<List>()
        .map((segment) => segment.isNotEmpty ? segment.first.toString() : '')
        .where((part) => part.isNotEmpty)
        .join();

    final cleaned = _decodeHtmlEntities(translated.trim());
    if (cleaned.isEmpty) {
      throw TranslationException('Terjemahan kosong');
    }

    return cleaned;
  }

  Future<String> _translateMyMemory(
    String text,
    String from,
    String to,
  ) async {
    final uri = Uri.parse(_myMemoryUrl).replace(
      queryParameters: {
        'q': text,
        'langpair': '${_myMemoryCode(from)}|${_myMemoryCode(to)}',
        'de': 'dev@ilb.app',
      },
    );

    final response = await http
        .get(uri, headers: _requestHeaders)
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw TranslationException('MyMemory error (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final translated = _decodeHtmlEntities(
      (data['responseData'] as Map<String, dynamic>?)?['translatedText']
              ?.toString()
              .trim() ??
          '',
    );

    if (translated.isEmpty) {
      throw TranslationException('Terjemahan kosong');
    }

    if (translated.toUpperCase().contains('MYMEMORY WARNING')) {
      throw TranslationException('Limit terjemahan harian tercapai');
    }

    return translated;
  }

  Map<String, String> get _requestHeaders => const {
        'User-Agent':
            'Mozilla/5.0 (compatible; ILB/1.0; +https://github.com/ilb)',
        'Accept': 'application/json,text/plain,*/*',
      };

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }
}
