import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

final storageStateProvider =
    StateNotifierProvider<StorageNotifier, StorageState>((ref) {
  final storageService = ref.read(storageServiceProvider);
  return StorageNotifier(storageService);
});

class StorageState {
  final Map<String, dynamic>? stats;
  final bool isLoading;
  final String? error;

  const StorageState({
    this.stats,
    this.isLoading = false,
    this.error,
  });

  StorageState copyWith({
    Map<String, dynamic>? stats,
    bool? isLoading,
    String? error,
  }) =>
      StorageState(
        stats: stats ?? this.stats,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class StorageNotifier extends StateNotifier<StorageState> {
  final StorageService _storageService;

  StorageNotifier(this._storageService) : super(const StorageState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    await _storageService.initialize();
    await refreshStats();
    state = state.copyWith(isLoading: false);
  }

  Future<void> refreshStats() async {
    try {
      final stats = await _storageService.getStorageStats();
      state = state.copyWith(stats: stats);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> clearCache() async {
    await _storageService.clearCache();
    await refreshStats();
  }

  Future<void> clearTransfers() async {
    await _storageService.clearTransfers();
    await refreshStats();
  }

  Future<void> autoCleanup() async {
    await _storageService.autoCleanup();
    await refreshStats();
  }
}
