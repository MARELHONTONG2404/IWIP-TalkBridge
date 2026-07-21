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

    // Normalisasi bahasa (slang, dsb)
    text = _applyLanguageNormalizations(text, languageCode);
    
    // Perjelas kata-kata multi-makna (polysemy) dengan sinonim eksplisit
    // agar mesin terjemahan menangkap konteks IT/Tambang secara akurat.
    text = _disambiguatePolysemy(text, languageCode);
    
    text = _normalizePunctuation(text);

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
        return _expandEnglishContractions(text);
      default:
        return text;
    }
  }

  static String _normalizeIndonesian(String text) {
    var normalized = text;

    // PENTING: Gunakan word-boundary (\b) pada SEMUA penggantian agar
    // tidak menimpa substring di tengah kata.
    // Contoh bug sebelumnya: "ga " → "tidak " bisa merusak "agar" → "tidakr"
    // Hanya ganti kata slang yang sangat umum & tidak ambigu.
    const replacements = <String, String>{
      // ── Kata informal → formal ─────────────────────────────────────────
      'gimana': 'bagaimana',
      'gmna': 'bagaimana',
      'gmn': 'bagaimana',
      'nggak': 'tidak',
      'gak': 'tidak',
      'gk': 'tidak',
      'udah': 'sudah',
      'udh': 'sudah',
      'blm': 'belum',
      'belom': 'belum',
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
      // ── Singkatan STT umum ──────────────────────────────────────────────
      'knp': 'kenapa',
      'brp': 'berapa',
      'jgn': 'jangan',
      'krn': 'karena',
      'tp': 'tapi',
      'sm': 'sama',
      'sblm': 'sebelum',
      'stlh': 'setelah',
      'bs': 'bisa',
      'tdk': 'tidak',
      'sdh': 'sudah',
      'blh': 'boleh',
      'dlm': 'dalam',
      'dr': 'dari',
      'utk': 'untuk',
      'krj': 'kerja',
      // ── Sapaan salah ejaan ──────────────────────────────────────────────
      'salamat pagi': 'Selamat pagi',
      'salamat siang': 'Selamat siang',
      'salamat sore': 'Selamat sore',
      'salamat malam': 'Selamat malam',
    };

    // CATATAN: "bgt"→"sangat" dan "banget"→"sangat" dihapus karena terlalu
    // agresif dan bisa mengubah nuansa kalimat. Demikian pula "bener"→"benar",
    // "ga "→"tidak " (tanpa boundary) dan beberapa lainnya.

    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(
        // Gunakan word-boundary eksplisit untuk setiap penggantian
        RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false),
        entry.value,
      );
    }

    return normalized;
  }

  static String _expandEnglishContractions(String text) {
    var expanded = text;
    const contractions = <String, String>{
      "don't": "do not",
      "Don't": "Do not",
      "doesn't": "does not",
      "Doesn't": "Does not",
      "didn't": "did not",
      "Didn't": "Did not",
      "won't": "will not",
      "Won't": "Will not",
      "can't": "cannot",
      "Can't": "Cannot",
      "wasn't": "was not",
      "Wasn't": "Was not",
      "weren't": "were not",
      "Weren't": "Were not",
      "isn't": "is not",
      "Isn't": "Is not",
      "aren't": "are not",
      "Aren't": "Are not",
      "haven't": "have not",
      "Haven't": "Have not",
      "hasn't": "has not",
      "Hasn't": "Has not",
      "hadn't": "had not",
      "Hadn't": "Had not",
      "shouldn't": "should not",
      "Shouldn't": "Should not",
      "wouldn't": "would not",
      "Wouldn't": "Would not",
      "couldn't": "could not",
      "Couldn't": "Could not",
      "mustn't": "must not",
      "Mustn't": "Must not",
      "I'm": "I am",
      "i'm": "i am",
      "you're": "you are",
      "You're": "You are",
      "we're": "we are",
      "We're": "We are",
      "they're": "they are",
      "They're": "They are",
      "he's": "he is",
      "He's": "He is",
      "she's": "she is",
      "She's": "She is",
      "it's": "it is",
      "It's": "It is",
      "I've": "I have",
      "you've": "you have",
      "You've": "You have",
      "we've": "we have",
      "We've": "We have",
      "they've": "they have",
      "They've": "They have",
      "I'd": "I would",
      "you'd": "you would",
      "You'd": "You would",
      "we'd": "we would",
      "We'd": "We would",
      "they'd": "they would",
      "They'd": "They would",
      "he'd": "he would",
      "He'd": "He would",
      "she'd": "she would",
      "She'd": "She would",
      "I'll": "I will",
      "you'll": "you will",
      "You'll": "You will",
      "we'll": "we will",
      "We'll": "We will",
      "they'll": "they will",
      "They'll": "They will",
      "he'll": "he will",
      "He'll": "He will",
      "she'll": "she will",
      "She'll": "She will",
      "it'll": "it will",
      "It'll": "It will",
      "that's": "that is",
      "That's": "That is",
      "there's": "there is",
      "There's": "There is",
      "what's": "what is",
      "What's": "What is",
      "who's": "who is",
      "Who's": "Who is",
      "let's": "let us",
      "Let's": "let us",
    };

    for (final entry in contractions.entries) {
      expanded = expanded.replaceAll(
        RegExp(r'\b' + RegExp.escape(entry.key) + r'\b'),
        entry.value,
      );
    }

    return expanded;
  }

  static String _disambiguatePolysemy(String text, String languageCode) {
    var result = text;
    
    if (languageCode == 'id') {
      // Anchoring arti kata untuk bahasa Indonesia agar diterjemahkan 
      // dengan benar ke bahasa target (terutama IT & Tambang).
      final disambiguations = <String, String>{
        // Kata -> Sinonim yang lebih spesifik agar engine tidak salah menebak
        'aplikasi': 'program aplikasi', // Mencegah arti "surat lamaran"
        'project': 'proyek pekerjaan', // Mencegah arti acak
        'proyek': 'proyek pekerjaan',
        'account': 'akun pengguna', // Mencegah arti "rekening/laporan"
        'akun': 'akun pengguna',
        'database': 'basis data', // 100% selalu diterjemahkan "database"
        'plant': 'pabrik', // Mencegah arti "tanaman"
        'mining': 'pertambangan', 
        'tambang': 'pertambangan',
        'server': 'server sistem',
      };

      for (final entry in disambiguations.entries) {
        result = result.replaceAll(
          RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false),
          entry.value,
        );
      }
    } else if (languageCode == 'en') {
      final disambiguations = <String, String>{
        'application': 'software application',
        'plant': 'factory plant',
      };
      for (final entry in disambiguations.entries) {
        result = result.replaceAll(
          RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false),
          entry.value,
        );
      }
    }

    return result;
  }
}
