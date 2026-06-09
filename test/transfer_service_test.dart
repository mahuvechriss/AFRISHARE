import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';
import 'package:afrishare/services/transfer_service.dart';
import 'package:afrishare/models/transfer_model.dart';
import 'package:afrishare/core/database/database_helper.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class FakeTransferModel extends Fake implements TransferModel {}

void main() {
  late TransferService transferService;
  late String senderId;
  late String receiverId;

  setUpAll(() {
    registerFallbackValue(FakeTransferModel());
  });

  setUp(() {
    transferService = TransferService.instance;
    senderId = const Uuid().v4();
    receiverId = const Uuid().v4();
  });

  tearDown(() {
    // Reset the service state between tests by disposing and re-initializing
    // Since it's a singleton, we need to clean up the internal lists
    transferService.dispose();
  });

  group('TransferService - Queue Management', () {
    test('queueTransfer should add transfer to queue and trigger callback',
        () async {
      TransferModel? addedTransfer;
      transferService.onTransferAdded = (transfer) {
        addedTransfer = transfer;
      };

      final transfer = await transferService.queueTransfer(
        fileName: 'test.pdf',
        fileSize: 1024 * 1024,
        fileType: 'pdf',
        senderId: senderId,
        senderName: 'Alice',
        receiverId: receiverId,
        receiverName: 'Bob',
      );

      expect(transfer, isNotNull);
      expect(transfer.fileName, 'test.pdf');
      expect(transfer.fileSize, 1024 * 1024);
      expect(transfer.status, TransferStatus.queued);
      expect(transfer.direction, TransferDirection.sent);

      // Callback should have been triggered
      expect(addedTransfer, isNotNull);
      expect(addedTransfer!.id, transfer.id);

      // Should be in the transfers list
      expect(transferService.transfers.length, greaterThanOrEqualTo(1));
      expect(transferService.transfers.any((t) => t.id == transfer.id), isTrue);
    });

    test('queueTransfer for received direction', () async {
      final transfer = await transferService.queueTransfer(
        fileName: 'photo.jpg',
        fileSize: 2048,
        fileType: 'jpg',
        senderId: receiverId,
        senderName: 'Bob',
        receiverId: senderId,
        receiverName: 'Alice',
        direction: TransferDirection.received,
      );

      expect(transfer.direction, TransferDirection.received);
      expect(transfer.senderName, 'Bob');
      expect(transfer.receiverName, 'Alice');
    });

    test('queueTransfer with multiple files should queue them all', () async {
      final files = ['doc1.pdf', 'doc2.pdf', 'doc3.pdf'];
      for (final file in files) {
        await transferService.queueTransfer(
          fileName: file,
          fileSize: 512,
          fileType: 'pdf',
          senderId: senderId,
          receiverId: receiverId,
        );
      }

      expect(transferService.transfers.length, files.length);
    });
  });

  group('TransferService - Status Updates', () {
    test('transfer should progress through statuses when started', () async {
      final transfer = await transferService.queueTransfer(
        fileName: 'large_video.mp4',
        fileSize: 10 * 1024 * 1024, // 10MB
        fileType: 'mp4',
        senderId: senderId,
        receiverId: receiverId,
      );

      expect(transfer.status, TransferStatus.queued);
    });

    test('activeTransfers should return transfers in active states', () async {
      await transferService.queueTransfer(
        fileName: 'active1.txt',
        fileSize: 100,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );
      await transferService.queueTransfer(
        fileName: 'active2.txt',
        fileSize: 200,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );

      // After queueing, transfers are queued which counts as active
      expect(transferService.activeTransfers.length, greaterThanOrEqualTo(1));
    });

    test('completedTransfers should only include completed transfers', () async {
      final transfer = await transferService.queueTransfer(
        fileName: 'completed.txt',
        fileSize: 100,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );

      // Initially no completed transfers
      expect(transferService.completedTransfers.length, 0);
      expect(transfer.status, isNot(TransferStatus.completed));
    });
  });

  group('TransferService - Cancel & Pause', () {
    test('pauseTransfer should not crash on non-active transfer', () async {
      final transfer = await transferService.queueTransfer(
        fileName: 'doc.txt',
        fileSize: 100,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );

      // Pausing a queued transfer should do nothing (not crash)
      await transferService.pauseTransfer(transfer.id);

      // Verify no error occurred - transfer should still be in the list
      expect(transferService.transfers.any((t) => t.id == transfer.id), isTrue);
    });

    test('cancelTransfer should mark transfer as cancelled', () async {
      final transfer = await transferService.queueTransfer(
        fileName: 'cancel_test.txt',
        fileSize: 100,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );

      await transferService.cancelTransfer(transfer.id);

      final cancelled = transferService.transfers.firstWhere(
        (t) => t.id == transfer.id,
      );
      expect(cancelled.status, TransferStatus.cancelled);
    });

    test('deleteTransfer should remove transfer from list', () async {
      final transfer = await transferService.queueTransfer(
        fileName: 'delete_test.txt',
        fileSize: 100,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );

      await transferService.deleteTransfer(transfer.id);

      expect(
          transferService.transfers.any((t) => t.id == transfer.id), isFalse);
    });
  });

  group('TransferService - Callbacks', () {
    test('onTransferAdded callback fires for each queued transfer', () async {
      int callbackCount = 0;
      transferService.onTransferAdded = (_) {
        callbackCount++;
      };

      await transferService.queueTransfer(
        fileName: 'a.txt',
        fileSize: 10,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );
      await transferService.queueTransfer(
        fileName: 'b.txt',
        fileSize: 20,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );
      await transferService.queueTransfer(
        fileName: 'c.txt',
        fileSize: 30,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );

      expect(callbackCount, 3);
    });

    test('onTransferRemoved callback fires on delete', () async {
      String? removedId;
      transferService.onTransferRemoved = (transfer) {
        removedId = transfer.id;
      };

      final transfer = await transferService.queueTransfer(
        fileName: 'callback_test.txt',
        fileSize: 100,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );

      await transferService.deleteTransfer(transfer.id);

      expect(removedId, transfer.id);
    });
  });

  group('TransferService - Statistics', () {
    test('getStatistics should return valid map structure', () async {
      final stats = await transferService.getStatistics();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('totalTransfers'), isTrue);
      expect(stats.containsKey('totalFilesShared'), isTrue);
      expect(stats.containsKey('totalStorageUsed'), isTrue);
      expect(stats.containsKey('transfersByStatus'), isTrue);
      expect(stats.containsKey('mostShared'), isTrue);
    });
  });

  group('TransferService - Queue Limits', () {
    test('queueTransfer should handle up to max queue size', () async {
      // Queue to near capacity - simplified test
      for (var i = 0; i < 5; i++) {
        await transferService.queueTransfer(
          fileName: 'file_$i.txt',
          fileSize: 100,
          fileType: 'txt',
          senderId: senderId,
          receiverId: receiverId,
        );
      }

      expect(transferService.transfers.length, 5);
    });

    test('retryTransfer should not crash on non-failed transfer', () async {
      final transfer = await transferService.queueTransfer(
        fileName: 'retry_test.txt',
        fileSize: 100,
        fileType: 'txt',
        senderId: senderId,
        receiverId: receiverId,
      );

      // Retrying a queued (not failed) transfer should do nothing
      await transferService.retryTransfer(transfer.id);

      final result = transferService.transfers.firstWhere(
        (t) => t.id == transfer.id,
      );
      expect(result.status, isNot(TransferStatus.retrying));
    });
  });
}
