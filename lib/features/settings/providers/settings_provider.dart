import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

class SettingsState {
  final bool darkMode;
  final String appLanguage;
  final String defaultSourceLang;
  final String defaultTargetLang;
  final String speechSpeed;
  final String voiceGender;
  final bool autoPlayTranslation;
  final bool autoSaveHistory;
  final bool notifications;
  final String userName;
  final String userEmail;

  SettingsState({
    required this.darkMode,
    required this.appLanguage,
    required this.defaultSourceLang,
    required this.defaultTargetLang,
    required this.speechSpeed,
    required this.voiceGender,
    required this.autoPlayTranslation,
    required this.autoSaveHistory,
    required this.notifications,
    required this.userName,
    required this.userEmail,
  });

  SettingsState copyWith({
    bool? darkMode,
    String? appLanguage,
    String? defaultSourceLang,
    String? defaultTargetLang,
    String? speechSpeed,
    String? voiceGender,
    bool? autoPlayTranslation,
    bool? autoSaveHistory,
    bool? notifications,
    String? userName,
    String? userEmail,
  }) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      appLanguage: appLanguage ?? this.appLanguage,
      defaultSourceLang: defaultSourceLang ?? this.defaultSourceLang,
      defaultTargetLang: defaultTargetLang ?? this.defaultTargetLang,
      speechSpeed: speechSpeed ?? this.speechSpeed,
      voiceGender: voiceGender ?? this.voiceGender,
      autoPlayTranslation: autoPlayTranslation ?? this.autoPlayTranslation,
      autoSaveHistory: autoSaveHistory ?? this.autoSaveHistory,
      notifications: notifications ?? this.notifications,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(SettingsState(
    darkMode: _prefs.getBool('darkMode') ?? false,
    appLanguage: _prefs.getString('appLanguage') ?? 'English',
    defaultSourceLang: _prefs.getString('defaultSourceLang') ?? 'English',
    defaultTargetLang: _prefs.getString('defaultTargetLang') ?? 'Indonesian',
    speechSpeed: _prefs.getString('speechSpeed') ?? 'Normal',
    voiceGender: _prefs.getString('voiceGender') ?? 'Female',
    autoPlayTranslation: _prefs.getBool('autoPlayTranslation') ?? true,
    autoSaveHistory: _prefs.getBool('autoSaveHistory') ?? true,
    notifications: _prefs.getBool('notifications') ?? true,
    userName: _prefs.getString('userName') ?? 'Guest User',
    userEmail: _prefs.getString('userEmail') ?? 'guest@iwip.com',
  ));

  void updateDarkMode(bool value) {
    state = state.copyWith(darkMode: value);
    _prefs.setBool('darkMode', value);
  }

  void updateAppLanguage(String value) {
    state = state.copyWith(appLanguage: value);
    _prefs.setString('appLanguage', value);
  }

  void updateDefaultTranslationLanguage(String source, String target) {
    state = state.copyWith(defaultSourceLang: source, defaultTargetLang: target);
    _prefs.setString('defaultSourceLang', source);
    _prefs.setString('defaultTargetLang', target);
  }

  void updateSpeechSpeed(String value) {
    state = state.copyWith(speechSpeed: value);
    _prefs.setString('speechSpeed', value);
  }

  void updateVoiceGender(String value) {
    state = state.copyWith(voiceGender: value);
    _prefs.setString('voiceGender', value);
  }

  void updateAutoPlayTranslation(bool value) {
    state = state.copyWith(autoPlayTranslation: value);
    _prefs.setBool('autoPlayTranslation', value);
  }

  void updateAutoSaveHistory(bool value) {
    state = state.copyWith(autoSaveHistory: value);
    _prefs.setBool('autoSaveHistory', value);
  }

  void updateNotifications(bool value) {
    state = state.copyWith(notifications: value);
    _prefs.setBool('notifications', value);
  }

  void updateProfile(String name, String email) {
    state = state.copyWith(userName: name, userEmail: email);
    _prefs.setString('userName', name);
    _prefs.setString('userEmail', email);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
