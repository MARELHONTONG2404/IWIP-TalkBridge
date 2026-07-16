import '../data/iwip_mining_glossary.dart';

/// Normalisasi istilah site IWIP sebelum/sesudah terjemahan.
class IwipGlossaryProcessor {
  IwipGlossaryProcessor._();

  static String normalizeSource(String text, String languageCode) {
    var result = text;
    for (final entry in kIwipMiningGlossary) {
      result = _replaceVariants(result, entry, languageCode);
    }
    return result;
  }

  static String applyToTranslation({
    required String source,
    required String translated,
    required String from,
    required String to,
  }) {
    var result = translated;
    for (final entry in kIwipMiningGlossary) {
      if (!_sourceContainsEntry(source, entry, from)) continue;
      final expected = _termForLang(entry, to);
      if (expected.isEmpty) continue;
      // Pastikan istilah teknis di hasil terjemahan sesuai glosarium IWIP.
      final wrongForms = _allWrongForms(entry, to);
      for (final wrong in wrongForms) {
        if (wrong.isEmpty) continue;
        result = result.replaceAll(
          RegExp(RegExp.escape(wrong), caseSensitive: false),
          expected,
        );
      }
    }
    return result;
  }

  static String _replaceVariants(
    String text,
    MiningGlossaryEntry entry,
    String lang,
  ) {
    var result = text;
    final canonical = _termForLang(entry, lang);
    if (canonical.isEmpty) return result;

    final variants = <String>[
      ...entry.idVariants,
      ...entry.enVariants,
      entry.id,
      entry.en,
      entry.zh,
    ];

    for (final variant in variants) {
      if (variant.toLowerCase() == canonical.toLowerCase()) continue;
      result = result.replaceAll(
        RegExp(r'\b' + RegExp.escape(variant) + r'\b', caseSensitive: false),
        canonical,
      );
    }
    return result;
  }

  static bool _sourceContainsEntry(
    String source,
    MiningGlossaryEntry entry,
    String from,
  ) {
    final terms = <String>[
      _termForLang(entry, from),
      ...entry.idVariants,
      ...entry.enVariants,
      entry.id,
      entry.en,
      entry.zh,
    ];
    final lower = source.toLowerCase();
    for (final t in terms) {
      if (t.isNotEmpty && lower.contains(t.toLowerCase())) return true;
    }
    return false;
  }

  static String _termForLang(MiningGlossaryEntry entry, String code) {
    switch (code) {
      case 'id':
        return entry.id;
      case 'en':
        return entry.en;
      case 'zh':
        return entry.zh;
      default:
        return entry.en;
    }
  }

  static List<String> _allWrongForms(MiningGlossaryEntry entry, String to) {
    final expected = _termForLang(entry, to).toLowerCase();
    final all = <String>[
      entry.id,
      entry.en,
      entry.zh,
      ...entry.idVariants,
      ...entry.enVariants,
    ];
    return all.where((t) => t.toLowerCase() != expected).toList();
  }
}
