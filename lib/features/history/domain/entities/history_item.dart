import 'package:equatable/equatable.dart';

class HistoryItem extends Equatable {
  final String id;
  final String originalText;
  final String translatedText;
  final DateTime timestamp;

  const HistoryItem({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, originalText, translatedText, timestamp];
}
