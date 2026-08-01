// ignore_for_file: avoid_print
import 'package:ilb/core/services/translation_service.dart';

void main() async {
  print('--- Memulai Uji TranslationService ---');
  final service = TranslationService();

  // Test 1: Deteksi Bahasa
  final detZh = await service.detectLanguage('你好，我在找项目经理。');
  print('Deteksi Mandarin: $detZh'); // Ekspektasi: zh
  
  final detId = await service.detectLanguage('Apakah excavator sudah siap di pit?');
  print('Deteksi Indonesia: $detId'); // Ekspektasi: id

  // Test 2: Terjemahan tanpa GEMINI_API_KEY (akan fallback ke Google/MyMemory)
  print('\n--- Menguji Terjemahan Fallback ---');
  try {
    final resultIdToZh = await service.translate(
      text: 'Tolong pastikan aplikasi berjalan di server.',
      from: 'id',
      to: 'zh',
    );
    print('ID -> ZH: $resultIdToZh');

    final resultZhToId = await service.translate(
      text: '请穿戴好安全帽和个人防护装备。',
      from: 'zh',
      to: 'id',
    );
    print('ZH -> ID: $resultZhToId');
  } catch (e) {
    print('Error Terjemahan: $e');
  }

  print('\n--- Uji Selesai ---');
}
