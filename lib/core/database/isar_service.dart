import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collections/favorite_record.dart';
import 'collections/history_record.dart';
import 'isar_migration.dart';

class _DummyIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod && invocation.memberName == #writeTxn) {
      return Future.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

class IsarService {
  static const _dbName = 'iwip_talkbridge';

  static Future<Isar> open(SharedPreferences prefs) async {
    debugPrint('--- AUDIT: IsarService.open() called');
    if (kIsWeb) {
      return _DummyIsar();
    }
    
    final dir = await getApplicationDocumentsDirectory();
    return openWithDir(prefs, dir.path);
  }

  static Future<Isar> openWithDir(SharedPreferences prefs, String dirPath) async {
    debugPrint('--- AUDIT: IsarService.openWithDir() called');
    if (kIsWeb) {
      return _DummyIsar();
    }
    
    final isar = await Isar.open(
      [HistoryRecordSchema, FavoriteRecordSchema],
      directory: dirPath,
      name: _dbName,
    );
    
    // Opt-out from awaiting migration if already migrated to save startup time
    if (prefs.getBool(IsarMigration.flagKey) != true) {
      await IsarMigration.migrateFromSharedPreferences(isar, prefs);
    }
    
    return isar;
  }
}
