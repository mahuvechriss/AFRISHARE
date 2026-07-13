import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/transfer_model.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';

/// Service managing file transfers between devices
class TransferService {
  TransferService._();
  static final TransferService instance = TransferService._();

  final Uuid _uuid = const Uuid();
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<TransferModel> _transfers = [];
  final Map<String, StreamSubscription> _transferSubscriptions = {};
  final Map<String, CancelToken> _cancelTokens = {};

  // Callbacks
  void Function(TransferModel transfer)? onTransferAdded;
  void Function(TransferModel transfer)? onTransferUpdated;
  void Function(TransferModel transfer)? onTransferRemoved;
  /// Called when a transfer needs to be re-sent (e.g. on retry)
  Future<bool> Function(TransferModel transfer)? onRetryTransfer;

  List<TransferModel> get transfers => List.unmodifiable(_transfers);

  List<TransferModel> get activeTransfers =>
      _transfers.where((t) => t.isActive).toList();

  List<TransferModel> get completedTransfers =>
      _transfers.where((t) => t.status == TransferStatus.completed).toList();

  List<TransferModel> get failedTransfers =>
      _transfers.where((t) => t.status == TransferStatus.failed).toList();

  /// Initialize and load transfer history
  Future<void> initialize() async {
    final results = await _db.query(
      'transfers',
      orderBy: 'created_at DESC',
      limit: 100,
    );
    for (final row in results) {
      _transfers.add(TransferModel.fromJson(row));
    }
  }

