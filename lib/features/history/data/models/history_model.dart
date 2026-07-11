import '../../domain/entities/history_item.dart';

class HistoryModel extends HistoryItem {
  const HistoryModel({
    required String id,
    required String originalText,
    required String translatedText,
    required DateTime timestamp,
  }) : super(
          id: id,
          originalText: originalText,
          translatedText: translatedText,
          timestamp: timestamp,
        );

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      id: json['id'],
      originalText: json['originalText'],
      translatedText: json['translatedText'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalText': originalText,
      'translatedText': translatedText,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
