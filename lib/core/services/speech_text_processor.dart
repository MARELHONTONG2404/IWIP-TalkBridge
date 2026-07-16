import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechTextProcessor {
  static String pickBestText(SpeechRecognitionResult result) {
    if (result.alternates.isEmpty) return result.recognizedWords;

    SpeechRecognitionWords best = result.alternates.first;
    for (final alternate in result.alternates) {
      if (alternate.hasConfidenceRating && best.hasConfidenceRating) {
        // Prioritaskan confidence tertinggi (semirip Google).
        if (alternate.confidence > best.confidence) {
          best = alternate;
        } else if ((alternate.confidence - best.confidence).abs() <= 0.02 &&
            alternate.recognizedWords.length > best.recognizedWords.length) {
          best = alternate;
        }
      } else if (alternate.hasConfidenceRating && !best.hasConfidenceRating) {
        best = alternate;
      } else if (!best.hasConfidenceRating &&
          alternate.recognizedWords.length > best.recognizedWords.length) {
        best = alternate;
      }
    }

    return best.recognizedWords.isNotEmpty
        ? best.recognizedWords
        : result.recognizedWords;
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
    // Hanya token nonsense yang jelas hallucination — jangan hapus kata umum.
    final garbagePattern = RegExp(
      r'\b(?:lotpong)\b',
      caseSensitive: false,
    );
    return text
        .replaceAll(garbagePattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Gabungkan hasil final STT agar kalimat panjang stabil (hindari duplikasi).
  static String mergeSession(String committed, String incoming) {
    final base = committed.trim();
    final next = incoming.trim();
    if (next.isEmpty) return base;
    if (base.isEmpty) return next;
    if (base == next) return base;
    if (base.endsWith(next)) return base;
    if (next.startsWith(base)) return next;
    if (base.startsWith(next)) return base;

    final baseLower = base.toLowerCase();
    final nextLower = next.toLowerCase();
    if (nextLower.contains(baseLower)) return next;
    if (baseLower.contains(nextLower)) return base;

    final baseWords = base.split(RegExp(r'\s+'));
    final nextWords = next.split(RegExp(r'\s+'));
    final maxOverlap = baseWords.length < nextWords.length
        ? baseWords.length
        : nextWords.length;

    for (var n = maxOverlap; n >= 1; n--) {
      final baseTail =
          baseWords.sublist(baseWords.length - n).join(' ').toLowerCase();
      final nextHead = nextWords.sublist(0, n).join(' ').toLowerCase();
      if (baseTail == nextHead) {
        final rest = nextWords.sublist(n).join(' ');
        return rest.isEmpty ? base : '$base $rest';
      }
    }

    final needsSpace =
        !base.endsWith('.') &&
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
    var fixed = text;

    // Glosarium site IWIP / PT Weda Bay Nickel (nama & istilah jangan diacak STT).
    final domainFixes = <Pattern, String>{
      RegExp(
        r'\b(?:i\s*w\s*i\s*p|ewip|iwiip|iwhip)\b',
        caseSensitive: false,
      ): 'IWIP',
      RegExp(
        r'\bindonesia\s+(?:weda|widiay|widaya|wida)\s+bay\s+industrial\s+park\b',
        caseSensitive: false,
      ): 'Indonesia Weda Bay Industrial Park',
      RegExp(
        r'\b(?:p\.?\s*t\.?|pt|pity|peti|pee\s*tee)\s+'
        r'(?:weda|widiay|widaya|widiy?a?|widay|weday|veda|weeda|wida)\s+'
        r'(?:bay|bali|bye|bei|bai)\s+'
        r'(?:nickel|nikel|nikl|nickle)\b',
        caseSensitive: false,
      ): 'PT Weda Bay Nickel',
      RegExp(
        r'\b(?:weda|widiay|widaya|widiy?a?|widay|weday|veda|weeda|wida)\s+'
        r'(?:bay|bali|bye|bei|bai)\s+'
        r'(?:nickel|nikel|nikl|nickle)\b',
        caseSensitive: false,
      ): 'Weda Bay Nickel',
      RegExp(
        r'\b(?:halma\s*hera|halmahaera)\b',
        caseSensitive: false,
      ): 'Halmahera',
      RegExp(r'\b(?:h\s*s\s*e|hse)\b', caseSensitive: false): 'HSE',
      RegExp(r'\b(?:p\s*p\s*e|ppe)\b', caseSensitive: false): 'PPE',
      RegExp(r'\b(?:apd)\b', caseSensitive: false): 'APD',
      RegExp(
        r'\b(?:titik\s+kumpul|titik\s+kumpulan|muster\s+point)\b',
        caseSensitive: false,
      ): 'titik kumpul',
      RegExp(
        r'\b(?:alat\s+pelindung\s+diri)\b',
        caseSensitive: false,
      ): 'alat pelindung diri',
      RegExp(r'\b(?:smelter|smelder|smeltar)\b', caseSensitive: false): 'smelter',
      RegExp(r'\b(?:nikel|nickle)\b', caseSensitive: false): 'nikel',
    };

    for (final entry in domainFixes.entries) {
      fixed = fixed.replaceAll(entry.key, entry.value);
    }

    if (languageCode == 'id') {
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
        RegExp(
          r'\bmarel\s+(?:lontong|lantong|luntung|hontong)\b',
          caseSensitive: false,
        ): 'Marel Hontong',
      };
      for (final entry in replacements.entries) {
        fixed = fixed.replaceAll(entry.key, entry.value);
      }
      return fixed;
    }

    if (languageCode == 'en' && fixed.isNotEmpty) {
      return fixed[0].toUpperCase() + fixed.substring(1);
    }

    return fixed;
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
