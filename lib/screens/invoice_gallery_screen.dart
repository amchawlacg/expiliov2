import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../models/attachment.dart';
import '../services/attachment_service.dart';
import '../widgets/attachment_thumbnail_view.dart';
import 'attachment_gallery_screen.dart';
import '../widgets/invoice_detail_viewer.dart';

enum InvoiceGroupBy {
  date('Date'),
  category('Category'),
  payment('Payment Method'),
  profile('Profile');

  final String label;
  const InvoiceGroupBy(this.label);
}

class InvoiceItemRecord {
  final AttachmentModel attachment;
  final String? transactionId; // 1. Added field
  final String? category;
  final String? paymentMethod;
  final String? profileType;
  final DateTime date;

  const InvoiceItemRecord({
    required this.attachment,
    this.transactionId, // 2. Added to constructor
    this.category,
    this.paymentMethod,
    this.profileType,
    required this.date,
  });
}

class InvoiceGalleryScreen extends StatefulWidget {
  const InvoiceGalleryScreen({super.key});

  @override
  State<InvoiceGalleryScreen> createState() => _InvoiceGalleryScreenState();
}

class _InvoiceGalleryScreenState extends State<InvoiceGalleryScreen> {
  final AttachmentService _attachmentService = AttachmentService();

  bool _isLoading = true;
  bool _isBackHovered = false; // 👈 Add this line
  bool _isGroupDropdownHovered = false;
  bool _isFilterHovered = false;

  // Grouping state
  InvoiceGroupBy selectedGroupBy = InvoiceGroupBy.date;
  String dateGranularity = "Month"; // "Month" or "Year"

  // Date Drill-down Navigation State
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;

  // Non-date Drill-down Navigation State (Category, Payment, Profile)
  String? _selectedSubfolder;

  // Filter state
  String selectedProfileFilter = "All"; // "All", "Personal", "Business"
  List<String> selectedCategories = ["All"];
  List<String> selectedPaymentFilters = ["All"];

