import 'dart:io';
import 'package:flutter/material.dart';
import '../models/attachment.dart';

class AttachmentThumbnailView extends StatelessWidget {
  final AttachmentModel attachment;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;

  const AttachmentThumbnailView({
    super.key,
    required this.attachment,
    this.size = 36.0,
    this.borderRadius = 8.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    // 1. Try local thumbnail file
    if (attachment.localThumbnailPath != null &&
        attachment.localThumbnailPath!.isNotEmpty &&
        File(attachment.localThumbnailPath!).existsSync()) {
      imageWidget = Image.file(
        File(attachment.localThumbnailPath!),
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }
    // 2. Fallback to local full file
    else if (attachment.localPath != null &&
        attachment.localPath!.isNotEmpty &&
        File(attachment.localPath!).existsSync()) {
      imageWidget = Image.file(
        File(attachment.localPath!),
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }
    // 3. Fallback to cloud thumbnail URL
    else if (attachment.cloudThumbnailUrl != null &&
        attachment.cloudThumbnailUrl!.isNotEmpty) {
      imageWidget = Image.network(
        attachment.cloudThumbnailUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey.withAlpha(50),
            child: const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }
    // 4. Fallback to cloud full URL
    else if (attachment.cloudUrl != null &&
        attachment.cloudUrl!.isNotEmpty) {
      imageWidget = Image.network(
        attachment.cloudUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    // 5. Fallback Placeholder
    else {
      imageWidget = _buildPlaceholder();
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: size,
          height: size,
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.withAlpha(40),
      child: const Icon(
        Icons.receipt_long,
        color: Colors.grey,
        size: 18,
      ),
    );
  }
}