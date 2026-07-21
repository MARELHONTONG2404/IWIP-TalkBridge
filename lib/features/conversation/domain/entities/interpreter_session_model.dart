import '../../../language/data/language_model.dart';

/// Model immutable untuk satu sesi Auto Interpreter.
///
/// Dibuat sekali saat user memilih bahasa di [InterpreterSessionPage]
/// dan tidak pernah berubah selama sesi berlangsung.
///
/// Desain ini mendukung extensibility untuk fitur masa depan:
/// - Group Conversation  → tambah `List<LanguageModel> participants`
/// - Meeting Interpreter → tambah `String meetingId`, `List<String> roles`
/// - Offline Translation → cukup tambah flag `bool offlineMode`
class InterpreterSessionModel {
  /// Bahasa pembicara pertama (sisi kiri / "Bahasa Anda").
  final LanguageModel languageA;

  /// Bahasa pembicara kedua (sisi kanan / "Bahasa Lawan Bicara").
  final LanguageModel languageB;

  /// Identifier unik sesi — berguna untuk logging dan analytics.
  final String sessionId;

  /// Waktu sesi dimulai.
  final DateTime startedAt;

  const InterpreterSessionModel({
    required this.languageA,
    required this.languageB,
    required this.sessionId,
    required this.startedAt,
  });

  /// Factory helper — buat sesi baru dengan ID dan timestamp sekarang.
  factory InterpreterSessionModel.create({
    required LanguageModel languageA,
    required LanguageModel languageB,
  }) {
    return InterpreterSessionModel(
      languageA: languageA,
      languageB: languageB,
      sessionId: _generateId(),
      startedAt: DateTime.now(),
    );
  }

  /// Durasi sesi sejak dimulai.
  Duration get elapsed => DateTime.now().difference(startedAt);

  /// Label ringkas untuk display (mis. "🇮🇩 Indonesia ↔ 🇨🇳 中文").
  String get displayLabel =>
      '${languageA.displayLabel} ↔ ${languageB.displayLabel}';

  /// Kode bahasa yang terlibat dalam sesi — digunakan oleh SpeechService
  /// untuk membangun locale chain yang relevan.
  List<String> get sessionLanguageCodes => [languageA.code, languageB.code];

  @override
  String toString() => 'InterpreterSession($displayLabel, id=$sessionId)';

  @override
  bool operator ==(Object other) =>
      other is InterpreterSessionModel && other.sessionId == sessionId;

  @override
  int get hashCode => sessionId.hashCode;

  /// Generate ID berbasis timestamp + random suffix (tanpa package uuid).
  static String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = (ts * 1000 + ts.hashCode).toRadixString(36);
    return 'ses_$rand';
  }
}
