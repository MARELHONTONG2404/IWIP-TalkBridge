import 'package:flutter_test/flutter_test.dart';

import 'package:ilb/core/services/speech_text_processor.dart';

void main() {
  group('SpeechTextProcessor', () {
    test('corrects the common phonetic misrecognition of Marel Hontong', () {
      expect(
        SpeechTextProcessor.postProcess(
          'halo perkenalkan nama saya marel lontong',
          'id',
        ),
        'Halo perkenalkan nama saya Marel Hontong',
      );
    });
  });
}
