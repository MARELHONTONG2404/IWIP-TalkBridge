import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/iwip_hse_phrases.dart';
import '../../../core/database/collections/favorite_record.dart';
import '../../../core/database/isar_provider.dart';
import '../../settings/providers/settings_provider.dart';

class FavoriteItem {
  final String id;
  final String sourceLang;
  final String targetLang;
  final String originalText;
  final String translatedText;
  final DateTime timestamp;

  FavoriteItem({
    required this.id,
    required this.sourceLang,
    required this.targetLang,
    required this.originalText,
    required this.translatedText,
    required this.timestamp,
  });

  factory FavoriteItem.fromRecord(FavoriteRecord record) => FavoriteItem(
        id: record.recordId,
        sourceLang: record.sourceLang,
        targetLang: record.targetLang,
        originalText: record.originalText,
        translatedText: record.translatedText,
        timestamp: record.timestamp,
      );
}

class FavoriteNotifier extends StateNotifier<List<FavoriteItem>> {
  final Isar _isar;
  final SharedPreferences _prefs;
  static const String _seedKey = 'iwip_hse_phrases_seeded_v1';

  FavoriteNotifier(this._isar, this._prefs) : super([]) {
    // ignore: discarded_futures
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final records = await _isar.favoriteRecords
        .where()
        .sortByTimestampDesc()
        .findAll();

    if (records.isNotEmpty) {
      state = records.map(FavoriteItem.fromRecord).toList();
      return;
    }

    if (_prefs.getBool(_seedKey) != true) {
      await _seedHsePhrases();
    }
  }

  Future<void> _seedHsePhrases() async {
    final seeded = kIwipHsePhrases
        .map(
          (p) => FavoriteItem(
            id: p.id,
            sourceLang: 'id',
            targetLang: 'zh',
            originalText: p.idText,
            translatedText: p.zhText,
            timestamp: DateTime.now(),
          ),
        )
        .toList();

    await _isar.writeTxn(() async {
      for (final item in seeded) {
        await _isar.favoriteRecords.putByRecordId(_toRecord(item));
      }
    });

    await _prefs.setBool(_seedKey, true);
    state = seeded;
  }

  Future<void> ensureHsePhrases() async {
    final existing =
        state.map((e) => e.originalText.trim().toLowerCase()).toSet();
    final toAdd = <FavoriteItem>[];
    for (final p in kIwipHsePhrases) {
      if (existing.contains(p.idText.trim().toLowerCase())) continue;
      toAdd.add(
        FavoriteItem(
          id: '${p.id}_${DateTime.now().millisecondsSinceEpoch}',
          sourceLang: 'id',
          targetLang: 'zh',
          originalText: p.idText,
          translatedText: p.zhText,
          timestamp: DateTime.now(),
        ),
      );
    }
    if (toAdd.isEmpty) return;

    await _isar.writeTxn(() async {
      for (final item in toAdd) {
        await _isar.favoriteRecords.putByRecordId(_toRecord(item));
      }
    });

    await _prefs.setBool(_seedKey, true);
    state = [...toAdd, ...state];
  }

  Future<void> addFavorite({
    required String sourceLang,
    required String targetLang,
    required String originalText,
    required String translatedText,
  }) async {
    final exists = state.any(
      (item) =>
          item.originalText.trim().toLowerCase() ==
              originalText.trim().toLowerCase() &&
          item.translatedText.trim().toLowerCase() ==
              translatedText.trim().toLowerCase(),
    );
    if (exists) return;

    final newItem = FavoriteItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourceLang: sourceLang,
      targetLang: targetLang,
      originalText: originalText,
      translatedText: translatedText,
      timestamp: DateTime.now(),
    );

    await _isar.writeTxn(() async {
      await _isar.favoriteRecords.putByRecordId(_toRecord(newItem));
    });

    state = [newItem, ...state];
  }

  Future<void> removeFavorite(String id) async {
    await _isar.writeTxn(() async {
      final record =
          await _isar.favoriteRecords.filter().recordIdEqualTo(id).findFirst();
      if (record != null) {
        await _isar.favoriteRecords.delete(record.id);
      }
    });
    state = state.where((item) => item.id != id).toList();
  }

  Future<void> toggleFavorite({
    required String sourceLang,
    required String targetLang,
    required String originalText,
    required String translatedText,
  }) async {
    final existingIndex = state.indexWhere(
      (item) =>
          item.originalText.trim().toLowerCase() ==
              originalText.trim().toLowerCase() &&
          item.translatedText.trim().toLowerCase() ==
              translatedText.trim().toLowerCase(),
    );

    if (existingIndex >= 0) {
      await removeFavorite(state[existingIndex].id);
    } else {
      await addFavorite(
        sourceLang: sourceLang,
        targetLang: targetLang,
        originalText: originalText,
        translatedText: translatedText,
      );
    }
  }

  bool isFavorite(String originalText, String translatedText) {
    return state.any(
      (item) =>
          item.originalText.trim().toLowerCase() ==
              originalText.trim().toLowerCase() &&
          item.translatedText.trim().toLowerCase() ==
              translatedText.trim().toLowerCase(),
    );
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.favoriteRecords.clear();
    });
    state = [];
  }

  FavoriteRecord _toRecord(FavoriteItem item) {
    return FavoriteRecord()
      ..recordId = item.id
      ..sourceLang = item.sourceLang
      ..targetLang = item.targetLang
      ..originalText = item.originalText
      ..translatedText = item.translatedText
      ..timestamp = item.timestamp;
  }
}

final favoriteProvider =
    StateNotifierProvider<FavoriteNotifier, List<FavoriteItem>>((ref) {
  final isar = ref.watch(isarProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FavoriteNotifier(isar, prefs);
});
