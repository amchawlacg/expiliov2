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
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfx/pdfx.dart';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint, kIsWeb;
import 'package:flutter/painting.dart' show imageCache;
import 'dart:io' show File, Directory;
import 'dart:io' show File, Directory, FileSystemEntity;
import 'package:flutter/painting.dart' show PaintingBinding;

class AttachmentChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class AttachmentService {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();

 static final AttachmentChangeNotifier onAttachmentsChanged = AttachmentChangeNotifier();
  static void notifyChange() => onAttachmentsChanged.notify();  

  /// Flexible entry point to capture an attachment.
  /// Set [useDocumentScanner] to true for ML Kit edge-detection & auto-cropping (Mobile only),
  /// or false for standard camera/gallery picking via ImagePicker.
  Future<AttachmentModel?> captureAttachment({
    required bool useDocumentScanner,
    ImageSource source = ImageSource.camera,
    String? transactionId,
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
          return await _saveAndCompressNative(
            rawFilePath,
            transactionId: transactionId,
          );
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
      return await _saveAndCompressNative(
        pickedFile.path,
        transactionId: transactionId,
      );
    }
  }

  /// Handles image processing for Web browsers (in-memory paths/blobs)
  Future<AttachmentModel> _processWebImage(
    XFile file, {
    String? transactionId,
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
    String? transactionId,
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
    final XFile? compressedThumb =
        await FlutterImageCompress.compressAndGetFile(
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
    String? transactionId,
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

  Future<int> addAttachment(AttachmentModel attachment) async {
    final now = DateTime.now();

    final newAttachment = attachment.copyWith(
      isSynced: false,
      isDeleted: false,
      createdAt: attachment.createdAt,
      updatedAt: now,
    );

    final id = await _database.insertAttachment(newAttachment);
  await recalculateAndPersistStorageUsed(); // <-- Add this
  notifyChange();
  return id;
  }

  /// Fetches all non-deleted attachments for a transaction
  Future<List<AttachmentModel>> getAttachments(String transactionId) async {
    return await _database.getAttachments(transactionId);
  }

  /// Soft deletes an attachment and enqueues the DELETE sync operation
  Future<int> deleteAttachment(int id) async {
    final result = await _database.deleteAttachment(id);
    notifyChange(); // <-- Triggers silent background reload in InvoiceGalleryScreen
    return result;
  }

  /// Fetches all active attachments joined with their transaction category and date
  Future<List<Map<String, dynamic>>>
  getInvoicesWithTransactionMetadata() async {
    return await _database.getInvoicesWithMetadataRaw();
  }

  /// Copies non-image files (such as PDFs) into permanent app storage
  Future<String> copyToAppStorage(String sourcePath, String fileName) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fullPdfDir = p.join(appDir.path, 'attachments', 'full');

    await Directory(fullPdfDir).create(recursive: true);

    final DateTime now = DateTime.now();
    final String timeStamp = now.millisecondsSinceEpoch.toString();
    final String destinationPath = p.join(fullPdfDir, '${timeStamp}_$fileName');

    final File sourceFile = File(sourcePath);
    final File copiedFile = await sourceFile.copy(destinationPath);
    return copiedFile.path;
  }

  /// Copies the bundled dummy PDF thumbnail asset into a local temp/cache file
  Future<String> getDummyPdfThumbnailPath(String fileName) async {
    final byteData = await rootBundle.load(
      'assets/images/pdf_dummy_thumbnail.png',
    );
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String thumbDir = p.join(appDir.path, 'attachments', 'thumbs');
    await Directory(thumbDir).create(recursive: true);

    final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String outPath = p.join(thumbDir, 'thumb_${timeStamp}_$fileName.png');

    final File file = File(outPath);
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return file.path;
  }


  /// Downloads an attachment from a remote URL to local app storage
  /// Downloads the remote attachment to the user's Downloads directory and saves local_path in SQLite
  Future<String?> downloadAttachmentFile(AttachmentModel attachment) async {
    // 1. Get the remote download URL
    final remoteUrl = attachment.cloudUrl;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      throw Exception("No remote download URL available for this file.");
    }

    // 2. Fetch the file bytes from the remote storage / R2
    final response = await http.get(Uri.parse(remoteUrl));
    if (response.statusCode != 200) {
      throw Exception("Download failed with status: ${response.statusCode}");
    }

    // 3. Resolve the user's Downloads directory
    Directory? targetDir = await getDownloadsDirectory();
    targetDir ??= await getApplicationDocumentsDirectory();

    // 4. Generate filename (avoid overwriting existing files in Downloads)
    final ext = p.extension(attachment.fileName);
    final baseName = p.basenameWithoutExtension(attachment.fileName);
    String filePath = p.join(targetDir.path, attachment.fileName);
    File localFile = File(filePath);

    int counter = 1;
    while (localFile.existsSync()) {
      filePath = p.join(targetDir.path, '${baseName}_$counter$ext');
      localFile = File(filePath);
      counter++;
    }

    // 5. Write file to Downloads
    await localFile.writeAsBytes(response.bodyBytes, flush: true);

    // 6. Persist the new local_path in SQLite
    if (attachment.id != null) {
      await _database.updateAttachmentLocalPath(
        id: attachment.id!,
        localPath: filePath,
      );
    }

    return filePath;
  }

  /// Downloads the lightweight thumbnail to local storage and updates local_thumbnail_path in SQLite
  Future<String?> downloadThumbnailFile(AttachmentModel attachment) async {
    // 1. Check if already present on disk
    if (attachment.localThumbnailPath != null &&
        attachment.localThumbnailPath!.isNotEmpty &&
        File(attachment.localThumbnailPath!).existsSync()) {
      return attachment.localThumbnailPath;
    }

    // 2. Pick the best remote thumbnail source: cloud thumbnail first, fallback to cloud original
    final remoteUrl = (attachment.cloudThumbnailUrl != null &&
            attachment.cloudThumbnailUrl!.isNotEmpty)
        ? attachment.cloudThumbnailUrl
        : attachment.cloudUrl;

    if (remoteUrl == null || remoteUrl.isEmpty) {
      return null;
    }

    try {
      debugPrint("🌐 [THUMB REQ] URL: $remoteUrl");
      final response = await http.get(Uri.parse(remoteUrl));
      debugPrint("🌐 [THUMB REQ] Status Code: ${response.statusCode} (Bytes: ${response.bodyBytes.length})");

      if (response.statusCode != 200) {
        debugPrint("❌ [THUMB REQ] Failed body: ${response.body}");
        return null;
      }

      // 4. Save into app's attachments/thumbs directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String thumbDir = p.join(appDir.path, 'attachments', 'thumbs');
      await Directory(thumbDir).create(recursive: true);

      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String thumbPath =
          p.join(thumbDir, 'thumb_${timeStamp}_${attachment.fileName}.jpg');

      final File localFile = File(thumbPath);
      await localFile.writeAsBytes(response.bodyBytes, flush: true);

      // 5. Persist the new local_thumbnail_path in SQLite
      final db = await _database.database;
      if (attachment.id != null && attachment.id! > 0) {
        await _database.updateAttachmentLocalThumbnailPath(
          id: attachment.id!,
          localThumbnailPath: thumbPath,
        );
      } else if (attachment.transactionId != null) {
        await db.update(
          'attachments',
          {
            'local_thumbnail_path': thumbPath,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'transaction_id = ? AND file_name = ?',
          whereArgs: [attachment.transactionId, attachment.fileName],
        );
      }

      notifyChange();
      return thumbPath;
    } catch (e, stack) {
      debugPrint("❌ [THUMB REQ] Exception: $e\n$stack");
      return null;
    }
  }


  /// Attempts to render Page 1 of a PDF as a thumbnail.
  /// Returns the saved local image path, or null if the file is protected/unrenderable.
  Future<String?> generatePdfThumbnailBestEffort(
    String pdfPath,
    String fileName,
  ) async {
    try {
      final document = await PdfDocument.openFile(pdfPath);
      final page = await document.getPage(1);

      final pageImage = await page.render(
        width: page.width / 2,
        height: page.height / 2,
        format: PdfPageImageFormat.png,
      );

      await page.close();
      await document.close();

      if (pageImage != null) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String thumbDir = p.join(appDir.path, 'attachments', 'thumbs');
        await Directory(thumbDir).create(recursive: true);

        final String timeStamp = DateTime.now().millisecondsSinceEpoch
            .toString();
        final String outPath = p.join(
          thumbDir,
          'thumb_${timeStamp}_$fileName.png',
        );

        final File file = File(outPath);
        await file.writeAsBytes(pageImage.bytes, flush: true);
        return file.path;
      }
    } catch (e) {
      debugPrint(
        "ℹ️ [PDF] Thumbnail rendering skipped (protected or unreadable): $e",
      );
    }
    return null;
  }

  /// Cleans up all cached/saved attachment files and thumbnails from the device disk.
  Future<void> clearAllLocalFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      
      // Target the directory where your app saves attachments (adjust subfolder name if needed)
      final attachmentsDir = Directory('${appDir.path}/attachments');
      if (await attachmentsDir.exists()) {
        await attachmentsDir.delete(recursive: true);
      }

      final thumbsDir = Directory('${appDir.path}/thumbnails');
      if (await thumbsDir.exists()) {
        await thumbsDir.delete(recursive: true);
      }
    } catch (e) {
      // Non-fatal if folder doesn't exist or already empty
    }
  }


  /// Calculates total size of all active attachments and updates the user session in SQLite
