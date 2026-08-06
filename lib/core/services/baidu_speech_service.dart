import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class BaiduSpeechService {
  // TODO: Isi dengan kredensial Baidu Anda
  static const String _appId = 'MASUKKAN_APP_ID_ANDA';
  static const String _apiKey = 'MASUKKAN_API_KEY_ANDA';
  static const String _secretKey = 'MASUKKAN_SECRET_KEY_ANDA';

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// 1. Mengambil Access Token dari Baidu
  Future<bool> _fetchAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return true; // Token masih berlaku
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=$_apiKey&client_secret=$_secretKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return true;
      }
    } catch (e) {
      debugPrint('Error fetch Baidu STT token: $e');
    }
    return false;
  }

  /// 2. Mengirim file audio (.pcm / .wav) ke Baidu STT API
  /// 
  /// [audioBytes] adalah data audio format PCM/WAV 16k rate.
  /// [format] biasanya 'pcm' atau 'wav'.
  /// [devPid] adalah kode bahasa (1537 = Mandarin standar, 1536 = Mandarin sederhana).
  Future<String?> recognizeSpeech(
    List<int> audioBytes, {
    String format = 'pcm',
    int rate = 16000,
    int devPid = 1537,
  }) async {
    final hasToken = await _fetchAccessToken();
    if (!hasToken) return null;

    final url = 'https://vop.baidu.com/server_api?dev_pid=$devPid&cuid=iwip_app&token=$_accessToken';
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'audio/$format; rate=$rate',
        },
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['err_no'] == 0 && data['result'] != null) {
          final results = data['result'] as List;
          if (results.isNotEmpty) {
            return results.first.toString();
          }
        } else {
          debugPrint('Baidu STT API Error: ${data['err_msg']}');
        }
      }
    } catch (e) {
      debugPrint('Exception in Baidu STT request: $e');
    }
    return null;
  }
}
