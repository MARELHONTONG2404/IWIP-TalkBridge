import '../data/iwip_mining_glossary.dart';

/// Normalisasi istilah site IWIP sebelum/sesudah terjemahan.
class IwipGlossaryProcessor {
  IwipGlossaryProcessor._();

  /// Melakukan koreksi terhadap hasil terjemahan berdasarkan glosarium.
  /// Berguna untuk mengganti kata yang sering salah diterjemahkan (mis. "aplikasi" -> "permohonan").
  static String postProcessGlossary(String translated, String toCode) {
    var result = translated;

    for (final entry in kIwipMiningGlossary) {
      if (entry.wrongTranslations.isEmpty) continue;

      final canonicalTo = _termForLang(entry, toCode);
      if (canonicalTo.isEmpty) continue;

      for (final wrong in entry.wrongTranslations) {
        if (wrong.trim().isEmpty) continue;

        // Gunakan word boundary untuk bahasa yang menggunakan spasi (id, en, dll.)
        // Untuk Mandarin/CJK, word boundary tidak berfungsi dengan cara yang sama, jadi gunakan pencarian langsung.
        final isCjk = RegExp(r'[\u4e00-\u9fff]').hasMatch(wrong);
        final pattern = isCjk
            ? RegExp(RegExp.escape(wrong), caseSensitive: false)
            : RegExp(r'\b' + RegExp.escape(wrong) + r'\b', caseSensitive: false);

        result = result.replaceAll(pattern, canonicalTo);
      }
    }

    return _postProcessGrammar(result, toCode);
  }

  static String _postProcessGrammar(String text, String toCode) {
    var result = text;
    if (toCode == 'zh') {
      // Perbaikan tata bahasa kontekstual spesifik untuk terjemahan harfiah Mandarin.
      // Jangan gunakan replace statis berlebihan, hanya struktur yang pasti salah di lingkungan pabrik lisan.
      const grammarCorrections = {
        '正在进工作': '正在上班', // "sedang masuk kerja" -> "sedang bekerja/shift"
        '去工作': '去上班', // "pergi kerja" -> "pergi shift/bekerja"
        '你在哪里': '您在哪儿', // Lebih sopan di site
        '我在找': '我正在找', // "saya cari" -> "saya sedang cari"
        '请你': '请您', // Lebih sopan
      };

      for (final entry in grammarCorrections.entries) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }
    return result;
  }

  static String _termForLang(MiningGlossaryEntry entry, String lang) {
    switch (lang) {
      case 'id':
        return entry.id;
      case 'en':
        return entry.en;
      case 'zh':
        return entry.zh;
      default:
        return '';
    }
  }
}
