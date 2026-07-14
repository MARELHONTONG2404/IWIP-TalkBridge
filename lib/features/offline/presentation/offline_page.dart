import 'package:flutter/material.dart';
import '../../../../core/services/offline_translation_service.dart';

/// Supported offline languages (code → display info)
final _offlineLanguages = [
  _LangInfo(code: 'id', name: 'Indonesian', native: 'Indonesia', flag: '🇮🇩', sizeMb: 30),
  _LangInfo(code: 'en', name: 'English', native: 'English', flag: '🇬🇧', sizeMb: 30),
  _LangInfo(code: 'zh', name: 'Chinese', native: '中文', flag: '🇨🇳', sizeMb: 35),
  _LangInfo(code: 'ja', name: 'Japanese', native: '日本語', flag: '🇯🇵', sizeMb: 32),
  _LangInfo(code: 'ko', name: 'Korean', native: '한국어', flag: '🇰🇷', sizeMb: 30),
  _LangInfo(code: 'ar', name: 'Arabic', native: 'العربية', flag: '🇸🇦', sizeMb: 30),
  _LangInfo(code: 'fr', name: 'French', native: 'Français', flag: '🇫🇷', sizeMb: 30),
  _LangInfo(code: 'de', name: 'German', native: 'Deutsch', flag: '🇩🇪', sizeMb: 30),
  _LangInfo(code: 'es', name: 'Spanish', native: 'Español', flag: '🇪🇸', sizeMb: 30),
  _LangInfo(code: 'ru', name: 'Russian', native: 'Русский', flag: '🇷🇺', sizeMb: 30),
];

class _LangInfo {
  final String code;
  final String name;
  final String native;
  final String flag;
  final int sizeMb;

  const _LangInfo({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
    required this.sizeMb,
  });
}

class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  final OfflineTranslationService _service = OfflineTranslationService();

  // State per language: isInstalled, isDownloading, progress
  final Map<String, bool> _installed = {};
  final Map<String, bool> _downloading = {};
  final Map<String, double> _progress = {};

  // Offline translation test
  String _testOutput = '';
  String _testFrom = 'id';
  String _testTo = 'en';
  bool _testing = false;
  final _testController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAllModels();
  }

  @override
  void dispose() {
    _testController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _checkAllModels() async {
    for (final lang in _offlineLanguages) {
      final installed = await _service.isModelDownloaded(lang.code);
      if (mounted) {
        setState(() => _installed[lang.code] = installed);
      }
    }
  }

  Future<void> _downloadModel(_LangInfo lang) async {
    if (_downloading[lang.code] == true || _installed[lang.code] == true) return;

    setState(() {
      _downloading[lang.code] = true;
      _progress[lang.code] = 0.05;
    });

    // Animate progress bar while downloading (ML Kit doesn't give real progress)
    // We use a fake incremental animation until download completes
    var fakeProg = 0.05;
    final ticker = Stream.periodic(const Duration(milliseconds: 400)).listen((_) {
      if (!mounted) return;
      fakeProg = (fakeProg + 0.04).clamp(0.0, 0.90);
      setState(() => _progress[lang.code] = fakeProg);
    });

    try {
      await _service.downloadModel(lang.code);
      ticker.cancel();
      if (mounted) {
        setState(() {
          _progress[lang.code] = 1.0;
          _installed[lang.code] = true;
          _downloading[lang.code] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.flag} ${lang.name} model installed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ticker.cancel();
      if (mounted) {
        setState(() {
          _downloading[lang.code] = false;
          _progress[lang.code] = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download ${lang.name}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteModel(_LangInfo lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${lang.name} model?'),
        content: Text('This will free ~${lang.sizeMb} MB of storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteModel(lang.code);
      if (mounted) {
        setState(() {
          _installed[lang.code] = false;
          _progress[lang.code] = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.name} model deleted.')),
        );
      }
    }
  }

  Future<void> _testTranslation() async {
    final text = _testController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _testing = true;
      _testOutput = '';
    });

    try {
      final result = await _service.translate(
        text: text,
        from: _testFrom,
        to: _testTo,
      );
      setState(() => _testOutput = result);
    } catch (e) {
      setState(() => _testOutput = 'Error: $e');
    } finally {
      setState(() => _testing = false);
    }
  }

  int get _installedCount =>
      _installed.values.where((v) => v == true).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Languages'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // --- Info Banner ---
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_download_rounded,
                    color: colors.onPrimaryContainer, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Translation Models',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Download language models (~30 MB each) to translate without internet. '
                        '$_installedCount/${_offlineLanguages.length} models installed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Language List ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Available Languages',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),

          ..._offlineLanguages.map((lang) {
            final isInstalled = _installed[lang.code] == true;
            final isDownloading = _downloading[lang.code] == true;
            final progress = _progress[lang.code] ?? 0.0;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(lang.flag, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${lang.native} • ~${lang.sizeMb} MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isInstalled)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.red),
                                onPressed: () => _deleteModel(lang),
                                tooltip: 'Delete model',
                              ),
                            ],
                          )
                        else if (isDownloading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else
                          IconButton(
                            icon: Icon(Icons.download_rounded,
                                color: colors.primary),
                            onPressed: () => _downloadModel(lang),
                            tooltip: 'Download model',
                          ),
                      ],
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: colors.surfaceContainerHighest,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Downloading... ${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // --- Test Offline Translation ---
          if (_installedCount > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Test Offline Translation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Builder(builder: (context) {
                            final installedItems = _offlineLanguages
                                .where((l) => _installed[l.code] == true)
                                .toList();
                            final isValid = installedItems
                                .any((l) => l.code == _testFrom);
                            final value = isValid ? _testFrom : (installedItems.isNotEmpty ? installedItems.first.code : null);
                            
                            return DropdownButtonFormField<String>(
                              initialValue: value,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'From',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                              items: installedItems
                                  .map((l) => DropdownMenuItem(
                                        value: l.code,
                                        child: Text(
                                            '${l.flag} ${l.name}',
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _testFrom = val!),
                            );
                          }),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward_rounded,
                              color: colors.primary, size: 20),
                        ),
                        Expanded(
                          child: Builder(builder: (context) {
                            final installedItems = _offlineLanguages
                                .where((l) => _installed[l.code] == true)
                                .toList();
                            final isValid = installedItems
                                .any((l) => l.code == _testTo);
                            final value = isValid ? _testTo : (installedItems.isNotEmpty ? installedItems.first.code : null);

                            return DropdownButtonFormField<String>(
                              initialValue: value,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'To',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                              items: installedItems
                                  .map((l) => DropdownMenuItem(
                                        value: l.code,
                                        child: Text(
                                            '${l.flag} ${l.name}',
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _testTo = val!),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _testController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter text to translate offline...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: _testing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : Icon(Icons.translate_rounded,
                                  color: colors.primary),
                          onPressed: _testing ? null : _testTranslation,
                        ),
                      ),
                      onSubmitted: (_) => _testTranslation(),
                    ),
                    if (_testOutput.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _testOutput,
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
