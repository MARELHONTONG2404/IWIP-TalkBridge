import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/tts_service.dart';
import '../../providers/favorite_provider.dart';

class FavoritePage extends ConsumerStatefulWidget {
  const FavoritePage({super.key});

  @override
  ConsumerState<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends ConsumerState<FavoritePage> {
  final TtsService _ttsService = TtsService();

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoriteProvider);
    final notifier = ref.read(favoriteProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.health_and_safety_outlined),
            tooltip: 'Muat frasa HSE IWIP',
            onPressed: () async {
              await notifier.ensureHsePhrases();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Frasa HSE IWIP siap dipakai')),
              );
            },
          ),
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear all',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear all favorites?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await notifier.clearAll();
                }
              },
            ),
        ],
      ),
      body: favorites.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final item = favorites[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${item.sourceLang} → ${item.targetLang}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              item.timestamp.toString().substring(0, 16),
                              style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.originalText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.titleMedium?.color,
                          ),
                        ),
                        Divider(height: 24, color: theme.dividerColor),
                        Text(
                          item.translatedText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.volume_up, color: theme.colorScheme.primary),
                              tooltip: 'Speak translation',
                              onPressed: () {
                                String code = 'en';
                                final t = item.targetLang.toLowerCase();
                                if (t.contains('indo') || t == 'id') {
                                  code = 'id';
                                } else if (t.contains('chin') ||
                                    t == 'zh' ||
                                    item.targetLang.contains('中文')) {
                                  code = 'zh';
                                } else if (t.contains('jap') ||
                                    item.targetLang.contains('日本語')) {
                                  code = 'ja';
                                } else if (t.contains('kor') ||
                                    item.targetLang.contains('한국어')) {
                                  code = 'ko';
                                }
                                _ttsService.speak(item.translatedText, languageCode: code);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                              tooltip: 'Remove',
                              onPressed: () => notifier.removeFavorite(item.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_border_rounded, 
              size: 80, 
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada favorit',
              style: TextStyle(
                fontSize: 18, 
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Muat frasa HSE siap pakai (Indonesia ↔ 中文)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, 
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(favoriteProvider.notifier).ensureHsePhrases(),
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Muat frasa HSE IWIP'),
            ),
          ],
        ),
      ),
    );
  }
}
