import 'dart:io';
import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../constants/app_colors.dart';
import '../services/attachment_service.dart';

class AttachmentThumbnailView extends StatefulWidget {
  final AttachmentModel attachment;
  final double size;
  final double borderRadius;
  final BoxFit fit;
  final VoidCallback? onTap;

  const AttachmentThumbnailView({
    super.key,
    required this.attachment,
    this.size = 36.0,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  State<AttachmentThumbnailView> createState() => _AttachmentThumbnailViewState();
}

class _AttachmentThumbnailViewState extends State<AttachmentThumbnailView> {
  final AttachmentService _attachmentService = AttachmentService();
  String? _resolvedThumbnailPath;
  bool _isDownloading = false;

  bool get _isPdf {
    final fileName = widget.attachment.fileName.toLowerCase();
    final fileType = widget.attachment.fileType?.toLowerCase() ?? '';
    return fileName.endsWith('.pdf') || fileType == 'application/pdf';
  }

  @override
  void initState() {
    super.initState();
    _resolveThumbnail();
  }

  @override
  void didUpdateWidget(covariant AttachmentThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.attachment.localThumbnailPath != widget.attachment.localThumbnailPath ||
        oldWidget.attachment.cloudThumbnailUrl != widget.attachment.cloudThumbnailUrl ||
        oldWidget.attachment.localPath != widget.attachment.localPath) {
      _resolveThumbnail();
    }
  }

  void _resolveThumbnail() {
    // 1. Check if local thumbnail already exists on disk
    final localThumb = widget.attachment.localThumbnailPath;
    if (localThumb != null && localThumb.isNotEmpty && File(localThumb).existsSync()) {
      _resolvedThumbnailPath = localThumb;
      return;
    }

    // 2. Check if local original file exists (for non-PDF images only)
    if (!_isPdf) {
      final localOriginal = widget.attachment.localPath;
      if (localOriginal != null && localOriginal.isNotEmpty && File(localOriginal).existsSync()) {
        _resolvedThumbnailPath = localOriginal;
        return;
      }
    }

    // 3. Neither exists locally; fetch thumbnail from cloud and cache it
    _triggerThumbnailDownload();
  }

  Future<void> _triggerThumbnailDownload() async {
    final hasRemoteUrl = (widget.attachment.cloudThumbnailUrl != null &&
            widget.attachment.cloudThumbnailUrl!.isNotEmpty) ||
        (widget.attachment.cloudUrl != null &&
            widget.attachment.cloudUrl!.isNotEmpty);

    if (!hasRemoteUrl || _isDownloading) return;

    _isDownloading = true;

    try {
      final path = await _attachmentService.downloadThumbnailFile(widget.attachment);
      if (mounted && path != null && File(path).existsSync()) {
        setState(() {
          _resolvedThumbnailPath = path;
          _isDownloading = false;
        });
      } else if (mounted) {
        setState(() => _isDownloading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget content;

    // Display cached image if available
    if (_resolvedThumbnailPath != null && File(_resolvedThumbnailPath!).existsSync()) {
      content = Image.file(
        File(_resolvedThumbnailPath!),
        fit: widget.fit,
        width: widget.size,
        height: widget.size,
        errorBuilder: (_, __, ___) => _buildPdfOrPlaceholder(colors),
      );
    } else {
      // While downloading or if unavailable, display the placeholder/PDF badge
      content = _buildPdfOrPlaceholder(colors);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: content,
        ),
      ),
    );
  }

  Widget _buildPdfOrPlaceholder(AppColorScheme colors) {
    if (_isPdf) {
      return Container(
        width: widget.size,
        height: widget.size,
        color: colors.cardLight.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                color: colors.red,
                size: (widget.size * 0.45).clamp(16.0, 72.0),
              ),
              if (widget.size >= 36) ...[
                const SizedBox(height: 2),
                Text(
                  "PDF",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: (widget.size * 0.2).clamp(8.0, 16.0),
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return _buildPlaceholder(colors);
  }

  Widget _buildPlaceholder(AppColorScheme colors) {
    return Container(
      width: widget.size,
      height: widget.size,
      color: colors.cardLight.withValues(alpha: 0.4),
      child: Icon(
        Icons.receipt_long,
        color: colors.textSecondary,
        size: (widget.size * 0.5).clamp(16.0, 64.0),
      ),
    );
  }
}