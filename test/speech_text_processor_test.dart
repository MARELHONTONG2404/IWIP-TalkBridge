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

    test('corrects PT Weda Bay Nickel misheard as widiay bali nickel', () {
      expect(
        SpeechTextProcessor.postProcess('pt widiay bali nickel', 'id'),
        'PT Weda Bay Nickel',
      );
      expect(
        SpeechTextProcessor.postProcess('widiay bali nickel', 'id'),
        'Weda Bay Nickel',
      );
    });

    test('leaves unrelated speech unchanged', () {
      expect(
        SpeechTextProcessor.postProcess(
          'saya mau pergi ke bali dan beli nickel baterai',
          'id',
        ),
        'Saya mau pergi ke bali dan beli nickel baterai',
      );
      expect(
        SpeechTextProcessor.postProcess('how long will it take', 'en'),
        'How long will it take',
      );
    });
  });
}
