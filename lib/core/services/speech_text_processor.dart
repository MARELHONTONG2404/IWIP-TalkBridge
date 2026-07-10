import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechTextProcessor {
  static String pickBestText(SpeechRecognitionResult result) {
    if (result.recognizedWords.isNotEmpty) {
      return result.recognizedWords;
    }
    if (result.alternates.isEmpty) return '';

    SpeechRecognitionWords best = result.alternates.first;
    for (final alternate in result.alternates) {
      if (alternate.hasConfidenceRating &&
          best.hasConfidenceRating &&
          alternate.confidence > best.confidence) {
        best = alternate;
      } else if (!best.hasConfidenceRating &&
          alternate.recognizedWords.length > best.recognizedWords.length) {
        best = alternate;
      }
    }

    return best.recognizedWords;
  }

  static String postProcess(String raw, String languageCode) {
    var text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';

    text = _stripFillers(text, languageCode);
    text = _removeGarbage(text);
    text = _applyLanguageFixes(text, languageCode);
    text = _capitalizeSentences(text, languageCode);

    return text;
  }

  static String _removeGarbage(String text) {
    // Daftar kata yang sering muncul sebagai hasil salah interpretasi (hallucinations)
    final garbagePattern = RegExp(
      r'\b(?:lotpong|pong|long|ding)\b',
      caseSensitive: false,
    );
    return text.replaceAll(garbagePattern, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String mergeSession(String committed, String incoming) {
    final base = committed.trim();
    final next = incoming.trim();
    if (next.isEmpty) return base;
    if (base.isEmpty) return next;
    if (base.endsWith(next)) return base;
    if (next.startsWith(base)) return next;

    final needsSpace = !base.endsWith('.') &&
        !base.endsWith('!') &&
        !base.endsWith('?') &&
        !base.endsWith(',');

    return needsSpace ? '$base $next' : '$base$next';
  }

  static String _stripFillers(String text, String languageCode) {
    if (languageCode == 'id') {
      return text
          .replaceAll(RegExp(r'^(ehm+|emm+|anu)\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+(ehm+|emm+|anu)$', caseSensitive: false), '')
          .trim();
    }
    return text
        .replaceAll(RegExp(r'^(uh+|um+|erm+)\s+', caseSensitive: false), '')
        .trim();
  }

  static String _applyLanguageFixes(String text, String languageCode) {
    if (languageCode == 'id') {
      var fixed = text;
      final replacements = <Pattern, String>{
        RegExp(
          r'\b(?:slam|salam|cell?a?mat?|selamat?|some\s+a)\s+(?:pagi|party|parquet|buggy|morning)\b',
          caseSensitive: false,
        ): 'Selamat pagi',
        RegExp(
          r'\b(?:slam|salam|cell?a?mat?|selamat?)\s+(?:siang|sang)\b',
          caseSensitive: false,
        ): 'Selamat siang',
        RegExp(
          r'\b(?:slam|salam|cell?a?mat?|selamat?)\s+(?:sore|sorry)\b',
          caseSensitive: false,
        ): 'Selamat sore',
        RegExp(
          r'\b(?:slam|salam|cell?a?mat?|selamat?)\s+(?:malam|malem)\b',
          caseSensitive: false,
        ): 'Selamat malam',
        RegExp(r'\bsalamat pagi\b', caseSensitive: false): 'Selamat pagi',
        RegExp(r'\bsalamat siang\b', caseSensitive: false): 'Selamat siang',
        RegExp(r'\bsalamat sore\b', caseSensitive: false): 'Selamat sore',
        RegExp(r'\bsalamat malam\b', caseSensitive: false): 'Selamat malam',
        RegExp(r'\bterima kasih\b', caseSensitive: false): 'Terima kasih',
        RegExp(r'\bapa kabar\b', caseSensitive: false): 'apa kabar',
        RegExp(r'\bdi mana\b', caseSensitive: false): 'di mana',
        RegExp(r'\bdimana\b', caseSensitive: false): 'di mana',
        RegExp(r'\bbagaimana\b', caseSensitive: false): 'bagaimana',
        RegExp(r'\btidak\b', caseSensitive: false): 'tidak',
        RegExp(r'\bbisa\b', caseSensitive: false): 'bisa',
      };
      for (final entry in replacements.entries) {
        fixed = fixed.replaceAll(entry.key, entry.value);
      }
      return fixed;
    }

    if (languageCode == 'en') {
      return text[0].toUpperCase() + text.substring(1);
    }

    return text;
  }

  static String _capitalizeSentences(String text, String languageCode) {
    if (languageCode != 'id' && languageCode != 'en') return text;

    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    return parts
        .map((part) {
          final trimmed = part.trim();
          if (trimmed.isEmpty) return trimmed;
          return trimmed[0].toUpperCase() + trimmed.substring(1);
        })
        .join(' ');
  }
}
