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

  Future<int> addAttachment(AttachmentModel attachment) async {
    final now = DateTime.now();

    final newAttachment = attachment.copyWith(
      isSynced: false,
      isDeleted: false,
      createdAt: attachment.createdAt,
      updatedAt: now,
    );

    final id = await _database.insertAttachment(newAttachment);
    notifyChange(); // <-- Triggers silent background reload in InvoiceGalleryScreen
    return id;
  }

  /// Fetches all non-deleted attachments for a transaction
  Future<List<AttachmentModel>> getAttachments(int transactionId) async {
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
  /// Downloads the remote attachment to local storage and saves local_path in SQLite
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

    // 3. Save to local app storage
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fullDir = p.join(appDir.path, 'attachments', 'full');
    await Directory(fullDir).create(recursive: true);

    final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String filePath = p.join(fullDir, '${timeStamp}_${attachment.fileName}');

    final File localFile = File(filePath);
    await localFile.writeAsBytes(response.bodyBytes, flush: true);

    // 4. Persist the new local_path in SQLite so it never has to download again
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
      // 3. Download the thumbnail bytes
      final response = await http.get(Uri.parse(remoteUrl));
      if (response.statusCode != 200) return null;

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
      if (attachment.id != null) {
        await _database.updateAttachmentLocalThumbnailPath(
          id: attachment.id!,
          localThumbnailPath: thumbPath,
        );
      }

      return thumbPath;
    } catch (e) {
      debugPrint("Failed to download thumbnail: $e");
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
}
