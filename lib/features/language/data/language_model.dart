class LanguageModel {
  final String name;
  final String nativeName;
  final String flag;
  final String code;
  final String speechCode;

  const LanguageModel({
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.code,
    required this.speechCode,
  });

  String get displayLabel => '$flag $nativeName';

  @override
  String toString() => displayLabel;

  @override
  bool operator ==(Object other) =>
      other is LanguageModel && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

const languages = [
  LanguageModel(
    name: 'Indonesia',
    nativeName: 'Indonesia',
    flag: '🇮🇩',
    code: 'id',
    speechCode: 'id-ID',
  ),
  LanguageModel(
    name: 'English',
    nativeName: 'English',
    flag: '🇺🇸',
    code: 'en',
    speechCode: 'en-US',
  ),
  LanguageModel(
    name: 'Chinese',
    nativeName: '中文',
    flag: '🇨🇳',
    code: 'zh',
    speechCode: 'zh-CN',
  ),
  LanguageModel(
    name: 'Japanese',
    nativeName: '日本語',
    flag: '🇯🇵',
    code: 'ja',
    speechCode: 'ja-JP',
  ),
  LanguageModel(
    name: 'Korean',
    nativeName: '한국어',
    flag: '🇰🇷',
    code: 'ko',
    speechCode: 'ko-KR',
  ),
  LanguageModel(
    name: 'Arabic',
    nativeName: 'العربية',
    flag: '🇸🇦',
    code: 'ar',
    speechCode: 'ar-SA',
  ),
  LanguageModel(
    name: 'French',
    nativeName: 'Français',
    flag: '🇫🇷',
    code: 'fr',
    speechCode: 'fr-FR',
  ),
  LanguageModel(
    name: 'German',
    nativeName: 'Deutsch',
    flag: '🇩🇪',
    code: 'de',
    speechCode: 'de-DE',
  ),
  LanguageModel(
    name: 'Spanish',
    nativeName: 'Español',
    flag: '🇪🇸',
    code: 'es',
    speechCode: 'es-ES',
  ),
  LanguageModel(
    name: 'Russian',
    nativeName: 'Русский',
    flag: '🇷🇺',
    code: 'ru',
    speechCode: 'ru-RU',
  ),
];

LanguageModel languageByCode(String code) {
  return languages.firstWhere(
    (lang) => lang.code == code,
    orElse: () => languages.first,
  );
}
