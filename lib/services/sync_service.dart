import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../models/sync_queue_item.dart';

class SyncService {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Call this on app startup (e.g. in main.dart) to listen for network restored events
  void initializeAutoSync() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final hasConnection = results.any((result) => result != ConnectivityResult.none);
        if (hasConnection) {
          processSyncQueue();
        }
      },
    );
  }

  /// Clean up connectivity listener when app or service is disposed
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Iterates through pending items and pushes them sequentially
  Future<void> processSyncQueue() async {
    final List<SyncQueueItem> pendingItems = await _database.getPendingSyncItems();

    if (pendingItems.isEmpty) return;

    for (final item in pendingItems) {
      try {
        final bool success = await _sendToBackend(item);

        if (success && item.id != null) {
          // Remove from queue upon successful remote operation
          await _database.deleteSyncQueueItem(item.id!);
        } else {
          // Pause execution if the server rejected the operation to maintain order
          break;
        }
      } catch (e) {
        // Network drop or exception—break loop and retry during next sync attempt
        print('Sync failed for queue item ${item.id}: $e');
        break;
      }
    }
  }

  /// Sends the action and payload to your cloud backend.
  /// Replace the placeholder logic below with your HTTP/Firebase API calls.
  Future<bool> _sendToBackend(SyncQueueItem item) async {
    switch (item.action) {
      case 'CREATE':
        // Example: POST /api/v1/transactions
        // Body: item.payload
        break;

      case 'UPDATE':
        // Example: PUT /api/v1/transactions/${item.entityId}
        // Body: item.payload
        break;

      case 'DELETE':
        // Example: DELETE /api/v1/transactions/${item.entityId}
        break;
    }

    // Return true when receiving an HTTP 200/201 Success status from server
    return true;
  }
}