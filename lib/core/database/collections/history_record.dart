import 'package:isar_community/isar.dart';

part 'history_record.g.dart';

@collection
class HistoryRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String recordId;

  late String originalText;
  late String translatedText;

  @Index()
  late DateTime timestamp;
}
