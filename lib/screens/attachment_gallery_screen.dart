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

  Widget _buildFullImage(AttachmentModel attachment) {
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
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 60),
        ),
      );
    } else {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 60),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.attachments.length > 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPrevious,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNext,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.attachments.isEmpty
                  ? "Attachments"
                  : "${_currentIndex + 1} / ${widget.attachments.length}",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            centerTitle: true,
            actions: [
              if (widget.attachments.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
              ? const Center(
                  child: Text(
                    "No attachments",
                    style: TextStyle(color: Colors.white54),
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
                            child: _buildFullImage(item),
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
                            backgroundColor: Colors.black54,
                            radius: 24,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
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
                            backgroundColor: Colors.black54,
                            radius: 24,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
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
              color: Colors.black.withAlpha(200),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
                  label: const Text(
                    "Attach Another File",
                    style: TextStyle(
                      color: Colors.white,
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