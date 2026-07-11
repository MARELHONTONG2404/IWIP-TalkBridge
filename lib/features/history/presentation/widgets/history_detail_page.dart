import 'package:flutter/material.dart';
import '../../domain/entities/history_item.dart';

class HistoryDetailPage extends StatelessWidget {
  final HistoryItem item;

  const HistoryDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Original Text', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(item.originalText),
            const SizedBox(height: 16),
            const Text('Translated Text', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(item.translatedText),
            const SizedBox(height: 16),
            const Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(item.timestamp.toString()),
          ],
        ),
      ),
    );
  }
}
