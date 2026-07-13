import '../entities/history_item.dart';

abstract class HistoryRepository {
  Future<List<HistoryItem>> getHistory();
  Future<void> deleteHistoryItem(String id);
  Future<void> addHistoryItem(HistoryItem item);
  Future<void> clearHistory();
}
