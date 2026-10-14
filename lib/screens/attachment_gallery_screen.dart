import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/attachment.dart';
import '../constants/app_colors.dart';
import '../widgets/attachment_thumbnail_view.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/invoice_detail_viewer.dart'; // Adjust path if needed

class AttachmentGalleryScreen extends StatefulWidget {
  final List<AttachmentModel> attachments;
  final int initialIndex;
  final Future<AttachmentModel?> Function() onAddMore;
  final Function(int index) onDelete;
  final Future<void> Function(AttachmentModel attachment)? onDownloadOriginal;

  const AttachmentGalleryScreen({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
    required this.onAddMore,
    required this.onDelete,
    this.onDownloadOriginal,
  });

  @override
  State<AttachmentGalleryScreen> createState() =>
      _AttachmentGalleryScreenState();
}

class _AttachmentGalleryScreenState extends State<AttachmentGalleryScreen> {
  late PageController _pageController;
  late ScrollController _thumbScrollController;
  late int _currentIndex;

  bool _isPicking = false;
  bool _isDownloading = false;
  bool _isBackHovered = false;
  bool _isDeleteHovered = false;
  bool _isDownloadHovered = false;
  bool _isAddMoreHovered = false;
  bool _isLeftArrowHovered = false;
  bool _isRightArrowHovered = false;
  bool _isViewAttachmentHovered = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _thumbScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbScrollController.dispose();
    super.dispose();
  }

  bool _isOriginalDownloaded(AttachmentModel attachment) {
    return attachment.localPath != null &&
        attachment.localPath!.isNotEmpty &&
        File(attachment.localPath!).existsSync();
  }

  bool _checkIsPdf(AttachmentModel attachment) {
    final name = attachment.fileName.toLowerCase();
    final type = attachment.fileType?.toLowerCase() ?? '';
    return name.endsWith('.pdf') || type == 'application/pdf';
  }

  void _scrollToIndex(int index) {
    if (index == _currentIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _scrollToIndex(_currentIndex - 1);
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.attachments.length - 1) {
      _scrollToIndex(_currentIndex + 1);
    }
  }

  Future<void> _handleDownload() async {
    if (_isDownloading ||
        widget.onDownloadOriginal == null ||
        widget.attachments.isEmpty) {
      return;
    }
    final current = widget.attachments[_currentIndex];

    setState(() => _isDownloading = true);
    try {
      await widget.onDownloadOriginal!(current);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleAddMore() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final newModel = await widget.onAddMore();
      if (newModel != null && mounted) {
        setState(() {
          _currentIndex = widget.attachments.length - 1;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentIndex);
          }
          if (_thumbScrollController.hasClients) {
            _thumbScrollController.animateTo(
              _thumbScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Widget _buildPreview(AttachmentModel attachment, AppColorScheme colors) {
    final bool isPdf = _checkIsPdf(attachment);
    final bool hasLocalOriginal = _isOriginalDownloaded(attachment);

    // 1. High-Res Image File Available Locally
    if (!isPdf && hasLocalOriginal) {
      return Image.file(File(attachment.localPath!), fit: BoxFit.contain);
    }

    // 2. High-Res Image File in Cloud
    if (!isPdf && attachment.cloudUrl != null && attachment.cloudUrl!.isNotEmpty) {
      return Image.network(
        attachment.cloudUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(child: CircularProgressIndicator(color: colors.hero));
        },
        errorBuilder: (_, __, ___) => _buildThumbnailFallback(attachment, colors),
      );
    }

    // 3. PDF Handling (Local page 1 or Cloud Thumbnail)
    if (isPdf) {
      if (attachment.localThumbnailPath != null &&
          attachment.localThumbnailPath!.isNotEmpty &&
          File(attachment.localThumbnailPath!).existsSync()) {
        return Image.file(File(attachment.localThumbnailPath!), fit: BoxFit.contain);
      }
      if (attachment.cloudThumbnailUrl != null &&
          attachment.cloudThumbnailUrl!.isNotEmpty) {
        return Image.network(
          attachment.cloudThumbnailUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(child: CircularProgressIndicator(color: colors.hero));
          },
          errorBuilder: (_, __, ___) => _buildPdfFallbackCard(attachment, colors),
        );
      }
      return _buildPdfFallbackCard(attachment, colors);
    }

    // 4. Default: Render available thumbnail as preview
    return _buildThumbnailFallback(attachment, colors);
  }

  Widget _buildThumbnailFallback(AttachmentModel attachment, AppColorScheme colors) {
    if (attachment.localThumbnailPath != null &&
        attachment.localThumbnailPath!.isNotEmpty &&
        File(attachment.localThumbnailPath!).existsSync()) {
      return Image.file(File(attachment.localThumbnailPath!), fit: BoxFit.contain);
    }
    if (attachment.cloudThumbnailUrl != null &&
        attachment.cloudThumbnailUrl!.isNotEmpty) {
      return Image.network(
        attachment.cloudThumbnailUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(child: CircularProgressIndicator(color: colors.hero));
        },
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.broken_image_rounded, color: colors.textHint, size: 60),
        ),
      );
    }
    return Center(
      child: Icon(Icons.broken_image_rounded, color: colors.textHint, size: 60),
    );
  }

  Widget _buildPdfFallbackCard(AttachmentModel attachment, AppColorScheme colors) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.cardLight.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              attachment.fileName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              "PDF Document",
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasMultiple = widget.attachments.length > 1;
    final currentAttachment = widget.attachments.isNotEmpty &&
            _currentIndex < widget.attachments.length
        ? widget.attachments[_currentIndex]
        : null;
    final bool isDownloaded =
        currentAttachment != null && _isOriginalDownloaded(currentAttachment);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPrevious,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNext,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _isBackHovered = true),
                        onExit: (_) => setState(() => _isBackHovered = false),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.pop(context),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
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

                      // Index Indicator
                      Text(
                        widget.attachments.isEmpty
                            ? "Attachments"
                            : "${_currentIndex + 1} / ${widget.attachments.length}",
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Actions: Download & Delete
                      if (widget.attachments.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isDownloaded &&
                                widget.onDownloadOriginal != null) ...[
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => setState(
                                    () => _isDownloadHovered = true),
                                onExit: (_) => setState(
                                    () => _isDownloadHovered = false),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _handleDownload,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _isDownloadHovered
                                          ? colors.heroLight
                                          : colors.heroLight
                                              .withValues(alpha: 0),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: _isDownloading
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colors.hero,
                                            ),
                                          )
                                        : Icon(
                                            Icons.download_rounded,
                                            color: colors.hero,
                                            size: 20,
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setState(() => _isDeleteHovered = true),
                              onExit: (_) =>
                                  setState(() => _isDeleteHovered = false),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  final shouldDelete =
                                      await AppAlertDialog.show(
                                    context,
                                    title: "Delete Attachment?",
                                    message:
                                        "Are you sure you want to delete this file?",
                                    confirmText: "Delete",
                                    cancelText: "Cancel",
                                    isDestructive: true,
                                  );

                                  if (shouldDelete != true || !mounted) return;

                                  final deleteIdx = _currentIndex;
                                  widget.onDelete(deleteIdx);
                                  if (widget.attachments.length <= 1) {
                                    Navigator.pop(context);
                                  } else {
                                    setState(() {
                                      if (_currentIndex >=
                                          widget.attachments.length - 1) {
                                        _currentIndex =
                                            widget.attachments.length - 2;
                                      }
                                    });
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _isDeleteHovered
                                        ? colors.redLight
                                        : colors.redLight.withValues(alpha: 0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/components/trash.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: ColorFilter.mode(
                                      colors.red,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(width: 36, height: 36),
                    ],
                  ),
                ),

                // Main Content View Area (Tappable when saved)
                Expanded(
                  child: widget.attachments.isEmpty
                      ? Center(
                          child: Text(
                            "No attachments",
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        )
                      : Stack(
                          children: [
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
                                final bool isSaved = item.id != null;

                                return MouseRegion(
                                  cursor: isSaved
                                      ? SystemMouseCursors.click
                                      : SystemMouseCursors.basic,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: isSaved
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    InvoiceDetailViewer(
                                                  attachment: item,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    child: Center(
                                      child: _buildPreview(item, colors),
                                    ),
                                  ),
                                );
                              },
                            ),

                            if (hasMultiple && _currentIndex > 0)
                              Positioned(
                                left: 16,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(
                                      () => _isLeftArrowHovered = true,
                                    ),
                                    onExit: (_) => setState(
                                      () => _isLeftArrowHovered = false,
                                    ),
                                    child: GestureDetector(
                                      onTap: _goToPrevious,
                                      child: TweenAnimationBuilder<Color?>(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeInOut,
                                        tween: ColorTween(
                                          end: _isLeftArrowHovered
                                              ? colors.hover
                                              : colors.idle,
                                        ),
                                        builder: (context, color, child) {
                                          return SvgPicture.asset(
                                            'assets/icons/components/arrow_left.svg',
                                            width: 36,
                                            height: 36,
                                            colorFilter: ColorFilter.mode(
                                              color ?? colors.idle,
                                              BlendMode.srcIn,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            if (hasMultiple &&
                                _currentIndex < widget.attachments.length - 1)
                              Positioned(
                                right: 16,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(
                                      () => _isRightArrowHovered = true,
                                    ),
                                    onExit: (_) => setState(
                                      () => _isRightArrowHovered = false,
                                    ),
                                    child: GestureDetector(
                                      onTap: _goToNext,
                                      child: TweenAnimationBuilder<Color?>(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeInOut,
                                        tween: ColorTween(
                                          end: _isRightArrowHovered
                                              ? colors.hover
                                              : colors.idle,
                                        ),
                                        builder: (context, color, child) {
                                          return SvgPicture.asset(
                                            'assets/icons/components/arrow_right.svg',
                                            width: 36,
                                            height: 36,
                                            colorFilter: ColorFilter.mode(
                                              color ?? colors.idle,
                                              BlendMode.srcIn,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),

                // Bottom Thumbnails Strip with Empty (+) Slot at the End
                Container(
                  height: 64,
                  margin: const EdgeInsets.only(top: 8, bottom: 20),
                  child: Center(
                    child: ListView.separated(
                      controller: _thumbScrollController,
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // Attachment thumbnails count + 1 slot for Add More
                      itemCount: widget.attachments.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        // Empty (+) Card as the last item in the thumbnail row
                        if (index == widget.attachments.length) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _isAddMoreHovered = true),
                            onExit: (_) =>
                                setState(() => _isAddMoreHovered = false),
                            child: GestureDetector(
                              onTap: _isPicking ? null : _handleAddMore,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _isAddMoreHovered
                                      ? colors.cardLight
                                      : colors.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    /*color: _isAddMoreHovered aman
                                        ? colors.purple
                                        : colors.cardLight.withValues(
                                            alpha: 0.8,
                                          ),*/
                                    color: _isAddMoreHovered
                                        ? colors.hero
                                        : colors.heroShadow,
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: _isPicking
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colors.hero,
                                          ),
                                        )
                                      : Icon(
                                          Icons.add_rounded,
                                          color: _isAddMoreHovered
                                              ? colors.hero
                                              : colors.textSecondary,
                                          size: 24,
                                        ),
                                ),
                              ),
                            ),
                          );
                        }

                        // Regular Attachment Thumbnail
                        final item = widget.attachments[index];
                        final isSelected = index == _currentIndex;

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _scrollToIndex(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  /*color: isSelected aman
                                      ? colors.purple
                                      : colors.cardLight.withValues(
                                          alpha: 0.7,
                                        ),*/
                                  color: isSelected
                                      ? colors.hero
                                      : colors.cardLight,
                                  width: isSelected ? 2.2 : 1.0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    AttachmentThumbnailView(
                                      attachment: item,
                                      size: 52,
                                      borderRadius: 8,
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 3,
                                        right: 3,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: colors.hero,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}