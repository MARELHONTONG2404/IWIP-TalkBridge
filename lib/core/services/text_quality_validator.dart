class TextQualityValidator {
  TextQualityValidator._();

  /// Validates OCR text quality based on several heuristic rules.
  /// Returns [true] if the text is deemed valid and translatable, [false] otherwise.
  static bool isValid({
    required String text,
    double? confidence,
    double minConfidence = 0.65,
  }) {
    final trimmed = text.trim();

    // 1. Minimum text length (increased to 5 for better stability)
    if (trimmed.length < 5) return false;

    // 2. OCR Confidence
    if (confidence != null && confidence < minConfidence) return false;

    // Remove all whitespace to check character density
    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 4) return false;

    // 3. Ratio of letters to symbols
    final lettersAndNumbers = RegExp(r'[A-Za-z0-9\u00C0-\u024F\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]').allMatches(compact).length;
    final symbolCount = compact.length - lettersAndNumbers;
    
    // Stricter: if symbols are more than 40% of the text, likely noise
    if (symbolCount / compact.length > 0.4) return false;

    // 4. Heuristic for "Random noise" / Gibberish
    // Reject strings with too many mixed case/consonants that look like noise
    final upperCaseCount = RegExp(r'[A-Z]').allMatches(compact).length;
    if (upperCaseCount > compact.length * 0.7) return false; // Too many uppercase

    // 5. CJK check & Word validation
    final hasCjk = RegExp(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]').hasMatch(trimmed);

    if (!hasCjk) {
      final words = trimmed.split(RegExp(r'\s+'));
      int validWordCount = 0;

      for (final word in words) {
        if (word.length < 2) continue;
        
        final wordLetters = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
        if (wordLetters.isEmpty) continue;

        // Simple vowel check for latin text
        final vowels = RegExp(r'[aeiouAEIOU]').allMatches(wordLetters).length;
        if (wordLetters.length > 3 && vowels == 0) continue; // Likely gibberish
        
        validWordCount++;
      }

      // If less than 30% of words look valid, reject
      if (words.isNotEmpty && (validWordCount / words.length) < 0.3) return false;
    }

    return true;
  }
}
