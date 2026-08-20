import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import '../models/attachment.dart';
import '../models/sync_queue_item.dart';
import 'attachment_service.dart';
import 'dart:io';
import 'dart:typed_data'; // Defines Uint8List
import 'package:image_picker/image_picker.dart'; // Defines XFile (or: import 'package:cross_file/cross_file.dart';)
import '../utils/app_logger.dart';

class SyncService {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final AttachmentService _attachmentService = AttachmentService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isSyncing = false; // <-- Add this lock flag
  // Base URL for your API backend
  final String _baseUrl = 'https://phpstack-1559747-6613825.cloudwaysapps.com';

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

  Future<void> processSyncQueue() async {
    // Prevent multiple concurrent sync runs
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final List<SyncQueueItem> pendingItems = await _database.getPendingSyncItems();

      if (pendingItems.isEmpty) return;

      for (final item in pendingItems) {
        try {
          final bool success = await _dispatchSyncItem(item);

          if (success && item.id != null) {
            // Remove from queue upon successful remote operation
            await _database.deleteSyncQueueItem(item.id!);
          } else {
            // Pause execution if the server rejected the operation to maintain order
            break;
          }
        } catch (e) {
          // Network drop or exception—break loop and retry during next sync attempt
          appLog('Sync failed for queue item ${item.id}: $e');
          break;
        }
      }
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

 /// Handles transaction CRUD API syncing
  Future<bool> _processTransactionSync(SyncQueueItem item) async {
    final headers = {'Content-Type': 'application/json'};

    switch (item.action) {
      case 'CREATE':
      case 'UPDATE':
        // Ensure payload is a valid JSON string
        final bodyData = item.payload is String
            ? item.payload as String
            : jsonEncode(item.payload);

        // Backend uses INSERT ... ON DUPLICATE KEY UPDATE on POST /transactions
        final response = await http.post(
          Uri.parse('$_baseUrl/transactions'),
          headers: headers,
          body: bodyData,
        );
        return response.statusCode == 200 || response.statusCode == 201;

      case 'DELETE':
        // Replace with your real user ID variable (e.g., _authService.userId or 'default_user')
        final String currentUserId = 'usr_test'; 
        final String serverId = '${currentUserId}_${item.entityId}';

        final response = await http.delete(
          Uri.parse('$_baseUrl/transactions/$serverId'),
          headers: headers,
        );
        return response.statusCode == 200 || response.statusCode == 204;

      default:
        return false;
    }
  }

/// Handles attachment file uploads to Cloudflare R2 via Presigned URLs
/// Handles attachment file uploads to Cloudflare R2 via Presigned URLs
  Future<bool> _processAttachmentSync(SyncQueueItem item) async {
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
      final String cloudThumbnailUrl = presignedData['cloud_thumbnail_url'] ?? '';

      // 2. Upload Full Image to Cloudflare R2
      if (attachment.localPath != null && attachment.localPath!.isNotEmpty) {
        appLog('🟡 [SYNC] Uploading full image to R2 presigned URL...');
        final XFile fullXFile = XFile(attachment.localPath!);
        final Uint8List fullBytes = await fullXFile.readAsBytes();

        final uploadRes = await http.put(
          Uri.parse(fullUploadUrl),
          headers: {'Content-Type': 'image/jpeg'},
          body: fullBytes,
        );

        appLog('🔵 [SYNC] Full Image R2 Upload Status: ${uploadRes.statusCode} (${fullBytes.lengthInBytes} bytes)');

        if (uploadRes.statusCode != 200) {
          appLog('❌ [SYNC] Full image R2 upload failed');
          return false;
        }
      }

      // 3. Upload Thumbnail to Cloudflare R2
      if (thumbUploadUrl != null &&
          thumbUploadUrl.isNotEmpty &&
          attachment.localThumbnailPath != null &&
          attachment.localThumbnailPath!.isNotEmpty) {
        appLog('🟡 [SYNC] Uploading thumbnail to R2 presigned URL...');
        final XFile thumbXFile = XFile(attachment.localThumbnailPath!);
        final Uint8List thumbBytes = await thumbXFile.readAsBytes();

        final thumbUploadRes = await http.put(
          Uri.parse(thumbUploadUrl),
          headers: {'Content-Type': 'image/jpeg'},
          body: thumbBytes,
        );

        appLog('🔵 [SYNC] Thumbnail R2 Upload Status: ${thumbUploadRes.statusCode} (${thumbBytes.lengthInBytes} bytes)');
      }

      // 4. Backend Confirmation
      appLog('🟡 [SYNC] Confirming upload with backend database...');
      final confirmResponse = await http.post(
        Uri.parse('$_baseUrl/attachments/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': attachment.id,
          'user_id': payloadMap['user_id'] ?? 'usr_test',
          'transaction_id': attachment.transactionId,
          'file_name': attachment.fileName,
          'cloud_url': cloudUrl,
          'cloud_thumbnail_url': cloudThumbnailUrl,
          'file_type': attachment.fileType ?? 'image/jpeg',
        }),
      );

      appLog('🔵 [SYNC] Confirm Endpoint Status Code: ${confirmResponse.statusCode}');
      appLog('🔵 [SYNC] Confirm Endpoint Body: ${confirmResponse.body}');

      if (confirmResponse.statusCode == 200 || confirmResponse.statusCode == 201) {
        appLog('✅ [SYNC] Attachment sync complete and confirmed!');
        return true;
      }
    }

    return false;
  }
}