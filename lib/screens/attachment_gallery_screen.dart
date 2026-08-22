import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/attachment.dart';
import '../constants/app_colors.dart';

class AttachmentGalleryScreen extends StatefulWidget {
  final List<AttachmentModel> attachments;
  final int initialIndex;
  final VoidCallback onAddMore;
  final Function(int index) onDelete;

  const AttachmentGalleryScreen({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
    required this.onAddMore,
    required this.onDelete,
  });

  @override
  State<AttachmentGalleryScreen> createState() => _AttachmentGalleryScreenState();
}

class _AttachmentGalleryScreenState extends State<AttachmentGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.attachments.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildFullImage(AttachmentModel attachment, AppColorScheme colors) {
    if (attachment.localPath != null &&
        attachment.localPath!.isNotEmpty &&
        File(attachment.localPath!).existsSync()) {
      return Image.file(
        File(attachment.localPath!),
        fit: BoxFit.contain,
      );
    } else if (attachment.cloudUrl != null &&
        attachment.cloudUrl!.isNotEmpty) {
      return Image.network(
        attachment.cloudUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        },
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.broken_image, color: colors.textHint, size: 60),
        ),
      );
    } else {
      return Center(
        child: Icon(Icons.broken_image, color: colors.textHint, size: 60),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasMultiple = widget.attachments.length > 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPrevious,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNext,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.attachments.isEmpty
                  ? "Attachments"
                  : "${_currentIndex + 1} / ${widget.attachments.length}",
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
            ),
            centerTitle: true,
            actions: [
              if (widget.attachments.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.expense),
                  onPressed: () {
                    final deleteIdx = _currentIndex;
                    widget.onDelete(deleteIdx);
                    if (widget.attachments.length <= 1) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        if (_currentIndex >= widget.attachments.length - 1) {
                          _currentIndex = widget.attachments.length - 2;
                        }
                      });
                    }
                  },
                ),
            ],
          ),
          body: widget.attachments.isEmpty
              ? Center(
                  child: Text(
                    "No attachments",
                    style: TextStyle(color: colors.textSecondary),
                  ),
                )
              : Stack(
                  children: [
                    // Main Swipeable Image View
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.attachments.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = widget.attachments[index];
                        return InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Center(
                            child: _buildFullImage(item, colors),
                          ),
                        );
                      },
                    ),

                    // Left Navigation Arrow Button
                    if (hasMultiple && _currentIndex > 0)
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: CircleAvatar(
                            backgroundColor: colors.iconCircle,
                            radius: 24,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
                              onPressed: _goToPrevious,
                            ),
                          ),
                        ),
                      ),

                    // Right Navigation Arrow Button
                    if (hasMultiple && _currentIndex < widget.attachments.length - 1)
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: CircleAvatar(
                            backgroundColor: colors.iconCircle,
                            radius: 24,
                            child: IconButton(
                              icon: Icon(Icons.arrow_forward_ios, color: colors.textPrimary, size: 20),
                              onPressed: _goToNext,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: colors.card,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(Icons.add_photo_alternate, color: colors.textPrimary),
                  label: Text(
                    "Attach Another File",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    widget.onAddMore();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}