import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'translation_service.dart'; // Untuk mendapatkan TranslationException

class BaiduFanyiService {
  // Ganti dengan kredensial Baidu Anda
  static const _appId = 'YOUR_BAIDU_FANYI_APP_ID';
  static const _secretKey = 'YOUR_BAIDU_FANYI_SECRET_KEY';
  
  static const _apiUrl = 'https://fanyi-api.baidu.com/api/trans/vip/translate';

  static String _generateSign(String query, String salt) {
    final str = '$_appId$query$salt$_secretKey';
    return md5.convert(utf8.encode(str)).toString();
  }

  /// Memanggil Baidu Fanyi API.
  /// Mendukung auto-detection, namun sebaiknya 'from' dan 'to' diset secara spesifik.
  Future<String> translate(String text, String from, String to) async {
    if (_appId == 'YOUR_BAIDU_FANYI_APP_ID' || _appId.isEmpty) {
      throw const TranslationException('Baidu Fanyi APP_ID belum dikonfigurasi.');
    }
    
    // Map kode bahasa standar ke format Baidu
    final baiduFrom = _mapToBaiduCode(from);
    final baiduTo = _mapToBaiduCode(to);
    
    final salt = Random().nextInt(100000).toString();
    final sign = _generateSign(text, salt);
    
    final uri = Uri.parse(_apiUrl).replace(queryParameters: {
      'q': text,
      'from': baiduFrom,
      'to': baiduTo,
      'appid': _appId,
      'salt': salt,
      'sign': sign,
    });
    
    if (kDebugMode) {
      debugPrint('[Baidu Fanyi] Request URL: $uri');
    }

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        throw TranslationException('Baidu Fanyi HTTP Error: ${response.statusCode}');
      }
      
      final data = jsonDecode(response.body);
      
      if (data.containsKey('error_code')) {
        final errorCode = data['error_code'].toString();
        final errorMsg = data['error_msg'] ?? 'Unknown Error';
        throw TranslationException('Baidu Fanyi API Error ($errorCode): $errorMsg');
      }
      
      final transResult = data['trans_result'] as List?;
      if (transResult == null || transResult.isEmpty) {
        throw const TranslationException('Baidu Fanyi: Hasil terjemahan kosong');
      }
      
      // Gabungkan hasil jika teks terdiri dari beberapa baris
      final resultLines = transResult.map((e) => e['dst'].toString()).toList();
      return resultLines.join('\n');
      
    } catch (e) {
      if (e is TranslationException) rethrow;
      throw TranslationException('Gagal menghubungi Baidu Fanyi: $e');
    }
  }

  static String _mapToBaiduCode(String code) {
    // Baidu menggunakan 'zh' untuk Simplified Chinese, 'en' untuk English, 'id' untuk Indonesian
    if (code.toLowerCase() == 'id' || code.toLowerCase() == 'id-id') return 'id';
    if (code.toLowerCase() == 'zh' || code.toLowerCase() == 'zh-cn') return 'zh';
    if (code.toLowerCase() == 'en' || code.toLowerCase() == 'en-us') return 'en';
    if (code.toLowerCase() == 'auto') return 'auto';
    return code; // Fallback ke kode asal
  }
}
