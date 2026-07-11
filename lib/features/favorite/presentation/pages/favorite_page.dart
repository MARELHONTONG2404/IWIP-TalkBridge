import 'package:flutter/material.dart';

class FavoriteItem {
  final String id;
  final String sourceLang;
  final String targetLang;
  final String content;
  final DateTime date;

  FavoriteItem({
    required this.id,
    required this.sourceLang,
    required this.targetLang,
    required this.content,
    required this.date,
  });
}

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  // Dummy data
  final List<FavoriteItem> favorites = [
    FavoriteItem(id: '1', sourceLang: 'English', targetLang: 'Indonesian', content: 'Hello, how can I help you?', date: DateTime.now().subtract(const Duration(days: 1))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final item = favorites[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text('${item.sourceLang} → ${item.targetLang}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.content),
                        const SizedBox(height: 4),
                        Text(item.date.toString().substring(0, 16), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.volume_up), onPressed: () {}),
                        IconButton(icon: const Icon(Icons.favorite, color: Colors.red), onPressed: () {}),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () {}),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No favorites yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
