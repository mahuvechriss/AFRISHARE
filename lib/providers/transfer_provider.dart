import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';

final transferServiceProvider = Provider<TransferService>((ref) {
  return TransferService.instance;
});

final transferListProvider =
    StateNotifierProvider<TransferListNotifier, TransferListState>((ref) {
  final transferService = ref.read(transferServiceProvider);
  return TransferListNotifier(transferService);
});

class TransferListState {
  final List<TransferModel> transfers;
  final List<TransferModel> activeTransfers;
  final List<TransferModel> completedTransfers;
  final List<TransferModel> failedTransfers;
  final bool isLoading;
  final String? error;

  const TransferListState({
    this.transfers = const [],
    this.activeTransfers = const [],
    this.completedTransfers = const [],
    this.failedTransfers = const [],
    this.isLoading = false,
    this.error,
  });

  TransferListState copyWith({
    List<TransferModel>? transfers,
    List<TransferModel>? activeTransfers,
    List<TransferModel>? completedTransfers,
    List<TransferModel>? failedTransfers,
    bool? isLoading,
    String? error,
  }) =>
      TransferListState(
        transfers: transfers ?? this.transfers,
        activeTransfers: activeTransfers ?? this.activeTransfers,
        completedTransfers: completedTransfers ?? this.completedTransfers,
        failedTransfers: failedTransfers ?? this.failedTransfers,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class TransferListNotifier extends StateNotifier<TransferListState> {
  final TransferService _transferService;

  TransferListNotifier(this._transferService)
      : super(const TransferListState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      await _transferService.initialize();
      _updateFromService();
      state = state.copyWith(isLoading: false);

      _transferService.onTransferUpdated = (_) => _updateFromService();
      _transferService.onTransferAdded = (_) => _updateFromService();
      _transferService.onTransferRemoved = (_) => _updateFromService();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _updateFromService() {
    state = state.copyWith(
      transfers: _transferService.transfers,
      activeTransfers: _transferService.activeTransfers,
      completedTransfers: _transferService.completedTransfers,
      failedTransfers: _transferService.failedTransfers,
    );
  }

  Future<void> queueTransfer({
    required String fileName,
    required int fileSize,
    required String fileType,
    String? mimeType,
    required String senderId,
    String? senderName,
    required String receiverId,
    String? receiverName,
    String? filePath,
  }) async {
    try {
      await _transferService.queueTransfer(
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
        mimeType: mimeType,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        receiverName: receiverName,
        filePath: filePath,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> pauseTransfer(String transferId) async {
    await _transferService.pauseTransfer(transferId);
  }

  Future<void> resumeTransfer(String transferId) async {
    await _transferService.resumeTransfer(transferId);
  }

  Future<void> cancelTransfer(String transferId) async {
    await _transferService.cancelTransfer(transferId);
  }

  Future<void> retryTransfer(String transferId) async {
    await _transferService.retryTransfer(transferId);
  }

  Future<void> deleteTransfer(String transferId) async {
    await _transferService.deleteTransfer(transferId);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
