import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/history_provider.dart';
import '../widgets/history_card.dart';
import '../widgets/history_detail_page.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyListProvider);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: historyState.when(
        data: (history) => history.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded, 
                      size: 80, 
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No history yet',
                      style: TextStyle(
                        fontSize: 18, 
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), 
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return HistoryCard(
                    item: item,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HistoryDetailPage(item: item)),
                    ),
                    onDelete: () => ref.read(historyListProvider.notifier).deleteItem(item.id),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
