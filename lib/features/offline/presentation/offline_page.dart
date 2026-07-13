import 'dart:async';
import 'package:flutter/material.dart';

class LanguagePack {
  final String name;
  final String code;
  final String size;
  double progress; // 0.0 to 1.0
  bool isInstalled;
  bool isDownloading;

  LanguagePack({
    required this.name,
    required this.code,
    required this.size,
    this.progress = 0.0,
    this.isInstalled = false,
    this.isDownloading = false,
  });
}

class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  final List<LanguagePack> languages = [
    LanguagePack(name: 'Indonesian', code: 'ID', size: '150 MB', progress: 1.0, isInstalled: true),
    LanguagePack(name: 'English', code: 'EN', size: '200 MB', progress: 0.0, isInstalled: false),
    LanguagePack(name: 'Chinese', code: 'ZH', size: '300 MB', progress: 0.0, isInstalled: false),
    LanguagePack(name: 'Japanese', code: 'JA', size: '180 MB', progress: 0.0, isInstalled: false),
    LanguagePack(name: 'Korean', code: 'KO', size: '190 MB', progress: 0.0, isInstalled: false),
  ];

  final Map<String, Timer> _timers = {};

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _startDownload(LanguagePack lang) {
    if (lang.isDownloading || lang.isInstalled) return;

    setState(() {
      lang.isDownloading = true;
      lang.progress = 0.05;
    });

    final timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        lang.progress += 0.1;
        if (lang.progress >= 1.0) {
          lang.progress = 1.0;
          lang.isInstalled = true;
          lang.isDownloading = false;
          timer.cancel();
          _timers.remove(lang.code);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${lang.name} language pack installed successfully!')),
          );
        }
      });
    });

    _timers[lang.code] = timer;
  }

  void _deletePack(LanguagePack lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${lang.name} pack?'),
        content: Text('This will free up ${lang.size} of storage space.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                lang.isInstalled = false;
                lang.isDownloading = false;
                lang.progress = 0.0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${lang.name} language pack deleted.')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  double get _totalStorageUsed {
    double total = 0;
    for (final lang in languages) {
      if (lang.isInstalled) {
        final sizeStr = lang.size.split(' ').first;
        total += double.tryParse(sizeStr) ?? 0;
      } else if (lang.isDownloading) {
        final sizeStr = lang.size.split(' ').first;
        final sizeVal = double.tryParse(sizeStr) ?? 0;
        total += sizeVal * lang.progress;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final storageUsed = _totalStorageUsed;

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Languages')),
      body: Column(
        children: [
          // Storage Info
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Storage Used', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '${storageUsed.toStringAsFixed(1)} MB / 10 GB',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  Icon(Icons.storage_rounded, color: Theme.of(context).primaryColor, size: 28),
                ],
              ),
            ),
          ),
          
          // List
          Expanded(
            child: ListView.builder(
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(lang.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('${lang.code} • ${lang.size}'),
                        if (lang.isDownloading) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: lang.progress,
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: lang.isInstalled
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            tooltip: 'Delete pack',
                            onPressed: () => _deletePack(lang),
                          )
                        : lang.isDownloading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.download_rounded, color: Colors.blue),
                                tooltip: 'Download pack',
                                onPressed: () => _startDownload(lang),
                              ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
