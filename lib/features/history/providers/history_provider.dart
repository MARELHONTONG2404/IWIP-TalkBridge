import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/history_repository_impl.dart';
import '../domain/entities/history_item.dart';
import '../domain/repositories/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepositoryImpl();
});

final historyListProvider = StateNotifierProvider<HistoryNotifier, AsyncValue<List<HistoryItem>>>((ref) {
  final repository = ref.watch(historyRepositoryProvider);
  return HistoryNotifier(repository);
});

class HistoryNotifier extends StateNotifier<AsyncValue<List<HistoryItem>>> {
  final HistoryRepository _repository;

  HistoryNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final history = await _repository.getHistory();
      state = AsyncValue.data(history);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteItem(String id) async {
    await _repository.deleteHistoryItem(id);
    _loadHistory();
  }
}
