import '../../domain/entities/history_item.dart';

class HistoryModel extends HistoryItem {
  const HistoryModel({
    required super.id,
    required super.originalText,
    required super.translatedText,
    required super.timestamp,
  });

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
