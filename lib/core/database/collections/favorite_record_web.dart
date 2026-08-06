import 'package:isar_community/isar.dart';

class FavoriteRecord {
  Id id = Isar.autoIncrement;
  late String recordId;
  late String sourceLang;
  late String targetLang;
  late String originalText;
  late String translatedText;
  late DateTime timestamp;
}

final dynamic FavoriteRecordSchema = null;

class _FavoriteQueryBuilder {
  _FavoriteQueryBuilder where() => this;
  _FavoriteQueryBuilder sortByTimestampDesc() => this;
  Future<List<FavoriteRecord>> findAll() async => <FavoriteRecord>[];
}

class _FavoriteMockCollection {
  _FavoriteQueryBuilder where() => _FavoriteQueryBuilder();
  Future<int> putByRecordId(FavoriteRecord record) async => 0;
}

extension GetFavoriteRecordCollection on Isar {
  dynamic get favoriteRecords => _FavoriteMockCollection();
}
