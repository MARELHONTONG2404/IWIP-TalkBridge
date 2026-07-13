import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/repositories/history_repository.dart';
import '../models/history_model.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final SharedPreferences _prefs;
  static const String _historyKey = 'translation_history';

  HistoryRepositoryImpl(this._prefs);

  @override
  Future<List<HistoryItem>> getHistory() async {
    final list = _prefs.getStringList(_historyKey);
    if (list == null) return [];
    return list.map((item) => HistoryModel.fromJson(jsonDecode(item))).toList();
  }

  @override
  Future<void> deleteHistoryItem(String id) async {
    final list = _prefs.getStringList(_historyKey);
    if (list == null) return;
    final newList = list.where((item) {
      final decoded = jsonDecode(item);
      return decoded['id'] != id;
    }).toList();
    await _prefs.setStringList(_historyKey, newList);
  }

  @override
  Future<void> addHistoryItem(HistoryItem item) async {
    final list = _prefs.getStringList(_historyKey) ?? [];
    final model = HistoryModel(
      id: item.id,
      originalText: item.originalText,
      translatedText: item.translatedText,
      timestamp: item.timestamp,
    );
    // Avoid duplicates if the same original text and translation exist
    list.removeWhere((x) {
      final decoded = jsonDecode(x);
      return decoded['originalText'] == item.originalText && decoded['translatedText'] == item.translatedText;
    });
    list.insert(0, jsonEncode(model.toJson())); // Put at start
    // Limit history length to e.g. 50 items
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }
    await _prefs.setStringList(_historyKey, list);
  }

  @override
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }
}