  /// Queue a file for sending
  Future<TransferModel> queueTransfer({
    required String fileName,
    required int fileSize,
    required String fileType,
    String? mimeType,
    required String senderId,
    String? senderName,
    required String receiverId,
    String? receiverName,
    TransferDirection direction = TransferDirection.sent,
    String? filePath,
  }) async {
    if (_transfers.length >= AppConstants.maxTransferQueueSize) {
      throw Exception('Transfer queue is full');
    }

    final transfer = TransferModel(
      id: _uuid.v4(),
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      fileType: fileType,
      mimeType: mimeType,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      direction: direction,
      status: TransferStatus.queued,
      isEncrypted: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _transfers.insert(0, transfer);
    await _db.insert('transfers', transfer.toJson());
    onTransferAdded?.call(transfer);

    // Start processing if possible
    _processQueue();

    return transfer;
  }

  /// Start processing the transfer queue
  Future<void> _processQueue() async {
    final activeCount = activeTransfers.length;
    if (activeCount >= AppConstants.maxSimultaneousTransfers) return;

    final queued = _transfers
        .where((t) => t.status == TransferStatus.queued)
        .toList();

    for (final transfer in queued) {
      if (activeTransfers.length >= AppConstants.maxSimultaneousTransfers) {
        break;
      }
      await _startTransfer(transfer);
    }
  }

  /// Start a single transfer
  Future<void> _startTransfer(TransferModel transfer) async {
    // Skip if already in terminal state
    if (transfer.isTerminal) return;

    // For HTTP-received transfers, the file is already saved by the HTTP
    // handler - mark as completed immediately instead of simulating
    if (transfer.direction == TransferDirection.received &&
        transfer.filePath != null) {
      await _updateTransferStatus(transfer, TransferStatus.completed);
      return;
    }

    // For HTTP-sent transfers, the actual sending is handled by HttpTransferService.
    // We still update status to connecting/transferring so UI can show progress,
    // but we don't simulate - HttpTransferService will call updateProgress/markCompleted.
    if (transfer.direction == TransferDirection.sent &&
        transfer.filePath != null) {
      await _updateTransferStatus(transfer, TransferStatus.connecting);
      await _updateTransferStatus(transfer, TransferStatus.transferring);
      return;
    }

    try {
      await _updateTransferStatus(transfer, TransferStatus.connecting);
      await _updateTransferStatus(transfer, TransferStatus.transferring);

      _cancelTokens[transfer.id] = CancelToken();
      await _simulateTransfer(transfer);
    } catch (e) {
      if (transfer.status != TransferStatus.cancelled) {
        await _updateTransferStatus(
          transfer,
          TransferStatus.failed,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Simulate transfer for development purposes
  Future<void> _simulateTransfer(TransferModel transfer) async {
    final cancelToken = _cancelTokens[transfer.id];
    if (cancelToken == null) return;

    const updateInterval = Duration(milliseconds: 50);
    int transferred = 0;
    const speed = 20000000; // 20 MB/s simulated speed for max throughput
    final totalSize = transfer.fileSize;
    final stopwatch = Stopwatch()..start();

    while (transferred < totalSize) {
      if (cancelToken.isCancelled) return;

      transferred += speed ~/ 20; // per 50ms
      if (transferred > totalSize) transferred = totalSize;

      final progress = (transferred / totalSize * 100);
      final elapsed = stopwatch.elapsedMilliseconds ~/ 1000;
      final currentSpeed = elapsed > 0
          ? (transferred / elapsed).toDouble()
          : speed.toDouble();
      await _updateTransferProgress(
        transfer,
        progress.clamp(0, 100),
        currentSpeed,
      );

      if (transferred >= totalSize) break;
      await Future.delayed(updateInterval);
    }

    await _updateTransferStatus(transfer, TransferStatus.completed);
  }

  /// Mark a transfer as completed
  Future<void> markCompleted(String transferId, {String? filePath}) async {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return;
    await _updateTransferStatus(
      _transfers[index],
      TransferStatus.completed,
      filePath: filePath,
    );
  }

  /// Mark a transfer as failed
  Future<void> markFailed(String transferId, {String? errorMessage}) async {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return;
    await _updateTransferStatus(
      _transfers[index],
      TransferStatus.failed,
      errorMessage: errorMessage,
    );
  }

  /// Update transfer progress
  Future<void> updateProgress(
    String transferId,
    double progress,
    double speed,
  ) async {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return;
    await _updateTransferProgress(_transfers[index], progress, speed);
  }

  /// Update transfer status
  Future<void> _updateTransferStatus(
    TransferModel transfer,
    TransferStatus status, {
    String? errorMessage,
    String? filePath,
  }) async {
    final index = _transfers.indexWhere((t) => t.id == transfer.id);
    if (index < 0) return;

    final updated = transfer.copyWith(
      status: status,
      filePath: filePath,
      errorMessage: errorMessage,
      completedAt: status == TransferStatus.completed ? DateTime.now() : null,
    );

    _transfers[index] = updated;
    await _db.update('transfers', updated.toJson(), 'id = ?', [updated.id]);
    onTransferUpdated?.call(updated);
  }

  /// Update transfer progress
  Future<void> _updateTransferProgress(
    TransferModel transfer,
    double progress,
    double speed,
  ) async {
    final index = _transfers.indexWhere((t) => t.id == transfer.id);
    if (index < 0) return;

    final updated = transfer.copyWith(
      progress: progress,
      speed: speed,
      status: TransferStatus.transferring,
    );

    _transfers[index] = updated;
    await _db.update('transfers', updated.toJson(), 'id = ?', [updated.id]);
    onTransferUpdated?.call(updated);
  }

  /// Pause a transfer
  Future<void> pauseTransfer(String transferId) async {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return;
    final transfer = _transfers[index];
    if (transfer.status != TransferStatus.transferring) return;

    await _updateTransferStatus(transfer, TransferStatus.paused);
  }

  /// Resume a paused transfer
  Future<void> resumeTransfer(String transferId) async {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return;
    final transfer = _transfers[index];
    if (transfer.status != TransferStatus.paused) return;

    await _startTransfer(transfer);
  }

  /// Cancel a transfer
  Future<void> cancelTransfer(String transferId) async {
    final cancelToken = _cancelTokens.remove(transferId);
    cancelToken?.cancel();

    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return;
    final transfer = _transfers[index];
    await _updateTransferStatus(transfer, TransferStatus.cancelled);
  }

  /// Retry a failed transfer
  Future<void> retryTransfer(String transferId) async {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return;
    final transfer = _transfers[index];
    if (transfer.status != TransferStatus.failed) return;

    final updated = transfer.copyWith(
      status: TransferStatus.retrying,
      progress: 0,
      errorMessage: null,
    );

    _transfers[index] = updated;
    await _db.update('transfers', updated.toJson(), 'id = ?', [transferId]);
    onTransferUpdated?.call(updated);

    // If a retry handler is registered (e.g. NearbyConnector), delegate to it
    if (onRetryTransfer != null) {
      await onRetryTransfer!(updated);
    } else {
      await _startTransfer(updated);
    }
  }

  /// Delete a transfer record
  Future<void> deleteTransfer(String transferId) async {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return;
    final transfer = _transfers[index];

    // Clean up file if it exists
    if (transfer.filePath != null) {
      try {
        final file = File(transfer.filePath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    _transfers.removeWhere((t) => t.id == transferId);
    await _db.delete('transfers', 'id = ?', [transferId]);
    onTransferRemoved?.call(transfer);
  }

  /// Open a completed transfer file
  Future<File?> openTransferFile(String transferId) async {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index < 0) return null;
    final transfer = _transfers[index];
    if (transfer.filePath == null) return null;
    final file = File(transfer.filePath!);
    if (await file.exists()) return file;
    return null;
  }

  /// Get transfer statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final totalTransfers = await _db.getTotalTransfers();
    final totalFilesShared = await _db.getTotalFilesShared();
    final totalStorageUsed = await _db.getTotalStorageUsed();
    final transfersByStatus = await _db.getTransfersByStatus();
    final mostShared = await _db.getMostSharedContent();

    return {
      'totalTransfers': totalTransfers,
      'totalFilesShared': totalFilesShared,
      'totalStorageUsed': totalStorageUsed,
      'transfersByStatus': transfersByStatus,
      'mostShared': mostShared,
    };
  }

  /// Clean up resources
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _cancelTokens.clear();
    _transferSubscriptions.clear();
  }
}

class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}
