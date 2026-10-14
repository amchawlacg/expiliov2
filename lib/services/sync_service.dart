import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../database/database_helper.dart';
import '../models/attachment.dart';
import '../models/sync_queue_item.dart';
import '../models/transaction.dart';
import '../utils/app_logger.dart';
import 'attachment_service.dart';
import 'preference_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

class SyncService {
  // --- Singleton Implementation ---
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();
  // ---------------------------------

  /// Global notifier that fires whenever transactions are downloaded/hydrated
  static final ValueNotifier<int> onDataChanged = ValueNotifier<int>(0);

  final DatabaseHelper _database = DatabaseHelper.instance;
  final AttachmentService _attachmentService = AttachmentService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isSyncing = false;
  // Base URL for your API backend
  final String _baseUrl = 'https://phpstack-1559747-6613825.cloudwaysapps.com';

  /// Call this on app startup (e.g. in main.dart) to listen for network restored events
  void initializeAutoSync() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        final hasConnection =
            results.any((result) => result != ConnectivityResult.none);
        if (!hasConnection) return;

        // Check if Wi-Fi only restriction is active
        final syncWifiOnly = await PreferencesService.getSyncWifiOnly();
        final isWifi = results.contains(ConnectivityResult.wifi);

        if (syncWifiOnly && !isWifi) {
          appLog(
            '⏸️ [SYNC] Auto-sync skipped: Wi-Fi only enabled but connected via mobile/other.',
          );
          return;
        }

