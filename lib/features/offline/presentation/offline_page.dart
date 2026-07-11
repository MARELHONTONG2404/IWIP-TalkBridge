import 'package:flutter/material.dart';

class LanguagePack {
  final String name;
  final String code;
  final String size;
  final double progress; // 0.0 to 1.0
  final bool isInstalled;

  LanguagePack({
    required this.name,
    required this.code,
    required this.size,
    required this.progress,
    required this.isInstalled,
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
    LanguagePack(name: 'English', code: 'EN', size: '200 MB', progress: 0.5, isInstalled: false),
    LanguagePack(name: 'Chinese', code: 'ZH', size: '300 MB', progress: 0.0, isInstalled: false),
  ];

  @override
  Widget build(BuildContext context) {
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Storage Used', style: TextStyle(color: Colors.grey)),
                      Text('150 MB / 10 GB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  Icon(Icons.storage, color: Theme.of(context).primaryColor),
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
                  child: ListTile(
                    title: Text(lang.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lang.code} • ${lang.size}'),
                        if (!lang.isInstalled && lang.progress > 0) ...[
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: lang.progress),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(lang.isInstalled ? Icons.delete : Icons.download),
                      color: lang.isInstalled ? Colors.red : Colors.blue,
                      onPressed: () {},
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