Future<double> recalculateAndPersistStorageUsed() async {
  try {
    final session = await _database.getActiveUserSession();
    final uid = session?['id'] as String?;
    if (uid == null || uid.isEmpty) return 0.0;

    // Fetch all active, non-deleted attachments
    final db = await _database.database;
    final records = await db.query(
      'attachments',
      columns: ['local_path'],
      where: 'is_deleted = ?',
      whereArgs: [0],
    );

    int totalBytes = 0;
    if (!kIsWeb) {
      for (final row in records) {
        final path = row['local_path'] as String?;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (file.existsSync()) {
            totalBytes += file.lengthSync();
          }
        }
      }
    }

    final double totalMB = totalBytes / (1024 * 1024);

    await _database.updateUserStorageStats(
      uid: uid,
      storageUsedMb: totalMB,
    );

    return totalMB;
  } catch (e) {
    debugPrint("Failed to recalculate storage: $e");
    return 0.0;
  }
}


/// Clears in-memory image cache and generated thumbnail cache files
Future<void> clearImageCacheOnly() async {
  try {
    // 1. Evict all cached images from Flutter engine memory
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // 2. Clear cached thumbnail directory on disk (if native)
    if (!kIsWeb) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory thumbsDir = Directory(p.join(appDir.path, 'attachments', 'thumbs'));
      if (await thumbsDir.exists()) {
        await thumbsDir.delete(recursive: true);
        await thumbsDir.create(recursive: true);
      }
    }

    // 3. Recalculate storage stats and notify listeners
    await recalculateAndPersistStorageUsed();
    notifyChange();
  } catch (e) {
    debugPrint("Failed to clear image cache: $e");
  }
}

}