  List<InvoiceItemRecord> _allInvoices = [];

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    // Silently re-queries SQLite whenever a new attachment is added/deleted
    AttachmentService.onAttachmentsChanged.addListener(
      _refreshInvoicesSilently,
    );
  }

  @override
  void dispose() {
    AttachmentService.onAttachmentsChanged.removeListener(
      _refreshInvoicesSilently,
    );
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      final rawRecords = await _attachmentService
          .getInvoicesWithTransactionMetadata();
      if (!mounted) return;

      final parsed = rawRecords.map((row) {
        final attachment = AttachmentModel.fromMap(row);
        final rawDate = row['date'] as String?;
        final date = rawDate != null
            ? (DateTime.tryParse(rawDate) ?? attachment.createdAt)
            : attachment.createdAt;

        return InvoiceItemRecord(
          attachment: attachment,
          // 3. Extract the transaction ID (adjust the key name if your SQL query uses something else)
          transactionId:
              row['transaction_id']?.toString() ?? row['id']?.toString(),
          category: row['category'] as String?,
          paymentMethod: row['payment_method'] as String?,
          profileType: row['profile_type'] as String?,
          date: date,
        );
      }).toList();

      setState(() {
        _allInvoices = parsed;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshInvoicesSilently() async {
    try {
      final rawRecords = await _attachmentService
          .getInvoicesWithTransactionMetadata();
      if (!mounted) return;

      final parsed = rawRecords.map((row) {
        final attachment = AttachmentModel.fromMap(row);
        final rawDate = row['date'] as String?;
        final date = rawDate != null
            ? (DateTime.tryParse(rawDate) ?? attachment.createdAt)
            : attachment.createdAt;

        return InvoiceItemRecord(
          attachment: attachment,
          transactionId:
              row['transaction_id']?.toString() ?? row['id']?.toString(),
          category: row['category'] as String?,
          paymentMethod: row['payment_method'] as String?,
          profileType: row['profile_type'] as String?,
          date: date,
        );
      }).toList();

      setState(() {
        _allInvoices = parsed;
      });
    } catch (_) {
      // Keep existing items if silent refresh fails
    }
  }

  void _resetHierarchy() {
    setState(() {
      _selectedYear = null;
      _selectedMonth = null;
      _selectedDay = null;
      _selectedSubfolder = null;
    });
  }

  bool get _canNavigateBackInHierarchy {
    if (selectedGroupBy == InvoiceGroupBy.date) {
      return _selectedYear != null;
    }
    return _selectedSubfolder != null;
  }

  void _navigateBackHierarchy() {
    setState(() {
      if (selectedGroupBy == InvoiceGroupBy.date) {
        if (_selectedDay != null) {
          _selectedDay = null;
        } else if (_selectedMonth != null) {
          _selectedMonth = null;
        } else if (_selectedYear != null) {
          _selectedYear = null;
        }
      } else {
        _selectedSubfolder = null;
      }
    });
  }

  bool get _hasActiveFilters {
    return selectedProfileFilter != "All" ||
        (!selectedPaymentFilters.contains("All") &&
            selectedPaymentFilters.isNotEmpty) ||
        (!selectedCategories.contains("All") &&
            selectedCategories.isNotEmpty) ||
        dateGranularity != "Month";
  }

  List<InvoiceItemRecord> get _filteredInvoices {
    var list = List<InvoiceItemRecord>.from(_allInvoices);

    // Profile Filter
    if (selectedProfileFilter != "All") {
      list = list.where((item) {
        final p = item.profileType?.trim().toLowerCase() ?? 'personal';
        return p == selectedProfileFilter.toLowerCase();
      }).toList();
    }

    // Payment Multi-Select Filter
    if (!selectedPaymentFilters.contains("All") &&
        selectedPaymentFilters.isNotEmpty) {
      list = list.where((item) {
        final pm = item.paymentMethod?.trim() ?? 'Cash';
        return selectedPaymentFilters.any(
          (selected) => selected.toLowerCase() == pm.toLowerCase(),
        );
      }).toList();
    }

    // Categories Multi-Select Filter
    if (!selectedCategories.contains("All") && selectedCategories.isNotEmpty) {
      list = list.where((item) {
        final cat = item.category?.trim();
        if (cat == null) return false;
        return selectedCategories.any(
          (selected) => selected.toLowerCase() == cat.toLowerCase(),
        );
      }).toList();
    }

    return list;
  }

  void _openViewer({
    required List<InvoiceItemRecord> currentGroupList,
    required int initialIndex,
  }) {
    final attachmentsList = currentGroupList.map((e) => e.attachment).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttachmentGalleryScreen(
          attachments: attachmentsList,
          initialIndex: initialIndex,
          onAddMore: () async {
            await _loadInvoices();
            return null;
          },
          onDelete: (index) {
            final removedId = attachmentsList[index].id;
            setState(() {
              _allInvoices.removeWhere(
                (item) => item.attachment.id == removedId,
              );
            });
          },
        ),
      ),
    );
  }

  void _openFilterSheet() async {
    final colors = context.colors;
    final profileOptions = ["All", "Personal", "Business"];
    final paymentOptions = [
      "All",
      "Cash",
      "Credit Card",
      "Debit Card",
      "UPI",
      "Bank",
    ];

    final Set<String> distinctCategories = {};
    for (var item in _allInvoices) {
      if (item.category != null && item.category!.trim().isNotEmpty) {
        distinctCategories.add(item.category!.trim());
      }
    }
    final sortedCategories = distinctCategories.toList()..sort();

    String tempProfile = selectedProfileFilter;
    String tempGranularity = dateGranularity;
    List<String> tempCategories = List<String>.from(selectedCategories);
    List<String> tempPayments = List<String>.from(selectedPaymentFilters);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (ctx) {
        bool isResetHovered = false;
        bool isApplyHovered = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAllCategories = tempCategories.contains("All");

            String categoryText;
            if (isAllCategories || tempCategories.isEmpty) {
              categoryText = "All Categories";
            } else if (tempCategories.length == 1) {
              categoryText = tempCategories.first;
            } else {
              categoryText = "${tempCategories.length} selected";
            }

            final isAllPayments = tempPayments.contains("All");
            String paymentText;
            if (isAllPayments || tempPayments.isEmpty) {
              paymentText = "All Payment Methods";
            } else if (tempPayments.length == 1) {
              paymentText = tempPayments.first;
            } else {
              paymentText = "${tempPayments.length} selected";
            }

            Widget buildDropdownTile({
              required String label,
              required String value,
              required List<String> options,
              required ValueChanged<String> onSelected,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (tileCtx) {
                      return GestureDetector(
                        onTap: () async {
                          final renderBox =
                              tileCtx.findRenderObject() as RenderBox;
                          final overlay =
                              Navigator.of(
                                    context,
                                  ).overlay!.context.findRenderObject()
                                  as RenderBox;

                          final target = Rect.fromPoints(
                            renderBox.localToGlobal(
                              Offset.zero,
                              ancestor: overlay,
                            ),
                            renderBox.localToGlobal(
                              renderBox.size.bottomRight(Offset.zero),
                              ancestor: overlay,
                            ),
                          );

                          final chosen = await showMenu<String>(
                            context: context,
                            color: colors.card,
                            elevation: 6,
                            constraints: BoxConstraints(
                              minWidth: renderBox.size.width,
                              maxWidth: renderBox.size.width,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            position: RelativeRect.fromRect(
                              target,
                              Offset.zero & overlay.size,
                            ),
                            items: options.map((opt) {
                              final isSelected = opt == value;
                              return PopupMenuItem<String>(
                                value: opt,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      opt,
                                      style: TextStyle(
                                        color: isSelected
                                            ? colors.purple
                                            : colors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check,
                                        color: colors.purple,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );

                          if (chosen != null) onSelected(chosen);
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: colors.cardLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                value,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "Filter Invoices",
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date Granularity (if grouping by Date)
                        if (selectedGroupBy == InvoiceGroupBy.date) ...[
                          buildDropdownTile(
                            label: "DATE GROUPING",
                            value: tempGranularity,
                            options: ["Month", "Year"],
                            onSelected: (val) =>
                                setModalState(() => tempGranularity = val),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Payment Profile
                        buildDropdownTile(
                          label: "PAYMENT PROFILE",
                          value: tempProfile,
                          options: profileOptions,
                          onSelected: (val) =>
                              setModalState(() => tempProfile = val),
                        ),
                        const SizedBox(height: 16),

                        // Payment Method Multi-Select Dropdown
                        Text(
                          "PAYMENT METHOD",
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (payCtx) {
                            return GestureDetector(
                              onTap: () async {
                                final renderBox =
                                    payCtx.findRenderObject() as RenderBox;
                                final overlay =
                                    Navigator.of(
                                          context,
                                        ).overlay!.context.findRenderObject()
                                        as RenderBox;

                                final position = RelativeRect.fromRect(
                                  Rect.fromPoints(
                                    renderBox.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay,
                                    ),
                                    renderBox.localToGlobal(
                                      renderBox.size.bottomRight(Offset.zero),
                                      ancestor: overlay,
                                    ),
                                  ),
                                  Offset.zero & overlay.size,
                                );

                                await showMenu<void>(
                                  context: context,
                                  color: colors.card,
                                  elevation: 6,
                                  constraints: BoxConstraints(
                                    minWidth: renderBox.size.width,
                                    maxWidth: renderBox.size.width,
                                    maxHeight: 280,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  position: position,
                                  items: [
                                    PopupMenuItem<void>(
                                      enabled: false,
                                      padding: EdgeInsets.zero,
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          disabledColor: colors.textPrimary,
                                        ),
                                        child: StatefulBuilder(
                                          builder: (pCtx, pSetState) {
                                            final isAllActive = tempPayments
                                                .contains("All");

                                            return SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      setModalState(() {
                                                        tempPayments.clear();
                                                        tempPayments.add("All");
                                                      });
                                                      pSetState(() {});
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            "All",
                                                            style: TextStyle(
                                                              color: isAllActive
                                                                  ? colors
                                                                        .purple
                                                                  : colors
                                                                        .textPrimary,
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  isAllActive
                                                                  ? FontWeight
                                                                        .bold
                                                                  : FontWeight
                                                                        .normal,
                                                            ),
                                                          ),
                                                          if (isAllActive)
                                                            Icon(
                                                              Icons.check,
                                                              color:
                                                                  colors.purple,
                                                              size: 18,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const Divider(
                                                    height: 1,
                                                    thickness: 0.5,
                                                  ),
                                                  ...paymentOptions.where((opt) => opt != "All").map((
                                                    opt,
                                                  ) {
                                                    final isSelected =
                                                        tempPayments.contains(
                                                          opt,
                                                        );
                                                    return InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          tempPayments.remove(
                                                            "All",
                                                          );
                                                          if (isSelected) {
                                                            tempPayments.remove(
                                                              opt,
                                                            );
                                                            if (tempPayments
                                                                .isEmpty) {
                                                              tempPayments.add(
                                                                "All",
                                                              );
                                                            }
                                                          } else {
                                                            tempPayments.add(
                                                              opt,
                                                            );
                                                          }
                                                        });
                                                        pSetState(() {});
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 12,
                                                            ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              opt,
                                                              style: TextStyle(
                                                                color:
                                                                    isSelected
                                                                    ? colors
                                                                          .purple
                                                                    : colors
                                                                          .textPrimary,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    isSelected
                                                                    ? FontWeight
                                                                          .bold
                                                                    : FontWeight
                                                                          .normal,
                                                              ),
                                                            ),
                                                            if (isSelected)
                                                              Icon(
                                                                Icons.check,
                                                                color: colors
                                                                    .purple,
                                                                size: 18,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.cardLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        paymentText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: colors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Categories Multi-select Dropdown
                        Text(
                          "CATEGORIES",
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (catCtx) {
                            return GestureDetector(
                              onTap: () async {
                                final renderBox =
                                    catCtx.findRenderObject() as RenderBox;
                                final overlay =
                                    Navigator.of(
                                          context,
                                        ).overlay!.context.findRenderObject()
                                        as RenderBox;

                                final position = RelativeRect.fromRect(
                                  Rect.fromPoints(
                                    renderBox.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay,
                                    ),
                                    renderBox.localToGlobal(
                                      renderBox.size.bottomRight(Offset.zero),
                                      ancestor: overlay,
                                    ),
                                  ),
                                  Offset.zero & overlay.size,
                                );

                                await showMenu<void>(
                                  context: context,
                                  color: colors.card,
                                  elevation: 6,
                                  constraints: BoxConstraints(
                                    minWidth: renderBox.size.width,
                                    maxWidth: renderBox.size.width,
                                    maxHeight: 280,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  position: position,
                                  items: [
                                    PopupMenuItem<void>(
                                      enabled: false,
                                      padding: EdgeInsets.zero,
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          disabledColor: colors.textPrimary,
                                        ),
                                        child: StatefulBuilder(
                                          builder: (mCtx, menuSetState) {
                                            final isAllActive = tempCategories
                                                .contains("All");

                                            return SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      setModalState(() {
                                                        tempCategories.clear();
                                                        tempCategories.add(
                                                          "All",
                                                        );
                                                      });
                                                      menuSetState(() {});
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            "All",
                                                            style: TextStyle(
                                                              color: isAllActive
                                                                  ? colors
                                                                        .purple
                                                                  : colors
                                                                        .textPrimary,
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  isAllActive
                                                                  ? FontWeight
                                                                        .bold
                                                                  : FontWeight
                                                                        .normal,
                                                            ),
                                                          ),
                                                          if (isAllActive)
                                                            Icon(
                                                              Icons.check,
                                                              color:
                                                                  colors.purple,
                                                              size: 18,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const Divider(
                                                    height: 1,
                                                    thickness: 0.5,
                                                  ),
                                                  ...sortedCategories.map((
                                                    cat,
                                                  ) {
                                                    final isSelected =
                                                        tempCategories.contains(
                                                          cat,
                                                        );
                                                    return InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          tempCategories.remove(
                                                            "All",
                                                          );
                                                          if (isSelected) {
                                                            tempCategories
                                                                .remove(cat);
                                                            if (tempCategories
                                                                .isEmpty) {
                                                              tempCategories
                                                                  .add("All");
                                                            }
                                                          } else {
                                                            tempCategories.add(
                                                              cat,
                                                            );
                                                          }
                                                        });
                                                        menuSetState(() {});
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 12,
                                                            ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                cat,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  color:
                                                                      isSelected
                                                                      ? colors
                                                                            .purple
                                                                      : colors
                                                                            .textPrimary,
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      isSelected
                                                                      ? FontWeight
                                                                            .bold
                                                                      : FontWeight
                                                                            .normal,
                                                                ),
                                                              ),
                                                            ),
                                                            if (isSelected)
                                                              Icon(
                                                                Icons.check,
                                                                color: colors
                                                                    .purple,
                                                                size: 18,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.cardLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        categoryText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: colors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons: Reset & Apply
                        Row(
                          children: [
                            // Reset Button
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) =>
                                    setModalState(() => isResetHovered = true),
                                onExit: (_) =>
                                    setModalState(() => isResetHovered = false),
                                child: AnimatedContainer(
                                  height: 38,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: colors.cardLight.withValues(
                                      alpha: isResetHovered ? 0.20 : 0.0,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colors.cardLight.withValues(
                                        alpha: isResetHovered ? 1.0 : 0.8,
                                      ),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      surfaceTintColor: Colors.transparent,
                                      overlayColor: Colors.transparent,
                                      minimumSize: Size.zero,
                                      side: BorderSide.none,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        tempProfile = "All";
                                        tempGranularity = "Month";
                                        tempCategories = ["All"];
                                        tempPayments = ["All"];
                                      });
                                    },
                                    child: Text(
                                      "Reset",
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Apply Button
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) =>
                                    setModalState(() => isApplyHovered = true),
                                onExit: (_) =>
                                    setModalState(() => isApplyHovered = false),
                                child: AnimatedContainer(
                                  height: 38,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: isApplyHovered
                                        ? colors.purpleLight
                                        : colors.purple,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      surfaceTintColor: Colors.transparent,
                                      overlayColor: Colors.transparent,
                                      minimumSize: Size.zero,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        selectedProfileFilter = tempProfile;
                                        dateGranularity = tempGranularity;
                                        selectedCategories = tempCategories;
                                        selectedPaymentFilters = tempPayments;
                                        _resetHierarchy();
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      "Apply",
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
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Breadcrumb Widget ---
  Widget _buildBreadcrumbBar(AppColorScheme colors) {
    final crumbs = <Widget>[];

    if (selectedGroupBy == InvoiceGroupBy.date) {
      crumbs.add(
        _crumbItem(
          "All Years",
          isLast: _selectedYear == null,
          onTap: () {
            setState(() {
              _selectedYear = null;
              _selectedMonth = null;
              _selectedDay = null;
            });
          },
          colors: colors,
        ),
      );

      if (_selectedYear != null) {
        crumbs.add(_crumbDivider(colors));
        crumbs.add(
          _crumbItem(
            "$_selectedYear",
            isLast: _selectedMonth == null,
            onTap: () {
              setState(() {
                _selectedMonth = null;
                _selectedDay = null;
              });
            },
            colors: colors,
          ),
        );
      }

      if (_selectedMonth != null) {
        crumbs.add(_crumbDivider(colors));
        crumbs.add(
          _crumbItem(
            _monthNames[_selectedMonth! - 1],
            isLast: _selectedDay == null,
            onTap: () {
              setState(() {
                _selectedDay = null;
              });
            },
            colors: colors,
          ),
        );
      }

      if (_selectedDay != null) {
        crumbs.add(_crumbDivider(colors));
        crumbs.add(
          _crumbItem(
            "$_selectedDay ${_monthNames[_selectedMonth! - 1].substring(0, 3)}",
            isLast: true,
            onTap: () {},
            colors: colors,
          ),
        );
      }
    } else {
      crumbs.add(
        _crumbItem(
          "All ${selectedGroupBy.label}s",
          isLast: _selectedSubfolder == null,
          onTap: () {
            setState(() => _selectedSubfolder = null);
          },
          colors: colors,
        ),
      );

      if (_selectedSubfolder != null) {
        crumbs.add(_crumbDivider(colors));
        crumbs.add(
          _crumbItem(
            _selectedSubfolder!,
            isLast: true,
            onTap: () {},
            colors: colors,
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: crumbs),
    );
  }

  Widget _crumbItem(
    String label, {
    required bool isLast,
    required VoidCallback onTap,
    required AppColorScheme colors,
  }) {
    return GestureDetector(
      onTap: isLast ? null : onTap,
      child: Text(
        label,
        style: TextStyle(
          color: isLast ? colors.textPrimary : colors.textSecondary,
          fontWeight: isLast ? FontWeight.w500 : FontWeight.w500,
          fontSize: isLast ? 13 : 10,
        ),
      ),
    );
  }

  Widget _crumbDivider(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 14,
        color: colors.textSecondary,
      ),
    );
  }

  Widget _buildFullWidthDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.colors.cardLight.withValues(alpha: 0.6),
    );
  }

  // --- Folder Grid with Manual Size Control & Auto-Stepping Label Text ---
  Widget _buildFolderGrid({
    required List<_FolderData> items,
    required Function(int) onSelect,
    required AppColorScheme colors,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final folder = items[index];

        return LayoutBuilder(
          builder: (context, constraints) {
            // 🎚️ ADJUST THIS VALUE TO CHANGE FOLDER SIZE MANUALLY:
            const double folderScaleFactor = 0.78;

            final cellWidth = constraints.maxWidth * folderScaleFactor;
            final folderHeight = cellWidth * 0.80;
            final maxStickerWidth = cellWidth * 0.70;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: cellWidth,
                    height: folderHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 1. Scaled folder SVG
                        Positioned.fill(
                          child: SvgPicture.asset(
                            'assets/images/folder.svg',
                            fit: BoxFit.fitWidth,
                          ),
                        ),

                        // 2. Sticker Tag (Stepping font size: 11 -> 10 -> 9 -> ellipsis)
                        Positioned(
                          top: folderHeight * 0.32,
                          child: Transform.rotate(
                            angle: -0.02,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: maxStickerWidth,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.16),
                                    blurRadius: 3.5,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: _AutoStepDownText(
                                text: folder.title,
                                // Subtract 14px for horizontal padding (7px left + 7px right)
                                maxWidth: maxStickerWidth - 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${folder.count} ${folder.count == 1 ? 'file' : 'files'}",
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Uniform Files Grid Builder ---
  // --- Uniform Files Grid Builder ---
  Widget _buildUniformFilesGrid({
    required List<InvoiceItemRecord> files,
    required AppColorScheme colors,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: files.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final record = files[index];
        return LayoutBuilder(
          builder: (context, constraints) {
            const double folderScaleFactor = 0.78;
            final cellWidth = constraints.maxWidth * folderScaleFactor;
            final cardHeight = cellWidth * 0.80;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceDetailViewer(
                      attachment: record.attachment,
                      transactionId: record.transactionId,
                    ),
                  ),
                );
                if (mounted) {
                  _refreshInvoicesSilently();
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. File thumbnail card sized to the exact dimensions of the folder SVG
                  Container(
                    width: cellWidth,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.cardLight.withValues(alpha: 0.6),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AttachmentThumbnailView(
                      attachment: record.attachment,
                      size: double.infinity,
                      borderRadius: 0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 2. Centered file name outside the card matching "${folder.count} files"
                  SizedBox(
                    width: cellWidth,
                    child: Text(
                      record.attachment.fileName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Main Dynamic Body Based on Selected Hierarchy ---
  Widget _buildHierarchyBody(AppColorScheme colors) {
    final activeInvoices = _filteredInvoices;
    if (activeInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/components/invoice.svg',
              width: 44,
              height: 44,
              colorFilter: ColorFilter.mode(colors.textHint, BlendMode.srcIn),
            ),
            const SizedBox(height: 12),
            Text(
              "No invoices match the filter",
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 1. DATE DRILL DOWN
    if (selectedGroupBy == InvoiceGroupBy.date) {
      // Step 1: Year Folders
      if (_selectedYear == null) {
        final years = activeInvoices.map((e) => e.date.year).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        return _buildFolderGrid(
          items: years
              .map(
                (year) => _FolderData(
                  title: "$year",
                  count: activeInvoices
                      .where((e) => e.date.year == year)
                      .length,
                ),
              )
              .toList(),
          onSelect: (idx) => setState(() => _selectedYear = years[idx]),
          colors: colors,
        );
      }

      // Step 2: Month Folders
      if (_selectedMonth == null) {
        final yearInvoices = activeInvoices
            .where((e) => e.date.year == _selectedYear)
            .toList();
        final months = yearInvoices.map((e) => e.date.month).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        return _buildFolderGrid(
          items: months
              .map(
                (month) => _FolderData(
                  title: _monthNames[month - 1],
                  count: yearInvoices
                      .where((e) => e.date.month == month)
                      .length,
                ),
              )
              .toList(),
          onSelect: (idx) => setState(() => _selectedMonth = months[idx]),
          colors: colors,
        );
      }

      // Step 3: Day Folders (or directly files if Year Granularity selected)
      if (dateGranularity != "Year" && _selectedDay == null) {
        final monthInvoices = activeInvoices
            .where(
              (e) =>
                  e.date.year == _selectedYear &&
                  e.date.month == _selectedMonth,
            )
            .toList();
        final days = monthInvoices.map((e) => e.date.day).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        return _buildFolderGrid(
          items: days
              .map(
                (day) => _FolderData(
                  title:
                      "$day ${_monthNames[_selectedMonth! - 1].substring(0, 3)}",
                  count: monthInvoices.where((e) => e.date.day == day).length,
                ),
              )
              .toList(),
          onSelect: (idx) => setState(() => _selectedDay = days[idx]),
          colors: colors,
        );
      }

      // Step 4: Final Files Grid
      final dateFilteredFiles = activeInvoices.where((e) {
        if (dateGranularity == "Year") {
          return e.date.year == _selectedYear && e.date.month == _selectedMonth;
        }
        return e.date.year == _selectedYear &&
            e.date.month == _selectedMonth &&
            e.date.day == _selectedDay;
      }).toList();

      return _buildUniformFilesGrid(files: dateFilteredFiles, colors: colors);
    }

    // 2. CATEGORY / PAYMENT / PROFILE DRILL DOWN
    if (_selectedSubfolder == null) {
      final Map<String, int> folderCounts = {};
      for (final item in activeInvoices) {
        String key;
        switch (selectedGroupBy) {
          case InvoiceGroupBy.category:
            key = (item.category != null && item.category!.trim().isNotEmpty)
                ? item.category!.trim()
                : 'Uncategorized';
            break;
          case InvoiceGroupBy.payment:
            key =
                (item.paymentMethod != null &&
                    item.paymentMethod!.trim().isNotEmpty)
                ? item.paymentMethod!.trim()
                : 'Cash';
            break;
          case InvoiceGroupBy.profile:
            key =
                (item.profileType != null &&
                    item.profileType!.trim().isNotEmpty)
                ? item.profileType!.trim()
                : 'Personal';
            break;
          default:
            key = 'General';
        }
        folderCounts[key] = (folderCounts[key] ?? 0) + 1;
      }

      final folderKeys = folderCounts.keys.toList()..sort();
      return _buildFolderGrid(
        items: folderKeys
            .map(
              (key) => _FolderData(
                title: key,
                count: folderCounts[key] ?? 0,
                icon: selectedGroupBy == InvoiceGroupBy.category
                    ? Icons.category_rounded
                    : selectedGroupBy == InvoiceGroupBy.payment
                    ? Icons.payment_rounded
                    : Icons.person_rounded,
              ),
            )
            .toList(),
        onSelect: (idx) => setState(() => _selectedSubfolder = folderKeys[idx]),
        colors: colors,
      );
    }

    // Files inside the selected non-date folder
    final subfolderFiles = activeInvoices.where((item) {
      String key;
      switch (selectedGroupBy) {
        case InvoiceGroupBy.category:
          key = (item.category != null && item.category!.trim().isNotEmpty)
              ? item.category!.trim()
              : 'Uncategorized';
          break;
        case InvoiceGroupBy.payment:
          key =
              (item.paymentMethod != null &&
                  item.paymentMethod!.trim().isNotEmpty)
              ? item.paymentMethod!.trim()
              : 'Cash';
          break;
        case InvoiceGroupBy.profile:
          key =
              (item.profileType != null && item.profileType!.trim().isNotEmpty)
              ? item.profileType!.trim()
              : 'Personal';
          break;
        default:
          key = 'General';
      }
      return key == _selectedSubfolder;
    }).toList();

    return _buildUniformFilesGrid(files: subfolderFiles, colors: colors);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: !_canNavigateBackInHierarchy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigateBackHierarchy();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),

              // Header Row: Back (if inside folder) + Centered Dropdown + Right-aligned Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_canNavigateBackInHierarchy)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isBackHovered = true),
                          onExit: (_) => setState(() => _isBackHovered = false),
                          child: GestureDetector(
                            onTap: _navigateBackHierarchy,
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

                    // Centered Grouping Dropdown Button
                    Builder(
                      builder: (buttonContext) {
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => _isGroupDropdownHovered = true),
                          onExit: (_) =>
                              setState(() => _isGroupDropdownHovered = false),
                          child: AnimatedContainer(
                            height: 38,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: _isGroupDropdownHovered
                                  ? colors.purpleLight
                                  : colors.purple,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                backgroundColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                minimumSize: Size.zero,
                                overlayColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                              ),
                              onPressed: () async {
                                final renderBox =
                                    buttonContext.findRenderObject()
                                        as RenderBox;
                                final overlay =
                                    Navigator.of(
                                          context,
                                        ).overlay!.context.findRenderObject()
                                        as RenderBox;

                                final target = Rect.fromPoints(
                                  renderBox.localToGlobal(
                                    Offset.zero,
                                    ancestor: overlay,
                                  ),
                                  renderBox.localToGlobal(
                                    renderBox.size.bottomRight(Offset.zero),
                                    ancestor: overlay,
                                  ),
                                );

                                final chosen = await showMenu<InvoiceGroupBy>(
                                  context: context,
                                  color: colors.card,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  position: RelativeRect.fromRect(
                                    target,
                                    Offset.zero & overlay.size,
                                  ),
                                  items: InvoiceGroupBy.values.map((group) {
                                    final isSelected = group == selectedGroupBy;
                                    return PopupMenuItem<InvoiceGroupBy>(
                                      value: group,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            group.label,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? colors.purple
                                                  : colors.textPrimary,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(
                                              Icons.check,
                                              color: colors.purple,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );

                                if (chosen != null &&
                                    chosen != selectedGroupBy) {
                                  setState(() {
                                    selectedGroupBy = chosen;
                                    _resetHierarchy();
                                  });
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    selectedGroupBy.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Filter Icon Pinned to the Right
                    Align(
                      alignment: Alignment.centerRight,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _isFilterHovered = true),
                        onExit: (_) => setState(() => _isFilterHovered = false),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openFilterSheet,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isFilterHovered
                                  ? colors.cardLight
                                  : colors.cardLight.withValues(alpha: 0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/components/filter.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                    colors.textPrimary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                if (_hasActiveFilters)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: colors.purple,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              
              // Breadcrumb Navigation
              _buildBreadcrumbBar(colors),
              _buildFullWidthDivider(),

              // Dynamic Explorer Body
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CupertinoActivityIndicator(color: colors.purple),
                      )
                    : _buildHierarchyBody(colors),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderData {
  final String title;
  final int count;
  final IconData? icon;
  _FolderData({required this.title, required this.count, this.icon});
}

class _AutoStepDownText extends StatelessWidget {
  final String text;
  final double maxWidth;

  const _AutoStepDownText({required this.text, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        // Minimum width allows it to shrink from 11px down to ~9px
        minWidth: 0,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 11, // Starts at 11px, scaleDown scales it down to fit
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
