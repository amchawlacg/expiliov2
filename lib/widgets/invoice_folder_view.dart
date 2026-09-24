import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../constants/app_colors.dart';
import 'attachment_thumbnail_view.dart';

enum FolderLevel { year, month, day, files }

class InvoiceFolderView extends StatefulWidget {
  final List<AttachmentModel> attachments;
  final Function(List<AttachmentModel> folderFiles, int tappedIndex) onFileTap;

  const InvoiceFolderView({
    super.key,
    required this.attachments,
    required this.onFileTap,
  });

  @override
  State<InvoiceFolderView> createState() => _InvoiceFolderViewState();
}

class _InvoiceFolderViewState extends State<InvoiceFolderView> {
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  FolderLevel get _currentLevel {
    if (_selectedYear == null) return FolderLevel.year;
    if (_selectedMonth == null) return FolderLevel.month;
    if (_selectedDay == null) return FolderLevel.day;
    return FolderLevel.files;
  }

  void navigateBack() {
    setState(() {
      if (_selectedDay != null) {
        _selectedDay = null;
      } else if (_selectedMonth != null) {
        _selectedMonth = null;
      } else if (_selectedYear != null) {
        _selectedYear = null;
      }
    });
  }

  List<int> _getAvailableYears() {
    final years = widget.attachments.map((a) => a.createdAt.year).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<int> _getAvailableMonths(int year) {
    final months = widget.attachments
        .where((a) => a.createdAt.year == year)
        .map((a) => a.createdAt.month)
        .toSet()
        .toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  List<int> _getAvailableDays(int year, int month) {
    final days = widget.attachments
        .where((a) => a.createdAt.year == year && a.createdAt.month == month)
        .map((a) => a.createdAt.day)
        .toSet()
        .toList();
    days.sort((a, b) => b.compareTo(a));
    return days;
  }

  List<AttachmentModel> _getCurrentFiles() {
    return widget.attachments.where((a) {
      return a.createdAt.year == _selectedYear &&
          a.createdAt.month == _selectedMonth &&
          a.createdAt.day == _selectedDay;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumbBar(colors),
        const Divider(height: 1, thickness: 1),
        Expanded(child: _buildExplorerBody(colors)),
      ],
    );
  }

  Widget _buildBreadcrumbBar(AppColorScheme colors) {
    final crumbs = <Widget>[
      _crumbItem("All Years", isLast: _selectedYear == null, onTap: () {
        setState(() {
          _selectedYear = null;
          _selectedMonth = null;
          _selectedDay = null;
        });
      }, colors: colors),
    ];

    if (_selectedYear != null) {
      crumbs.add(_crumbDivider(colors));
      crumbs.add(
        _crumbItem("$_selectedYear", isLast: _selectedMonth == null, onTap: () {
          setState(() {
            _selectedMonth = null;
            _selectedDay = null;
          });
        }, colors: colors),
      );
    }

    if (_selectedMonth != null) {
      crumbs.add(_crumbDivider(colors));
      crumbs.add(
        _crumbItem(_monthNames[_selectedMonth! - 1], isLast: _selectedDay == null, onTap: () {
          setState(() {
            _selectedDay = null;
          });
        }, colors: colors),
      );
    }

    if (_selectedDay != null) {
      crumbs.add(_crumbDivider(colors));
      crumbs.add(
        _crumbItem("Day $_selectedDay", isLast: true, onTap: () {}, colors: colors),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: crumbs),
    );
  }

  Widget _crumbItem(String label, {required bool isLast, required VoidCallback onTap, required AppColorScheme colors}) {
    return GestureDetector(
      onTap: isLast ? null : onTap,
      child: Text(
        label,
        style: TextStyle(
          color: isLast ? colors.purple : colors.textSecondary,
          fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _crumbDivider(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.chevron_right_rounded, size: 16, color: colors.textHint),
    );
  }

  Widget _buildExplorerBody(AppColorScheme colors) {
    switch (_currentLevel) {
      case FolderLevel.year:
        final years = _getAvailableYears();
        if (years.isEmpty) return _buildEmpty("No invoices available", colors);
        return _buildFolderGrid(
          items: years.map((y) => _FolderItem(title: "$y", count: widget.attachments.where((a) => a.createdAt.year == y).length)).toList(),
          onSelect: (i) => setState(() => _selectedYear = years[i]),
          colors: colors,
        );

      case FolderLevel.month:
        final months = _getAvailableMonths(_selectedYear!);
        return _buildFolderGrid(
          items: months.map((m) => _FolderItem(title: _monthNames[m - 1], count: widget.attachments.where((a) => a.createdAt.year == _selectedYear && a.createdAt.month == m).length)).toList(),
          onSelect: (i) => setState(() => _selectedMonth = months[i]),
          colors: colors,
        );

      case FolderLevel.day:
        final days = _getAvailableDays(_selectedYear!, _selectedMonth!);
        return _buildFolderGrid(
          items: days.map((d) => _FolderItem(title: "$d ${_monthNames[_selectedMonth! - 1].substring(0, 3)}", count: widget.attachments.where((a) => a.createdAt.year == _selectedYear && a.createdAt.month == _selectedMonth && a.createdAt.day == d).length)).toList(),
          onSelect: (i) => setState(() => _selectedDay = days[i]),
          colors: colors,
        );

      case FolderLevel.files:
        final files = _getCurrentFiles();
        if (files.isEmpty) return _buildEmpty("No files here", colors);
        return _buildFileGrid(files, colors);
    }
  }

  Widget _buildFolderGrid({
    required List<_FolderItem> items,
    required Function(int) onSelect,
    required AppColorScheme colors,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelect(index),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.cardLight.withValues(alpha: 0.7)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_rounded, size: 46, color: colors.purple),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text("${item.count} files", style: TextStyle(color: colors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileGrid(List<AttachmentModel> files, AppColorScheme colors) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        // Child aspect ratio lowered to allow room for card + spacing + external label
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final file = files[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onFileTap(files, index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Exact replica of folder card container & aspect ratio
              AspectRatio(
                aspectRatio: 0.95,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.cardLight.withValues(alpha: 0.7),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: AttachmentThumbnailView(
                      attachment: file,
                      size: double.infinity,
                      borderRadius: 0,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // 2. File name rendered OUTSIDE the card
              // Matches the font size (11), color (colors.textSecondary), and alignment of "${item.count} files"
              SizedBox(
                width: double.infinity,
                child: Text(
                  file.fileName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String text, AppColorScheme colors) {
    return Center(
      child: Text(text, style: TextStyle(color: colors.textSecondary)),
    );
  }
}

class _FolderItem {
  final String title;
  final int count;
  _FolderItem({required this.title, required this.count});
}