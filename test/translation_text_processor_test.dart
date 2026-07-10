import 'package:flutter_test/flutter_test.dart';

import 'package:ilb/core/services/translation_text_processor.dart';

void main() {
  group('TranslationTextProcessor', () {
    test('normalizes informal Indonesian before translation', () {
      const input = 'Gimana caranya biar gak salah terjemahan?';
      const expected = 'bagaimana caranya biar tidak salah terjemahan?';

      expect(
        TranslationTextProcessor.prepare(input, 'id'),
        expected,
      );
    });

    test('fixes common Indonesian speech mistakes', () {
      expect(
        TranslationTextProcessor.prepare('makasih ya udah bantu', 'id'),
        'terima kasih ya sudah bantu',
      );
    });

    test('normalizes punctuation spacing', () {
      expect(
        TranslationTextProcessor.prepare('Halo , apa kabar ?', 'id'),
        'Halo, apa kabar?',
      );
    });

    test('expands English contractions for clearer translation', () {
      expect(
        TranslationTextProcessor.prepare("I don't know what you're saying", 'en'),
        'I do not know what you are saying',
      );
    });

    test('returns empty for blank input', () {
      expect(TranslationTextProcessor.prepare('   ', 'id'), '');
    });
  });
}
