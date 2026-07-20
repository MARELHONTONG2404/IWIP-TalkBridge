import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collections/favorite_record.dart';
import 'collections/history_record.dart';
import 'isar_migration.dart';

class IsarService {
  static const _dbName = 'iwip_talkbridge';

  static Future<Isar> open(SharedPreferences prefs) async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [HistoryRecordSchema, FavoriteRecordSchema],
      directory: dir.path,
      name: _dbName,
    );
    await IsarMigration.migrateFromSharedPreferences(isar, prefs);
    return isar;
  }
}
