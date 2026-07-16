import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/iwip_hse_phrases.dart';
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
  static const String _seedKey = 'iwip_hse_phrases_seeded_v1';

  FavoriteNotifier(this._prefs) : super([]) {
    _loadFavorites();
  }

  void _loadFavorites() {
    final list = _prefs.getStringList(_key);
    if (list != null && list.isNotEmpty) {
      state = list.map((item) => FavoriteItem.fromJson(jsonDecode(item))).toList();
      return;
    }
    // First install / empty: seed frasa HSE IWIP sekali saja.
    if (_prefs.getBool(_seedKey) != true) {
      _seedHsePhrasesSync();
    }
  }

  void _seedHsePhrasesSync() {
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
    state = seeded;
    _prefs.setBool(_seedKey, true);
    // Fire-and-forget persist; load path is sync constructor.
    // ignore: discarded_futures
    _saveToPrefs();
  }

  /// Muat ulang frasa HSE tanpa menghapus favorit user yang sudah ada.
  Future<void> ensureHsePhrases() async {
    final existing = state.map((e) => e.originalText.trim().toLowerCase()).toSet();
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
    state = [...toAdd, ...state];
    await _prefs.setBool(_seedKey, true);
    await _saveToPrefs();
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
