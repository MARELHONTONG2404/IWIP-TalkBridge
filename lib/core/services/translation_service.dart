import 'dart:convert';

import 'package:http/http.dart' as http;

import 'translation_text_processor.dart';

class TranslationException implements Exception {
  final String message;

  const TranslationException(this.message);

  @override
  String toString() => message;
}

class TranslationService {
  static const _googleUrl = 'https://translate.googleapis.com/translate_a/single';
  static const _myMemoryUrl = 'https://api.mymemory.translated.net/get';
  static const _postLengthThreshold = 180;

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

    TranslationException? lastError;

    final attempts = <Future<String> Function()>[
      () => _translateGoogle(input, from, to),
      if (from != 'auto') () => _translateGoogle(input, 'auto', to),
      () => _translateMyMemory(input, from, to),
    ];

    for (final attempt in attempts) {
      try {
        final translated = await attempt();
        if (_isUsableTranslation(input, translated, from, to)) {
          return translated;
        }
      } on TranslationException catch (e) {
        lastError = e;
      }
    }

    throw lastError ??
        const TranslationException('Terjemahan gagal. Cek koneksi internet.');
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
    bool hasLatin(String value) =>
        RegExp(r'[A-Za-z]').hasMatch(value);
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
          .timeout(const Duration(seconds: 15));
    } else {
      final uri = Uri.parse(_googleUrl).replace(
        queryParameters: {
          ...params,
          'q': text,
        },
      );
      response = await http
          .get(uri, headers: _requestHeaders)
          .timeout(const Duration(seconds: 12));
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
        .timeout(const Duration(seconds: 12));

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
