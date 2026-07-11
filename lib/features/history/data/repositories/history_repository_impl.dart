import '../../domain/entities/history_item.dart';
import '../../domain/repositories/history_repository.dart';
import '../models/history_model.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  // Dummy data
  final List<HistoryModel> _history = [
    HistoryModel(
      id: '1',
      originalText: 'Hello',
      translatedText: 'Halo',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    HistoryModel(
      id: '2',
      originalText: 'How are you?',
      translatedText: 'Apa kabar?',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  Future<List<HistoryItem>> getHistory() async {
    return _history;
  }

  @override
  Future<void> deleteHistoryItem(String id) async {
    _history.removeWhere((item) => item.id == id);
  }
}
