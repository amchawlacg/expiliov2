import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/attachment.dart';
import '../widgets/attachment_thumbnail_view.dart';

import '../services/attachment_service.dart';

import '../database/database_helper.dart';
import '../screens/add_transaction_screen.dart'; // Adjust path if located elsewhere

import 'package:pdfx/pdfx.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 👈 Ensure this import is added

class InvoiceDetailViewer extends StatefulWidget {
  final AttachmentModel attachment;
  final String? transactionId;

  const InvoiceDetailViewer({
    super.key,
    required this.attachment,
    this.transactionId,
  });

  @override
  State<InvoiceDetailViewer> createState() => _InvoiceDetailViewerState();
}

class _InvoiceDetailViewerState extends State<InvoiceDetailViewer> {
  bool _isDownloading = false;
  bool _isOriginalDownloaded = false;
  bool _isBackHovered = false; // 👈 Add this line
  bool _isDownloadHovered = false; // 👈 Add this line
  bool _isViewTxHovered = false; // 👈 Add this line
  File? _originalFile;
  PdfController? _pdfController;
  final AttachmentService _attachmentService = AttachmentService();

  @override
  void initState() {
    super.initState();
    _checkOriginalAvailability();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  void _checkOriginalAvailability() {
    final path = widget.attachment.localPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        final isPdf = widget.attachment.fileName.toLowerCase().endsWith('.pdf');

        setState(() {
          _isOriginalDownloaded = true;
          _originalFile = file;

          // Only instantiate if not already created
          if (isPdf && _pdfController == null) {
            _pdfController = PdfController(
              document: PdfDocument.openFile(file.path),
            );
          }
        });
        return;
      }
    }

    setState(() {
      _isOriginalDownloaded = false;
      _originalFile = null;
      _pdfController?.dispose();
      _pdfController = null;
    });
  }

  Future<void> _handleDownload() async {
    setState(() => _isDownloading = true);

    try {
      final savedPath = await _attachmentService.downloadAttachmentFile(
        widget.attachment,
      );

      if (!mounted) return;

      if (savedPath != null && File(savedPath).existsSync()) {
        final isPdf = widget.attachment.fileName.toLowerCase().endsWith('.pdf');

        setState(() {
          _isOriginalDownloaded = true;
          _originalFile = File(savedPath);
          if (isPdf && _pdfController == null) {
            _pdfController = PdfController(
              document: PdfDocument.openFile(savedPath),
            );
          }
        });
      } else {
        _checkOriginalAvailability();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${widget.attachment.fileName} downloaded successfully",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _navigateToTransaction() async {
    final String? transactionId = widget.transactionId;
    if (transactionId == null || transactionId.isEmpty) return;

    try {
      final tx = await DatabaseHelper.instance.getTransactionById(transactionId);
      if (!mounted) return;

      if (tx == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transaction not found"),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(transaction: tx),
        ),
      );

      // Re-check original file status in case transaction/attachment was modified
      if (mounted) {
        _checkOriginalAvailability();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to open transaction: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  
  Widget _buildBody(AppColorScheme colors) {
    final fileNameLower = widget.attachment.fileName.toLowerCase();
    final isPdf = fileNameLower.endsWith('.pdf');

    // 1. Original file is downloaded and present on device storage
    if (_isOriginalDownloaded && _originalFile != null) {
      if (isPdf) {
        if (_pdfController == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        return PdfView(
          controller: _pdfController!,
          scrollDirection: Axis.vertical,
          pageSnapping: false,
          builders: PdfViewBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) =>
                const Center(child: CupertinoActivityIndicator()),
            pageLoaderBuilder: (_) =>
                const Center(child: CupertinoActivityIndicator()),
            errorBuilder: (_, error) => Center(
              child: Text(
                'Failed to load PDF: $error',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          ),
        );
      }

      // Original Image with pan and pinch-to-zoom
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: Image.file(
            _originalFile!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackThumbnail(colors),
          ),
        ),
      );
    }

    // 2. Original file not downloaded: expand the cached thumbnail
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.8,
          maxScale: 3.0,
          child: Center(child: _buildFallbackThumbnail(colors)),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  "Preview",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackThumbnail(AppColorScheme colors) {
    return Center(
      child: AttachmentThumbnailView(
        attachment: widget.attachment,
        size: double.infinity,
        borderRadius: 0,
        fit: BoxFit.contain, // Add this line
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0, // 👈 Disables the scroll-under elevation
        surfaceTintColor:
            Colors.transparent, // 👈 Removes the Material 3 tint overlay
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isBackHovered = true),
              onExit: (_) => setState(() => _isBackHovered = false),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isBackHovered
                        ? colors.cardLight
                        : colors.cardLight.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/components/back.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      colors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          widget.attachment.fileName,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoActivityIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isDownloadHovered = true),
                  onExit: (_) => setState(() => _isDownloadHovered = false),
                  child: GestureDetector(
                    onTap: _isOriginalDownloaded ? null : _handleDownload,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isDownloadHovered
                            ? colors.cardLight
                            : colors.cardLight.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/components/download.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          colors.textPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _buildBody(colors)),
            if (widget.transactionId != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: 14, // 👈 Controls gap above the button
                  bottom: 14, // 👈 Controls gap below the button
                ),
                decoration: BoxDecoration(color: colors.card),
                child: Center(
                  child: SizedBox(
                    height: 38,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _isViewTxHovered = true),
                      onExit: (_) => setState(() => _isViewTxHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: _isViewTxHovered
                              ? colors.heroLight
                              : colors.hero,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            overlayColor: Colors.transparent,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: _navigateToTransaction,
                          icon: const Icon(
                            Icons.receipt_long_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "View Transaction",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
