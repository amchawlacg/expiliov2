import 'dart:convert';
import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../models/attachment.dart';

class AttachmentService {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();

  /// Flexible entry point to capture an attachment.
  /// Set [useDocumentScanner] to true for ML Kit edge-detection & auto-cropping (Mobile only),
  /// or false for standard camera/gallery picking via ImagePicker.
  Future<AttachmentModel?> captureAttachment({
    required bool useDocumentScanner,
    ImageSource source = ImageSource.camera,
    int? transactionId,
  }) async {
    // 1. ML Kit Document Scanner (Mobile only)
    if (!kIsWeb && useDocumentScanner && source == ImageSource.camera) {
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: 1,
      );
      final documentScanner = DocumentScanner(options: options);

      try {
        final result = await documentScanner.scanDocument();
        if (result.images.isNotEmpty) {
          final rawFilePath = result.images.first;
          return await _saveAndCompressNative(rawFilePath, transactionId: transactionId);
        }
      } catch (e) {
        debugPrint('Document scanner error or cancelled: $e');
        return null;
      }
    }

    // 2. Standard ImagePicker (Supports Web, iOS, Android, Desktop)
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) return null;

    if (kIsWeb) {
      return await _processWebImage(pickedFile, transactionId: transactionId);
    } else {
      return await _saveAndCompressNative(pickedFile.path, transactionId: transactionId);
    }
  }

  /// Handles image processing for Web browsers (in-memory paths/blobs)
  Future<AttachmentModel> _processWebImage(
    XFile file, {
    int? transactionId,
  }) async {
    final DateTime now = DateTime.now();
    final String timeStamp = now.millisecondsSinceEpoch.toString();
    final String fileName = '${timeStamp}_${file.name}';

    return AttachmentModel(
      transactionId: transactionId,
      fileName: fileName,
      localPath: file.path, // On web, this contains the blob URL or object URL
      localThumbnailPath: file.path,
      fileType: 'image/jpeg',
      isSynced: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Handles persistent storage and thumbnail compression for native platforms (iOS, Android, macOS)
  /// Handles persistent storage and image/thumbnail compression for native platforms
  Future<AttachmentModel> _saveAndCompressNative(
    String rawFilePath, {
    int? transactionId,
  }) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final DateTime now = DateTime.now();
    final String timeStamp = now.millisecondsSinceEpoch.toString();
    final String baseName = p.basenameWithoutExtension(rawFilePath);
    final String fileName = '${timeStamp}_$baseName.jpg';

    final String fullImageDir = p.join(appDir.path, 'attachments', 'full');
    final String thumbImageDir = p.join(appDir.path, 'attachments', 'thumbs');

    await Directory(fullImageDir).create(recursive: true);
    await Directory(thumbImageDir).create(recursive: true);

    final String fullImagePath = p.join(fullImageDir, fileName);
    final String thumbImagePath = p.join(thumbImageDir, 'thumb_$fileName');

    // 1. Compress and save full image (Max 1920x1080, 80% quality)
    final XFile? compressedFull = await FlutterImageCompress.compressAndGetFile(
      rawFilePath,
      fullImagePath,
      minWidth: 1920,
      minHeight: 1080,
      quality: 80,
      format: CompressFormat.jpeg,
    );

    final String finalFullPath = compressedFull?.path ?? fullImagePath;
    if (compressedFull == null) {
      await File(rawFilePath).copy(fullImagePath);
    }

    // 2. Generate and save low-res thumbnail (~150px, 50% quality)
    final XFile? compressedThumb = await FlutterImageCompress.compressAndGetFile(
      finalFullPath,
      thumbImagePath,
      minWidth: 150,
      minHeight: 150,
      quality: 50,
      format: CompressFormat.jpeg,
    );

    return AttachmentModel(
      transactionId: transactionId,
      fileName: fileName,
      localPath: finalFullPath,
      localThumbnailPath: compressedThumb?.path ?? finalFullPath,
      fileType: 'image/jpeg',
      isSynced: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Public helper to process, compress, and create thumbnails from any file path
  Future<AttachmentModel> processPickedFilePath(
    String filePath, {
    int? transactionId,
  }) async {
    return await _saveAndCompressNative(filePath, transactionId: transactionId);
  }

  /// Uploads binary file bytes directly to Cloudflare R2 using a presigned URL.
  /// Works across Web, iOS, Android, and Desktop via XFile bytes.
  Future<bool> uploadToPresignedUrl({
    required String localFilePath,
    required String presignedUrl,
  }) async {
    try {
      final XFile xFile = XFile(localFilePath);
      final bytes = await xFile.readAsBytes();

      if (bytes.isEmpty) return false;

      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {'Content-Type': 'image/jpeg'},
        body: bytes,
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Failed to upload attachment to R2: $e');
      return false;
    }
  }

  /// Inserts a newly picked attachment record into the database and sync queue
  Future<int> addAttachment(AttachmentModel attachment) async {
    final now = DateTime.now();

    final newAttachment = attachment.copyWith(
      isSynced: false,
      isDeleted: false,
      createdAt: attachment.createdAt,
      updatedAt: now,
    );

    return await _database.insertAttachment(newAttachment);
  }

  /// Fetches all non-deleted attachments for a transaction
  Future<List<AttachmentModel>> getAttachments(int transactionId) async {
    return await _database.getAttachments(transactionId);
  }

  /// Soft deletes an attachment and enqueues the DELETE sync operation
  Future<int> deleteAttachment(int id) async {
    return await _database.deleteAttachment(id);
  }
}