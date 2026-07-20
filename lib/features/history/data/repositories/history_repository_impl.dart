import 'package:isar_community/isar.dart';

import '../../domain/entities/history_item.dart';
import '../../domain/repositories/history_repository.dart';
import '../../../../core/database/collections/history_record.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final Isar _isar;
  static const _maxItems = 50;

  HistoryRepositoryImpl(this._isar);

  @override
  Future<List<HistoryItem>> getHistory() async {
    final records = await _isar.historyRecords
        .where()
        .sortByTimestampDesc()
        .findAll();
    return records.map(_toEntity).toList();
  }

  @override
  Future<void> deleteHistoryItem(String id) async {
    await _isar.writeTxn(() async {
      final record = await _isar.historyRecords
          .filter()
          .recordIdEqualTo(id)
          .findFirst();
      if (record != null) {
        await _isar.historyRecords.delete(record.id);
      }
    });
  }

  @override
  Future<void> addHistoryItem(HistoryItem item) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.historyRecords
          .filter()
          .originalTextEqualTo(item.originalText)
          .translatedTextEqualTo(item.translatedText)
          .findFirst();
      if (existing != null) {
        await _isar.historyRecords.delete(existing.id);
      }

      final record = HistoryRecord()
        ..recordId = item.id
        ..originalText = item.originalText
        ..translatedText = item.translatedText
        ..timestamp = item.timestamp;
      await _isar.historyRecords.putByRecordId(record);

      final count = await _isar.historyRecords.count();
      if (count > _maxItems) {
        final oldest = await _isar.historyRecords
            .where()
            .sortByTimestamp()
            .limit(count - _maxItems)
            .findAll();
        await _isar.historyRecords.deleteAll(oldest.map((r) => r.id).toList());
      }
    });
  }

  @override
  Future<void> clearHistory() async {
    await _isar.writeTxn(() async {
      await _isar.historyRecords.clear();
    });
  }

  HistoryItem _toEntity(HistoryRecord record) {
    return HistoryItem(
      id: record.recordId,
      originalText: record.originalText,
      translatedText: record.translatedText,
      timestamp: record.timestamp,
    );
  }
}
