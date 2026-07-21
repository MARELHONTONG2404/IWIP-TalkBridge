/// Deteksi bahasa dari teks STT (heuristik lokal, tanpa package baru).
///
/// Mendukung semua pasangan bahasa melalui parameter [detectForSession].
/// Marker heuristik difokuskan pada id/en/zh karena ketiga bahasa ini
/// memiliki karakteristik teks paling berbeda; bahasa lain diserahkan ke
/// API online via [priorityCodes] hints.
class LanguageDetector {
  LanguageDetector._();

  static final _cjk = RegExp(r'[\u4e00-\u9fff]');
  static final _latinWord = RegExp(r'[A-Za-zÀ-ž]+');

  // ── Marker Indonesia ──────────────────────────────────────────────────────
  // Kata-kata yang sangat khas Indonesia (bobot 2) — hampir tidak pernah
  // muncul dalam kalimat Inggris.
  static const _idStrongMarkers = {
    'yang',
    'dengan',
    'untuk',
    'tidak',
    'dari',
    'sudah',
    'akan',
    'kami',
    'kita',
    'anda',
    'saya',
    'tolong',
    'selamat',
    'bagaimana',
    'mengapa',
    'karena',
    'tetapi',
    'juga',
    'silakan',
    'mohon',
    'segera',
    'belum',
    'jangan',
    'pakai',
    'masuk',
    'keluar',
    'boleh',
    'harus',
    'sedang',
    'pernah',
    'saja',
    'bahaya',
    'nikel',
    'izin',
    'pelindung',
  };

  // Kata Indonesia yang lebih umum (bobot 1) — bisa overlap dengan bahasa lain
  // tapi tetap indikator berguna.
  static const _idWeakMarkers = {
    'dan',
    'ada',
    'ini',
    'itu',
    'ke',
    'di',
    'bisa',
    'apa',
    'atau',
    'hari',
    'kerja',
    'lagi',
    'sini',
    'situ',
    'mana',
    'dekat',
    'jauh',
    'konveyor',
    'pengeboran',
    'peledakan',
    'bijih',
    'smelter',
    'tungku',
    'helm',
    'titik',
    'kumpul',
  };

  // ── Marker English ────────────────────────────────────────────────────────
  // Kata-kata yang sangat khas Inggris (bobot 2).
  static const _enStrongMarkers = {
    'the',
    'was',
    'were',
    'have',
    'has',
    'been',
    'would',
    'could',
    'should',
    'please',
    'because',
    'there',
    'where',
    'when',
    'what',
    'they',
    'their',
    'these',
    'those',
    'which',
    'about',
    'into',
    'safety',
    'danger',
    'hazard',
    'permit',
    'nickel',
    'furnace',
    'helmet',
  };

  // Kata Inggris yang lebih umum (bobot 1).
  static const _enWeakMarkers = {
    'and',
    'with',
    'for',
    'this',
    'that',
    'from',
    'are',
    'but',
    'or',
    'also',
    'you',
    'we',
    'need',
    'work',
    'how',
    'why',
    'can',
    'will',
    'must',
    'here',
    'done',
    'make',
    'take',
    'crusher',
    'conveyor',
    'stockpile',
    'smelter',
    'drilling',
    'excavator',
    'blasting',
  };

  /// Mengembalikan kode bahasa (`id`/`en`/`zh`/…) atau `null` jika tidak yakin.
  ///
  /// [priorityCodes] — kode bahasa yang diutamakan (mis. dari sesi interpreter).
  /// Jika teks tidak mengandung marker kuat dan salah satu kode ada di
  /// [priorityCodes], kode tersebut akan dikembalikan sebagai fallback sebelum
  /// menyerahkan ke API online.
  static String? detectLocal(String text, {List<String>? priorityCodes}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final cjk = _cjk.allMatches(trimmed).length;
    final letters = RegExp(r'[A-Za-z\u4e00-\u9fff]').allMatches(trimmed).length;
    if (letters == 0) return null;

    // CJK dominan → Mandarin (atau bahasa CJK lain jika ada di prioritas).
    if (cjk / letters >= 0.25) {
      // Jika ada bahasa CJK lain (ja, ko) di prioritas, periksa dulu.
      if (priorityCodes != null) {
        for (final code in priorityCodes) {
          if (code == 'ja' || code == 'ko' || code == 'zh') {
            // Biarkan API online yang membedakan ja/ko/zh;
            // heuristik kita tidak cukup akurat untuk membedakan.
            return null;
          }
        }
      }
      return 'zh';
    }

    final words = _latinWord
        .allMatches(trimmed.toLowerCase())
        .map((m) => m.group(0)!)
        .where((w) => w.length > 1)
        .toList();
    if (words.isEmpty) return null;

    // Weighted scoring: strong marker = 2 poin, weak marker = 1 poin.
    var idScore = 0;
    var enScore = 0;
    for (final w in words) {
      if (_idStrongMarkers.contains(w)) {
        idScore += 2;
      } else if (_idWeakMarkers.contains(w)) {
        idScore += 1;
      }
      if (_enStrongMarkers.contains(w)) {
        enScore += 2;
      } else if (_enWeakMarkers.contains(w)) {
        enScore += 1;
      }
    }

    if (idScore == 0 && enScore == 0) {
      // Tidak ada marker kuat. Jika sesi hanya melibatkan dua bahasa
      // Latin non-id/non-en (mis. es↔fr), serahkan ke API.
      if (priorityCodes != null &&
          !priorityCodes.contains('id') &&
          !priorityCodes.contains('en')) {
        return null;
      }
      // Default: Inggris lebih aman untuk STT online jika >=3 kata.
      return words.length >= 3 ? 'en' : null;
    }

    // Butuh selisih minimal 2 poin agar yakin; jika seri atau selisih 1,
    // prioritaskan Indonesia (konteks IWIP = site Indonesia).
    if (idScore >= enScore + 2) return 'id';
    if (enScore >= idScore + 2) return 'en';
    // Selisih kecil / seri.
    if (idScore > 0) return 'id';
    return enScore > 0 ? 'en' : 'id';
  }

  /// Deteksi bahasa khusus untuk sesi interpreter dengan dua bahasa tetap.
  ///
  /// Mengembalikan `langACode` atau `langBCode` berdasarkan analisis teks.
  /// Jika tidak yakin, mengembalikan `null` (serahkan ke API online).
  /// Jika API online juga tidak digunakan, fallback ke [defaultCode].
  static String? detectForSession(
    String text, {
    required String langACode,
    required String langBCode,
    String? defaultCode,
  }) {
    final priorityCodes = [langACode, langBCode];

    // Gunakan deteksi lokal dengan hints sesi.
    final local = detectLocal(text, priorityCodes: priorityCodes);

    // Jika hasil deteksi cocok dengan salah satu bahasa sesi, kembalikan.
    if (local != null) {
      if (local == langACode) return langACode;
      if (local == langBCode) return langBCode;

      // Hasil deteksi bukan salah satu dari dua bahasa sesi.
      // Dalam konteks interpreter, default ke bahasa A.
      return defaultCode ?? langACode;
    }

    return null; // Serahkan ke API online.
  }
}
