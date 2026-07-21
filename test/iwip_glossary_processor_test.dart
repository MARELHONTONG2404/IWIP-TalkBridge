import 'package:flutter_test/flutter_test.dart';
import 'package:ilb/core/services/iwip_glossary_processor.dart';

void main() {
  group('IwipGlossaryProcessor', () {
    test('corrects wrong translations for "aplikasi" to canonical terms', () {
      // In Indonesian: 'permohonan' or 'lamaran' -> 'aplikasi'
      expect(
        IwipGlossaryProcessor.postProcessGlossary(
          'Tolong buka permohonan ini di hp Anda.',
          'id',
        ),
        'Tolong buka aplikasi ini di hp Anda.',
      );
      
      expect(
        IwipGlossaryProcessor.postProcessGlossary(
          'Saya mengirim lamaran baru.',
          'id',
        ),
        'Saya mengirim aplikasi baru.',
      );

      // In Chinese: '申请' (apply/request) -> '应用程序' (software application)
      expect(
        IwipGlossaryProcessor.postProcessGlossary(
          '请打开这个申请。',
          'zh',
        ),
        '请打开这个应用程序。',
      );
    });

    test('replaces wrong translations using word boundaries for non-CJK', () {
      // English: 'apply' -> 'application'
      expect(
        IwipGlossaryProcessor.postProcessGlossary(
          'Please install this apply on the server.',
          'en',
        ),
        'Please install this application on the server.',
      );

      // Check that it doesn't replace substrings (like "applying" or "misapplied")
      expect(
        IwipGlossaryProcessor.postProcessGlossary(
          'I am applying for a job.',
          'en',
        ),
        'I am applying for a job.',
      );
    });

    test('does not touch or mask pronouns like Saya, Pak, Bapak', () {
      // Since masking is removed, postProcessGlossary should leave common pronouns completely untouched.
      const sentenceId = 'Saya sedang berbicara dengan Pak Marel.';
      expect(
        IwipGlossaryProcessor.postProcessGlossary(sentenceId, 'id'),
        sentenceId,
      );

      const sentenceEn = 'I am speaking with Mr. Marel.';
      expect(
        IwipGlossaryProcessor.postProcessGlossary(sentenceEn, 'en'),
        sentenceEn,
      );

      const sentenceZh = '我正在和 Marel 先生说话。';
      expect(
        IwipGlossaryProcessor.postProcessGlossary(sentenceZh, 'zh'),
        sentenceZh,
      );
    });
  });
}
