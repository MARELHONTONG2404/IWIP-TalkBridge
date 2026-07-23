import 'dart:io';

void main() async {
  final inputPath = r'C:\Users\NITRO\.gemini\antigravity\brain\8f9b2f21-26fd-4e61-ba1b-0c39d113aaeb\iwip_talkbridge_logo_v2_1784612629683.jpg';
  final outputPath = r'd:\Projects\IWIP-TalkBridge\assets\images\iwip_logo_v2.jpg';
  
  final bytes = await File(inputPath).readAsBytes();
  
  await File(outputPath).writeAsBytes(bytes);
}
