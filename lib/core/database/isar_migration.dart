import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collections/favorite_record.dart';
import 'collections/history_record.dart';

/// Migrasi data lama dari SharedPreferences ke Isar (sekali saja).
class IsarMigration {
  static const _flagKey = 'isar_migrated_v1';

  static Future<void> migrateFromSharedPreferences(
    Isar isar,
    SharedPreferences prefs,
  ) async {
    if (prefs.getBool(_flagKey) == true) return;

    await isar.writeTxn(() async {
      await _migrateHistory(isar, prefs);
      await _migrateFavorites(isar, prefs);
    });

    await prefs.setBool(_flagKey, true);
  }

  static Future<void> _migrateHistory(
    Isar isar,
    SharedPreferences prefs,
  ) async {
    const key = 'translation_history';
    final list = prefs.getStringList(key);
    if (list == null || list.isEmpty) return;

    for (final raw in list) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final record = HistoryRecord()
          ..recordId = json['id'] as String
          ..originalText = json['originalText'] as String
          ..translatedText = json['translatedText'] as String
          ..timestamp = DateTime.parse(json['timestamp'] as String);
        await isar.historyRecords.putByRecordId(record);
      } catch (_) {
        // Skip corrupt legacy rows.
      }
    }
  }

  static Future<void> _migrateFavorites(
    Isar isar,
    SharedPreferences prefs,
  ) async {
    const key = 'translation_favorites';
    final list = prefs.getStringList(key);
    if (list == null || list.isEmpty) return;

    for (final raw in list) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final record = FavoriteRecord()
          ..recordId = json['id'] as String
          ..sourceLang = json['sourceLang'] as String
          ..targetLang = json['targetLang'] as String
          ..originalText = json['originalText'] as String
          ..translatedText = json['translatedText'] as String
          ..timestamp = DateTime.parse(json['timestamp'] as String);
        await isar.favoriteRecords.putByRecordId(record);
      } catch (_) {
        // Skip corrupt legacy rows.
      }
    }
  }
}
