import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../settings/providers/settings_provider.dart';

class FavoriteItem {
  final String id;
  final String sourceLang; // e.g. "English" or "en"
  final String targetLang; // e.g. "Indonesian" or "id"
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'originalText': originalText,
        'translatedText': translatedText,
        'timestamp': timestamp.toIso8601String(),
      };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
        id: json['id'],
        sourceLang: json['sourceLang'],
        targetLang: json['targetLang'],
        originalText: json['originalText'],
        translatedText: json['translatedText'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class FavoriteNotifier extends StateNotifier<List<FavoriteItem>> {
  final SharedPreferences _prefs;
  static const String _key = 'translation_favorites';

  FavoriteNotifier(this._prefs) : super([]) {
    _loadFavorites();
  }

  void _loadFavorites() {
    final list = _prefs.getStringList(_key);
    if (list != null) {
      state = list.map((item) => FavoriteItem.fromJson(jsonDecode(item))).toList();
    }
  }

  Future<void> addFavorite({
    required String sourceLang,
    required String targetLang,
    required String originalText,
    required String translatedText,
  }) async {
    final newItem = FavoriteItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourceLang: sourceLang,
      targetLang: targetLang,
      originalText: originalText,
      translatedText: translatedText,
      timestamp: DateTime.now(),
    );

    // Prevent duplicates
    final exists = state.any((item) =>
        item.originalText.trim().toLowerCase() == originalText.trim().toLowerCase() &&
        item.translatedText.trim().toLowerCase() == translatedText.trim().toLowerCase());
    
    if (exists) return;

    final newState = [newItem, ...state];
    state = newState;
    await _saveToPrefs();
  }

  Future<void> removeFavorite(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _saveToPrefs();
  }

  Future<void> toggleFavorite({
    required String sourceLang,
    required String targetLang,
    required String originalText,
    required String translatedText,
  }) async {
    final existingIndex = state.indexWhere((item) =>
        item.originalText.trim().toLowerCase() == originalText.trim().toLowerCase() &&
        item.translatedText.trim().toLowerCase() == translatedText.trim().toLowerCase());

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
    return state.any((item) =>
        item.originalText.trim().toLowerCase() == originalText.trim().toLowerCase() &&
        item.translatedText.trim().toLowerCase() == translatedText.trim().toLowerCase());
  }

  Future<void> clearAll() async {
    state = [];
    await _prefs.remove(_key);
  }

  Future<void> _saveToPrefs() async {
    final list = state.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs.setStringList(_key, list);
  }
}

final favoriteProvider = StateNotifierProvider<FavoriteNotifier, List<FavoriteItem>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FavoriteNotifier(prefs);
});