        processSyncQueue();
      },
    );
  }

  /// Clean up connectivity listener when app or service is disposed
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Processes pending items in the queue.
  /// Returns a Map with status and message for caller feedback (e.g., ProfileScreen UI).
  Future<Map<String, dynamic>> processSyncQueue({bool force = false}) async {
    // Prevent multiple concurrent sync runs
    if (_isSyncing) {
      return {'success': false, 'message': 'Sync already in progress.'};
    }

    // Network & Wi-Fi Check
    final connectivityResults = await _connectivity.checkConnectivity();
    final hasConnection =
        connectivityResults.any((r) => r != ConnectivityResult.none);

    if (!hasConnection) {
      return {
        'success': false,
        'message': 'No internet connection available.',
      };
    }

    if (!force) {
      final syncWifiOnly = await PreferencesService.getSyncWifiOnly();
      final isWifi = connectivityResults.contains(ConnectivityResult.wifi);
      if (syncWifiOnly && !isWifi) {
        return {
          'success': false,
          'message': 'Sync paused: Wi-Fi only mode is turned on.',
        };
      }
    }

    _isSyncing = true;

    try {
      final List<SyncQueueItem> pendingItems =
          await _database.getPendingSyncItems();

      if (pendingItems.isEmpty) {
        await PreferencesService.saveLastSyncedAt(
          DateTime.now().millisecondsSinceEpoch,
        );
        return {'success': true, 'message': 'Everything is already up to date.'};
      }

      int syncedCount = 0;

      for (final item in pendingItems) {
        // If sync lock was released externally or cancelled, halt execution
        if (!_isSyncing) break;

        try {
          final bool success = await _dispatchSyncItem(item);

          if (success && item.id != null) {
            if (!_isSyncing) break;
            await _database.deleteSyncQueueItem(item.id!);
            syncedCount++;
          } else {
            return {
              'success': false,
              'message': 'Sync paused: server rejected item ${item.entityType}.',
            };
          }
        } catch (e) {
          appLog('Sync failed for queue item ${item.id}: $e');
          return {
            'success': false,
            'message': 'Sync failed: network or server error.',
          };
        }
      }

      await PreferencesService.saveLastSyncedAt(
        DateTime.now().millisecondsSinceEpoch,
      );
      return {
        'success': true,
        'message': 'Synced $syncedCount item(s) successfully.',
      };
    } catch (e) {
      appLog('Error reading or processing sync queue: $e');
      return {
        'success': false,
        'message': 'An unexpected sync error occurred.',
      };
    } finally {
      _isSyncing = false;
    }
  }

  /// Routes sync operations based on entity_type (transaction vs attachment)
  Future<bool> _dispatchSyncItem(SyncQueueItem item) async {
    if (item.entityType == 'attachment') {
      return await _processAttachmentSync(item);
    } else {
      return await _processTransactionSync(item);
    }
  }

  Future<bool> _processTransactionSync(SyncQueueItem item) async {
    final headers = {'Content-Type': 'application/json'};
    

    switch (item.action) {
      case 'CREATE':
      case 'UPDATE':
        final bodyData = item.payload is String
            ? item.payload as String
            : jsonEncode(item.payload);

        final response = await http.post(
          Uri.parse('$_baseUrl/transactions'),
          headers: headers,
          body: bodyData,
        );
        return response.statusCode == 200 || response.statusCode == 201;

      case 'DELETE':
        final response = await http.delete(
          Uri.parse('$_baseUrl/transactions/${item.entityId}'),
          headers: headers,
        );
        return response.statusCode == 200 || response.statusCode == 204;

      default:
        return false;
    }
  }

  Future<bool> _processAttachmentSync(SyncQueueItem item) async {
    // --- Handle Attachment DELETE ---
    if (item.action == 'DELETE') {
      appLog('🟡 [SYNC] Deleting attachment with ID: ${item.entityId}');
      final response = await http.delete(
        Uri.parse('$_baseUrl/attachments/${item.entityId}'),
        headers: {'Content-Type': 'application/json'},
      );
      final isSuccess = response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404;
      appLog('🔵 [SYNC] Attachment DELETE status code: ${response.statusCode}');
      return isSuccess;
    }

    if (item.payload == null) return false;

    appLog('🟡 [SYNC] Starting attachment sync for item ID: ${item.id}');

    final Map<String, dynamic> payloadMap = item.payload is String
        ? jsonDecode(item.payload as String)
        : Map<String, dynamic>.from(item.payload as Map);

    final AttachmentModel attachment = AttachmentModel.fromMap(payloadMap);

    if (item.action == 'CREATE') {
      // 1. Presigned URL Request
      appLog('🟡 [SYNC] Requesting presigned URL for: ${attachment.fileName}');
      final presignedResponse = await http.post(
        Uri.parse('$_baseUrl/attachments/presigned-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_name': attachment.fileName,
          'transaction_id': attachment.transactionId,
        }),
      );

      appLog('🔵 [SYNC] Presigned URL Response Code: ${presignedResponse.statusCode}');
      appLog('🔵 [SYNC] Presigned URL Body: ${presignedResponse.body}');

      if (presignedResponse.statusCode != 200) {
        appLog('❌ [SYNC] Failed to get presigned URL');
        return false;
      }

      final presignedData = jsonDecode(presignedResponse.body);
      final String fullUploadUrl = presignedData['full_upload_url'];
      final String? thumbUploadUrl = presignedData['thumb_upload_url'];
      final String cloudUrl = presignedData['cloud_url'];
      final String cloudThumbnailUrl =
          presignedData['cloud_thumbnail_url'] ?? '';

      // Determine file MIME type dynamically
      final bool isPdf = attachment.fileName.toLowerCase().endsWith('.pdf') ||
          attachment.fileType == 'application/pdf';
      final String fileContentType = isPdf ? 'application/pdf' : 'image/jpeg';

      // 2. Upload Full File (PDF or Image) to Cloudflare R2
      if (attachment.localPath != null && attachment.localPath!.isNotEmpty) {
        appLog('🟡 [SYNC] Uploading full file to R2 presigned URL...');
        final File localFile = File(attachment.localPath!);

        if (!localFile.existsSync()) {
          appLog('❌ [SYNC] Local file does not exist at path: ${attachment.localPath}');
          return false;
        }

        final Uint8List fullBytes = await localFile.readAsBytes();

        final uploadRes = await http.put(
          Uri.parse(fullUploadUrl),
          headers: {'Content-Type': fileContentType},
          body: fullBytes,
        );

        appLog('🔵 [SYNC] Full File R2 Upload Status: ${uploadRes.statusCode} (${fullBytes.lengthInBytes} bytes)');

        if (uploadRes.statusCode != 200) {
          appLog('❌ [SYNC] Full file R2 upload failed');
          return false;
        }
      }

      // 3. Upload Thumbnail to Cloudflare R2
      if (thumbUploadUrl != null &&
          thumbUploadUrl.isNotEmpty &&
          attachment.localThumbnailPath != null &&
          attachment.localThumbnailPath!.isNotEmpty) {
        final File thumbFile = File(attachment.localThumbnailPath!);

        if (thumbFile.existsSync()) {
          appLog('🟡 [SYNC] Uploading thumbnail to R2 presigned URL...');
          final Uint8List thumbBytes = await thumbFile.readAsBytes();

          final thumbUploadRes = await http.put(
            Uri.parse(thumbUploadUrl),
            headers: {'Content-Type': 'image/png'},
            body: thumbBytes,
          );

          appLog('🔵 [SYNC] Thumbnail R2 Upload Status: ${thumbUploadRes.statusCode} (${thumbBytes.lengthInBytes} bytes)');
        }
      }

      // 4. Backend Confirmation
      final bool hasThumb = attachment.localThumbnailPath != null &&
          attachment.localThumbnailPath!.isNotEmpty &&
          File(attachment.localThumbnailPath!).existsSync();

      appLog('🟡 [SYNC] Confirming upload with backend database...');
      // Ensure Firebase Auth is imported at top: import 'package:firebase_auth/firebase_auth.dart';

final currentUserId = FirebaseAuth.instance.currentUser?.uid;
final String resolvedUserId = payloadMap['user_id'] ?? currentUserId ?? 'usr_test'; // ✅ Dynamic fallback

final confirmResponse = await http.post(
  Uri.parse('$_baseUrl/attachments/confirm'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'id': attachment.id,
    'user_id': resolvedUserId,
    'transaction_id': attachment.transactionId,
    'file_name': attachment.fileName,
    'cloud_url': cloudUrl,
    'cloud_thumbnail_url': hasThumb ? cloudThumbnailUrl : null,
    'file_type': isPdf ? 'application/pdf' : (attachment.fileType ?? 'image/jpeg'),
  }),
);

      appLog('🔵 [SYNC] Confirm Endpoint Status Code: ${confirmResponse.statusCode}');
      appLog('🔵 [SYNC] Confirm Endpoint Body: ${confirmResponse.body}');

      if (confirmResponse.statusCode == 200 ||
          confirmResponse.statusCode == 201) {
        appLog('✅ [SYNC] Attachment sync complete and confirmed!');
        return true;
      } else {
        appLog('❌ [SYNC] Confirmation failed with status code: ${confirmResponse.statusCode}');
        return false;
      }
    }

    return false;
  }

  /// Temporary helper to purge stuck items from sync queue
  Future<void> clearQueue() async {
    final db = await _database.database;
    await db.delete('sync_queue');
    appLog('🧹 [SYNC] Sync queue table cleared completely.');
  }

  /// Or clear only a specific stuck item by its sync_queue ID
  Future<void> clearQueueItem(int queueItemId) async {
    await _database.deleteSyncQueueItem(queueItemId);
    appLog('🧹 [SYNC] Removed item $queueItemId from sync queue.');
  }

  /// Cancels listeners and locks sync operations during account deletion or logout.
  Future<void> stopAndReset() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // Halt any active sync loops
    _isSyncing = false;

    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Unlocks the sync flag and re-initializes connectivity listeners on login
  void resumeSync() {
    _isSyncing = false;
    if (!kIsWeb) {
      initializeAutoSync();
    }
  }

  /// Pulls all transactions and cloud attachments from the remote server for the logged-in user
  Future<bool> pullRemoteData(String userId) async {
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse(
        '$_baseUrl/transactions?user_id=$userId&_cb=$cacheBuster',
      );

      // 15-second timeout ensures the app never hangs indefinitely on login/pull
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
              'X-User-Id': userId,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        appLog('❌ [SYNC] Failed to fetch remote transactions. Code: ${response.statusCode}');
        return false;
      }

      final List<dynamic> rawList = jsonDecode(response.body);
      final List<TransactionModel> transactions = [];
      final List<AttachmentModel> attachments = [];

      for (var item in rawList) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        final List<AttachmentModel> itemAttachments = [];

        if (map['attachments'] != null && map['attachments'] is List) {
          for (var aMap in (map['attachments'] as List)) {
            final att = AttachmentModel.fromMap(Map<String, dynamic>.from(aMap));
            itemAttachments.add(att);
            attachments.add(att);
          }
        }

        transactions.add(
          TransactionModel.fromMap(map, attachments: itemAttachments),
        );
      }

      await _database.hydrateDatabaseFromRemote(
        transactions: transactions,
        attachments: attachments,
      );

      // Notify all screens to refresh data immediately
      onDataChanged.value++;

      // 👇 ADD THIS: Download missing thumbnails right after hydration
      if (attachments.isNotEmpty) {
        unawaited(_downloadMissingThumbnails(attachments));
      }

      await PreferencesService.saveLastSyncedAt(
        DateTime.now().millisecondsSinceEpoch,
      );
      appLog('✅ [SYNC] Successfully restored ${transactions.length} transactions and ${attachments.length} attachments.');
      return true;
    } on TimeoutException {
      appLog('⏱️ [SYNC] pullRemoteData timed out after 15 seconds.');
      return false;
    } catch (e) {
      appLog('❌ [SYNC] Error during pullRemoteData: $e');
      return false;
    }
  }

  Future<void> _downloadMissingThumbnails(List<AttachmentModel> attachments) async {
    for (final att in attachments) {
      final hasLocalThumb = att.localThumbnailPath != null &&
          att.localThumbnailPath!.isNotEmpty &&
          File(att.localThumbnailPath!).existsSync();

      if (!hasLocalThumb &&
          ((att.cloudThumbnailUrl != null && att.cloudThumbnailUrl!.isNotEmpty) ||
              (att.cloudUrl != null && att.cloudUrl!.isNotEmpty))) {
        try {
          appLog('📥 [SYNC] Downloading thumbnail for: ${att.fileName}');
          final savedPath = await _attachmentService.downloadThumbnailFile(att); // 👈 capture path
          appLog('✅ [SYNC] Thumbnail saved locally at: $savedPath');            // 👈 add this
        } catch (e) {
          appLog('❌ [SYNC] Failed thumbnail download for ${att.fileName}: $e');
        }
      }
    }
    // Refresh the UI so the downloaded thumbnails show up immediately
    onDataChanged.value++;
  }
}