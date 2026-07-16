/// Deteksi bahasa dari teks STT (heuristik lokal, tanpa package baru).
/// Fokus IWIP: id / en / zh.
class LanguageDetector {
  LanguageDetector._();

  static final _cjk = RegExp(r'[\u4e00-\u9fff]');
  static final _latinWord = RegExp(r'[A-Za-zÀ-ž]+');

  static const _idMarkers = {
    'yang',
    'dan',
    'dengan',
    'untuk',
    'tidak',
    'ada',
    'ini',
    'itu',
    'dari',
    'ke',
    'di',
    'sudah',
    'bisa',
    'akan',
    'kami',
    'kita',
    'anda',
    'saya',
    'tolong',
    'selamat',
    'apa',
    'bagaimana',
    'mengapa',
    'karena',
    'tetapi',
    'atau',
    'juga',
    'hari',
    'kerja',
    'silakan',
    'mohon',
    'segera',
    'area',
    'bahaya',
    'konveyor',
    'pengeboran',
    'peledakan',
    'bijih',
    'nikel',
    'smelter',
    'tungku',
    'helm',
    'izin',
    'titik',
    'kumpul',
    'pelindung',
  };

  static const _enMarkers = {
    'the',
    'and',
    'with',
    'for',
    'this',
    'that',
    'from',
    'have',
    'has',
    'are',
    'was',
    'were',
    'please',
    'what',
    'how',
    'why',
    'because',
    'but',
    'or',
    'also',
    'you',
    'we',
    'they',
    'need',
    'work',
    'safety',
    'danger',
    'area',
    'crusher',
    'conveyor',
    'stockpile',
    'smelter',
    'drilling',
    'excavator',
    'blasting',
    'nickel',
    'furnace',
    'helmet',
    'hazard',
    'permit',
  };

  /// Mengembalikan kode bahasa (`id`/`en`/`zh`/…) atau `null` jika tidak yakin.
  static String? detectLocal(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final cjk = _cjk.allMatches(trimmed).length;
    final letters = RegExp(r'[A-Za-z\u4e00-\u9fff]').allMatches(trimmed).length;
    if (letters == 0) return null;

    if (cjk / letters >= 0.25) return 'zh';

    final words = _latinWord
        .allMatches(trimmed.toLowerCase())
        .map((m) => m.group(0)!)
        .where((w) => w.length > 1)
        .toList();
    if (words.isEmpty) return null;

    var idScore = 0;
    var enScore = 0;
    for (final w in words) {
      if (_idMarkers.contains(w)) idScore++;
      if (_enMarkers.contains(w)) enScore++;
    }

    if (idScore == 0 && enScore == 0) {
      // Banyak kata Latin tanpa marker kuat → default Inggris lebih aman untuk STT online.
      return words.length >= 3 ? 'en' : null;
    }
    if (idScore >= enScore + 1) return 'id';
    if (enScore >= idScore + 1) return 'en';
    if (idScore > 0 && idScore == enScore) return 'id';
    return enScore > 0 ? 'en' : 'id';
  }
}
