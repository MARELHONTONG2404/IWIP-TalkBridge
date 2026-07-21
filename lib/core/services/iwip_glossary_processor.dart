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
