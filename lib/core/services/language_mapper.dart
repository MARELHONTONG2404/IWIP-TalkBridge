class LanguageMapper {
  /// Memeriksa apakah input bermakna 'auto detect'.
  static bool isAuto(String? input) {
    if (input == null) return true;
    final lower = input.trim().toLowerCase();
    return lower.isEmpty ||
        lower == 'auto' ||
        lower == 'auto detect' ||
        lower == 'unknown';
  }

  /// Memetakan berbagai variasi kode bahasa ke ISO 639-1 yang valid.
  static String mapToIso(String input) {
    if (isAuto(input)) {
      throw Exception('Cannot map AUTO to ISO code directly. Detect language first.');
    }
    
    final lower = input.trim().toLowerCase();
    
    // Explicit mappings for API compatibility
    if (lower.startsWith('zh') || lower == 'chinese' || lower == 'cmn') {
      return 'zh-CN';
    }
    if (lower.startsWith('en') || lower == 'english') return 'en';
    if (lower.startsWith('id') || lower == 'in' || lower == 'indonesia') return 'id';
    if (lower.startsWith('ja') || lower == 'japanese') return 'ja';
    if (lower.startsWith('ko') || lower == 'korean') return 'ko';
    if (lower.startsWith('ar') || lower == 'arabic') return 'ar';
    if (lower.startsWith('fr') || lower == 'french') return 'fr';
    if (lower.startsWith('de') || lower == 'german') return 'de';
    if (lower.startsWith('es') || lower == 'spanish') return 'es';
    if (lower.startsWith('ru') || lower == 'russian') return 'ru';
    
    if (lower.contains('-')) {
      return input.trim();
    }
    if (lower.length == 2) {
      return lower;
    }

    return input.trim();
  }
}
