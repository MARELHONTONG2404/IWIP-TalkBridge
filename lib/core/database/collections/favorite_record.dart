import 'package:isar_community/isar.dart';

part 'favorite_record.g.dart';

@collection
class FavoriteRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String recordId;

  late String sourceLang;
  late String targetLang;
  late String originalText;
  late String translatedText;

  @Index()
  late DateTime timestamp;
}
