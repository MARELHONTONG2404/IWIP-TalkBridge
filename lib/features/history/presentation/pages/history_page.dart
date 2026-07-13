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

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: historyState.when(
        data: (history) => history.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'No history yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : ListView.builder(
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
