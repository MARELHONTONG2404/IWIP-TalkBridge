class TranslationTextProcessor {
  static const _unsafeMarkers = [
    'camerax',
    'camera2',
    'androidx.camera',
    'stacktrace',
    'stack trace',
    'fatal exception',
    'flutter.',
    'exception:',
    'error_network',
    'socketexception',
  ];

  static String prepare(String raw, String languageCode) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    text = _stripControlChars(text);
    text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
    if (text.isEmpty) return '';

    if (_looksUnsafe(text)) return '';

    text = _normalizePunctuation(text);
    text = _applyLanguageNormalizations(text, languageCode);

    return text.trim();
  }

  static bool isSafeToTranslate(String raw) {
    final text = _stripControlChars(raw.trim());
    if (text.isEmpty) return false;
    return !_looksUnsafe(text);
  }

  static String _stripControlChars(String text) {
    return text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  }

  static bool _looksUnsafe(String text) {
    final lower = text.toLowerCase();
    for (final m in _unsafeMarkers) {
      if (lower.contains(m)) return true;
    }
    final lines = text.split('\n');
    if (lines.length >= 3) {
      final logLike =
          lines.where((l) => RegExp(r'^[VDIWEF]/').hasMatch(l.trim())).length;
      if (logLike >= 2) return true;
    }
    return false;
  }

  static String _normalizePunctuation(String text) {
    var normalized = text.replaceAllMapped(
      RegExp(r'\s+([,.!?;:])'),
      (match) => match.group(1)!,
    );

    normalized = normalized
        .replaceAll(RegExp(r'\.{3,}'), '...')
        .replaceAll(RegExp(r'\?{2,}'), '?')
        .replaceAll(RegExp(r'!{2,}'), '!');

    normalized = normalized.replaceAllMapped(
      RegExp(r'([,.!?;:])([^\s])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return normalized;
  }

  static String _applyLanguageNormalizations(String text, String languageCode) {
    switch (languageCode) {
      case 'id':
        return _normalizeIndonesian(text);
      case 'en':
        return _normalizeEnglish(text);
      default:
        return text;
    }
  }

  static String _normalizeIndonesian(String text) {
    var normalized = text;

    const replacements = <String, String>{
      'gimana': 'bagaimana',
      'gmna': 'bagaimana',
      'gmn': 'bagaimana',
      'nggak': 'tidak',
      'gak': 'tidak',
      'ga ': 'tidak ',
      'gk': 'tidak',
      'udah': 'sudah',
      'udh': 'sudah',
      'blm': 'belum',
      'belom': 'belum',
      'bgt': 'sangat',
      'banget': 'sangat',
      'bener': 'benar',
      'beneran': 'benar',
      'kalo': 'kalau',
      'dgn': 'dengan',
      'dpt': 'dapat',
      'hrs': 'harus',
      'tgl': 'tanggal',
      'org': 'orang',
      'yg': 'yang',
      'sy': 'saya',
      'gue': 'saya',
      'gw': 'saya',
      'lu': 'kamu',
      'lo': 'kamu',
      'km': 'kamu',
      'makasih': 'terima kasih',
      'trimakasih': 'terima kasih',
      'terimakasih': 'terima kasih',
      'salamat pagi': 'Selamat pagi',
      'salamat siang': 'Selamat siang',
      'salamat sore': 'Selamat sore',
      'salamat malam': 'Selamat malam',
    };

    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b', caseSensitive: false),
        entry.value,
      );
    }

    return normalized;
  }

  static String _normalizeEnglish(String text) {
    var normalized = text;

    const contractions = <String, String>{
      "don't": 'do not',
      "doesn't": 'does not',
      "didn't": 'did not',
      "can't": 'cannot',
      "won't": 'will not',
      "i'm": 'I am',
      "you're": 'you are',
      "we're": 'we are',
      "they're": 'they are',
      "it's": 'it is',
      "that's": 'that is',
      "what's": 'what is',
      "i've": 'I have',
      "i'll": 'I will',
      "i'd": 'I would',
    };

    for (final entry in contractions.entries) {
      normalized = normalized.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b', caseSensitive: false),
        entry.value,
      );
    }

    return normalized;
  }
}
