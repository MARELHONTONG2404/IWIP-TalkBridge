import 'package:isar_community/isar.dart';

class HistoryRecord {
  Id id = Isar.autoIncrement;
  late String recordId;
  late String originalText;
  late String translatedText;
  late DateTime timestamp;
}

final dynamic HistoryRecordSchema = null;

class _HistoryQueryBuilder {
  _HistoryQueryBuilder where() => this;
  _HistoryQueryBuilder filter() => this;
  _HistoryQueryBuilder sortByTimestampDesc() => this;
  _HistoryQueryBuilder sortByTimestamp() => this;
  _HistoryQueryBuilder limit(dynamic max) => this;
  _HistoryQueryBuilder recordIdEqualTo(dynamic id) => this;
  _HistoryQueryBuilder originalTextEqualTo(dynamic text) => this;
  _HistoryQueryBuilder translatedTextEqualTo(dynamic text) => this;
  
  Future<List<HistoryRecord>> findAll() async => <HistoryRecord>[];
  Future<HistoryRecord?> findFirst() async => null;
}

class _HistoryMockCollection {
  _HistoryQueryBuilder where() => _HistoryQueryBuilder();
  _HistoryQueryBuilder filter() => _HistoryQueryBuilder();
  Future<int> putByRecordId(HistoryRecord record) async => 0;
  Future<bool> delete(dynamic id) async => true;
  Future<int> deleteAll(dynamic ids) async => 0;
  Future<void> clear() async {}
  Future<int> count() async => 0;
}

extension GetHistoryRecordCollection on Isar {
  dynamic get historyRecords => _HistoryMockCollection();
}
