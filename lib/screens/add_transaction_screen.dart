import 'dart:io';

import 'package:flutter/cupertino.dart'; // Make sure this import is at the top

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transaction.dart';
import '../models/attachment.dart';

import '../services/transaction_service.dart';
import '../services/attachment_service.dart';

import '../constants/expense_categories.dart';
import '../constants/app_colors.dart';

import '../widgets/transaction_option_tile.dart';
import '../services/sync_service.dart'; // Make sure this import exists at top of file

import '../database/database_helper.dart';
import '../utils/app_logger.dart';

import '../widgets/attachment_thumbnail_view.dart';
import '../screens/attachment_gallery_screen.dart';

import '../models/category_model.dart';
import '../services/category_service.dart';

import 'package:flutter_svg/flutter_svg.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final TransactionModel? draftTransaction;

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.draftTransaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  final merchantController = TextEditingController();
  final paymentNameController = TextEditingController();

  String selectedCategory = "";
  String selectedSubcategory = "";
  String transactionType = "expense";
  String profileType = "Personal";
  String paymentMethod = "Cash";

  DateTime selectedDate = DateTime.now();
  File? selectedInvoice;
  List<AttachmentModel> attachments = [];
  List<CategoryModel> categories = [];

  final transactionService = TransactionService();
  final attachmentService = AttachmentService();
  final categoryService = CategoryService();

  String?
  _hoveredTypeButton; // 👈 Tracks which type button is currently hovered
  bool _isSaveHovered = false; // 👈 Tracks hover for Save button

  bool _isBackHovered = false;
  bool _isDeleteHovered = false;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction ?? widget.draftTransaction;

    if (transaction != null) {
      amountController.text = transaction.amount.toString();
      selectedCategory = transaction.category ?? "Food";
      selectedSubcategory = transaction.subCategory ?? "Restaurant";
      noteController.text = transaction.note ?? "";
      merchantController.text = transaction.merchant ?? "";
      paymentNameController.text = transaction.paymentName ?? "";
      paymentMethod = transaction.paymentMethod ?? "Cash";
      transactionType = transaction.transactionType;
      profileType = transaction.profileType;
      selectedDate = transaction.date;

      loadAttachments();
    }
    loadCategories();
  }

  String _getCategoryIconPath(String category) {
    const String baseCat = 'assets/icons/categories';
    final cat = category.trim().toLowerCase().replaceAll(' ', '_');
    if (cat.isNotEmpty && cat != 'other') {
      return '$baseCat/$cat.svg';
    }
    return '$baseCat/other.svg';
  }

  String _getSubcategoryIconPath(String subcategory) {
    const String baseSub = 'assets/icons/subcategories';
    final sub = subcategory.trim().toLowerCase().replaceAll(' ', '_');
    if (sub.isNotEmpty && sub != 'other') {
      return '$baseSub/$sub.svg';
    }
    return 'assets/icons/categories/other.svg';
  }

  Future<void> loadCategories() async {
    final fetched = await categoryService.getAllCategories();
    if (!mounted) return;

    setState(() {
      categories = fetched;
      if (categories.isNotEmpty) {
        // If not editing an existing transaction, pick the first category and subcategory
        if (selectedCategory.isEmpty) {
          selectedCategory = categories.first.name;
          selectedSubcategory = categories.first.subcategories.isNotEmpty
              ? categories.first.subcategories.first
              : "Other";
        } else if (selectedSubcategory.isEmpty) {
          final matched = categories.firstWhere(
            (c) => c.name.toLowerCase() == selectedCategory.toLowerCase(),
            orElse: () => categories.first,
          );
          selectedSubcategory = matched.subcategories.isNotEmpty
              ? matched.subcategories.first
              : "Other";
        }
      }
    });
  }

  Future<void> loadAttachments() async {
    if (widget.transaction == null) {
      return;
    }

    attachments = await attachmentService.getAttachments(
      widget.transaction!.id!,
    );

    setState(() {});
  }

  Future<void> selectDate() async {
    final colors = context.colors;

    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    final years = List.generate(101, (i) => 2000 + i);

    int tempYear = selectedDate.year;
    int tempMonth = selectedDate.month;
    int tempDay = selectedDate.day;

    const int yearBase = 12120; // 101 * 120 (Exact multiple of 101)
    const int monthBase = 12000; // 12 * 1000 (Exact multiple of 12)

    int currentDaysCount = DateUtils.getDaysInMonth(tempYear, tempMonth);
    int dayBase =
        (12000 ~/ currentDaysCount) *
        currentDaysCount; // Exact multiple of currentDaysCount

    final yearController = FixedExtentScrollController(
      initialItem: yearBase + years.indexOf(tempYear),
    );
    final monthController = FixedExtentScrollController(
      initialItem: monthBase + (tempMonth - 1),
    );
    FixedExtentScrollController dayController = FixedExtentScrollController(
      initialItem: dayBase + (tempDay - 1),
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final daysInCurrentMonth = DateUtils.getDaysInMonth(
              tempYear,
              tempMonth,
            );

            // Re-sync controller when month length changes (e.g. leap year or 30/31 days)
            if (daysInCurrentMonth != currentDaysCount) {
              currentDaysCount = daysInCurrentMonth;
              if (tempDay > daysInCurrentMonth) {
                tempDay = daysInCurrentMonth;
              }
              dayBase = (12000 ~/ currentDaysCount) * currentDaysCount;
              dayController.dispose();
              dayController = FixedExtentScrollController(
                initialItem: dayBase + (tempDay - 1),
              );
            }

            void updateDate() {
              if (tempDay > daysInCurrentMonth) {
                tempDay = daysInCurrentMonth;
              }
              setState(() {
                selectedDate = DateTime(tempYear, tempMonth, tempDay);
              });
            }

            Widget buildInfiniteWheel({
              required Key key,
              required FixedExtentScrollController controller,
              required int moduloCount,
              required int currentSelectedValue,
              required String Function(int) labelBuilder,
              required ValueChanged<int> onSelectedItemChanged,
            }) {
              return ListWheelScrollView.useDelegate(
                key: key,
                controller: controller,
                itemExtent: 42,
                perspective: 0.0001,
                diameterRatio: 30,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: onSelectedItemChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: null,
                  builder: (context, index) {
                    final itemVal =
                        ((index % moduloCount) + moduloCount) % moduloCount;
                    final isSelected = itemVal == currentSelectedValue;

                    return Center(
                      child: Text(
                        labelBuilder(itemVal),
                        style: TextStyle(
                          fontSize: isSelected ? 18 : 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: colors.textPrimary.withOpacity(
                            isSelected ? 1.0 : 0.35,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            return SizedBox(
              height: 380,
              width: double.infinity,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 42,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: colors.iconCircle.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Row(
                          children: [
                            // 1. Year (Cyclic)
                            Expanded(
                              flex: 2,
                              child: buildInfiniteWheel(
                                key: const ValueKey('year_wheel'),
                                controller: yearController,
                                moduloCount: years.length,
                                currentSelectedValue: years.indexOf(tempYear),
                                labelBuilder: (val) => "${years[val]}",
                                onSelectedItemChanged: (index) {
                                  setModalState(() {
                                    final val =
                                        ((index % years.length) +
                                            years.length) %
                                        years.length;
                                    tempYear = years[val];
                                  });
                                  updateDate();
                                },
                              ),
                            ),
                            // 2. Month (Cyclic: Dec -> Jan -> Feb...)
                            Expanded(
                              flex: 3,
                              child: buildInfiniteWheel(
                                key: const ValueKey('month_wheel'),
                                controller: monthController,
                                moduloCount: 12,
                                currentSelectedValue: tempMonth - 1,
                                labelBuilder: (val) => months[val],
                                onSelectedItemChanged: (index) {
                                  setModalState(() {
                                    final val = ((index % 12) + 12) % 12;
                                    tempMonth = val + 1;
                                  });
                                  updateDate();
                                },
                              ),
                            ),
                            // 3. Day (Cyclic with dynamic modulo alignment)
                            Expanded(
                              flex: 2,
                              child: buildInfiniteWheel(
                                key: ValueKey(
                                  'day_wheel_${daysInCurrentMonth}',
                                ),
                                controller: dayController,
                                moduloCount: daysInCurrentMonth,
                                currentSelectedValue: tempDay - 1,
                                labelBuilder: (val) => "${val + 1}",
                                onSelectedItemChanged: (index) {
                                  setModalState(() {
                                    final val =
                                        ((index % daysInCurrentMonth) +
                                            daysInCurrentMonth) %
                                        daysInCurrentMonth;
                                    tempDay = val + 1;
                                  });
                                  updateDate();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Future<void> pickInvoice() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result == null || result.files.single.path == null) {
      return;
    }

    final String pickedPath = result.files.single.path!;

    final AttachmentModel model = await attachmentService.processPickedFilePath(
      pickedPath,
      transactionId: widget.transaction?.id,
    );

    setState(() {
      selectedInvoice = File(model.localPath ?? pickedPath);
      attachments.add(model); // Appends to list instead of replacing
    });
  }

  void _openGallery({int initialIndex = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttachmentGalleryScreen(
          attachments: attachments,
          initialIndex: initialIndex,
          onAddMore: () async {
            await pickInvoice();
            setState(() {});
          },
          onDelete: (index) {
            setState(() {
              attachments.removeAt(index);
              if (attachments.isEmpty) {
                selectedInvoice = null;
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> saveTransaction() async {
    if (amountController.text.trim().isEmpty) {
      return;
    }

    final amount = double.tryParse(amountController.text.trim());

    if (amount == null) {
      return;
    }

    final transaction = TransactionModel(
      id: widget.transaction?.id,
      userId: "local_user",
      amount: amount,
      transactionType: transactionType,
      profileType: profileType,
      category: selectedCategory,
      subCategory: selectedSubcategory,
      note: noteController.text,
      merchant: merchantController.text,
      paymentMethod: paymentMethod,
      paymentName: paymentNameController.text,
      date: selectedDate,
      source: "manual",
      createdAt: widget.transaction?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. Prepare attachments to save
    List<AttachmentModel> attachmentsToSave = List.from(attachments);

    // If the user picked a new invoice file from the file picker
    if (selectedInvoice != null) {
      final now = DateTime.now();
      final fileName = selectedInvoice!.path.split(Platform.pathSeparator).last;

      final newAttachment = AttachmentModel(
        transactionId: widget.transaction?.id,
        fileName: fileName,
        localPath: selectedInvoice!.path,
        localThumbnailPath: selectedInvoice!.path,
        fileType: 'image/jpeg',
        isSynced: false,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
      );

      attachmentsToSave.add(newAttachment);
    }

    // 2. Persist to Database with Sync Queue
    if (widget.transaction == null) {
      if (attachmentsToSave.isNotEmpty) {
        await DatabaseHelper.instance.insertTransactionWithAttachments(
          transaction,
          attachmentsToSave,
        );
      } else {
        await DatabaseHelper.instance.insertTransaction(transaction);
      }
    } else {
      await DatabaseHelper.instance.updateTransaction(transaction);

      // If updating an existing transaction with a new attached invoice
      if (selectedInvoice != null && attachmentsToSave.isNotEmpty) {
        final lastAttachment = attachmentsToSave.last.copyWith(
          transactionId: widget.transaction!.id,
        );
        await DatabaseHelper.instance.insertAttachment(lastAttachment);
      }
    }

    // 3. Trigger immediate sync queue processing (Cloudflare R2 & backend)
    appLog(
      '🟢 [UI] Transaction & attachments saved. Triggering SyncService...',
    );
    SyncService().processSyncQueue();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _onWillPop() async {
    final initial = widget.transaction ?? widget.draftTransaction;

    bool hasInput;
    if (initial != null) {
      // When editing: check if any value actually changed
      final amountChanged =
          amountController.text.trim() != initial.amount.toString();
      final noteChanged = noteController.text.trim() != (initial.note ?? "");
      final merchantChanged =
          merchantController.text.trim() != (initial.merchant ?? "");
      final paymentNameChanged =
          paymentNameController.text.trim() != (initial.paymentName ?? "");
      final categoryChanged = selectedCategory != (initial.category ?? "");
      final subcategoryChanged =
          selectedSubcategory != (initial.subCategory ?? "");
      final typeChanged = transactionType != initial.transactionType;
      final profileChanged = profileType != initial.profileType;
      final paymentChanged = paymentMethod != (initial.paymentMethod ?? "cash");
      final dateChanged = selectedDate != initial.date;
      final attachmentChanged = selectedInvoice != null;

      hasInput =
          amountChanged ||
          noteChanged ||
          merchantChanged ||
          paymentNameChanged ||
          categoryChanged ||
          subcategoryChanged ||
          typeChanged ||
          profileChanged ||
          paymentChanged ||
          dateChanged ||
          attachmentChanged;
    } else {
      // When adding new: check if user typed anything
      hasInput =
          amountController.text.trim().isNotEmpty ||
          merchantController.text.trim().isNotEmpty ||
          noteController.text.trim().isNotEmpty ||
          paymentNameController.text.trim().isNotEmpty ||
          attachments.isNotEmpty ||
          selectedInvoice != null;
    }

    if (!hasInput) return true;

    final colors = context.colors;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          "Discard Changes?",
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          "You have unsaved changes. Are you sure you want to exit without saving?",
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Keep Editing",
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Discard", style: TextStyle(color: colors.expense)),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  Future<void> _confirmDelete() async {
    if (widget.transaction?.id == null) return;

    final colors = context.colors;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          "Delete Transaction",
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          "Are you sure you want to delete this transaction?",
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: TextStyle(color: colors.expense)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      await DatabaseHelper.instance.deleteTransaction(widget.transaction!.id!);
      SyncService().processSyncQueue();
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Custom Action Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _isBackHovered = true),
                        onExit: (_) => setState(() => _isBackHovered = false),
                        child: IconButton(
                          hoverColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          icon: SvgPicture.asset(
                            'assets/icons/components/trash.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              _isBackHovered
                                  ? Color.alphaBlend(
                                      Colors.black.withValues(alpha: 0.35),
                                      colors.textPrimary,
                                    )
                                  : colors.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                          onPressed: () async {
                            final shouldPop = await _onWillPop();
                            if (shouldPop && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      if (widget.transaction != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isDeleteHovered = true),
                          onExit: (_) => setState(() => _isDeleteHovered = false),
                          child: IconButton(
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            icon: SvgPicture.asset(
                              'assets/icons/components/trash.svg',
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                _isDeleteHovered
                                    ? Color.alphaBlend(
                                        Colors.black.withValues(alpha: 0.35),
                                        colors.textPrimary,
                                      )
                                    : colors.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                          onPressed: _confirmDelete,
                        ),
                      )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 46,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    prefixText: "₹ ",
                    prefixStyle: TextStyle(color: colors.textPrimary),
                    hintText: "0",
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 380, // 👈 Set your exact fixed width here
                    child: Row(
                      children: [
                        typeButton("expense"),
                        typeButton("income"),
                        typeButton("transfer"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),TransactionOptionTile(
                  svgAssetPath: _getCategoryIconPath(selectedCategory),
                  title: "Category",
                  value: selectedCategory,
                  onTap: () {
                    if (categories.isEmpty) return;
                    showPicker(
                      categories.map((c) => c.name).toList(),
                      (value) {
                        final matched = categories.firstWhere(
                          (c) => c.name == value,
                          orElse: () => categories.first,
                        );
                        setState(() {
                          selectedCategory = value;
                          selectedSubcategory = matched.subcategories.isNotEmpty
                              ? matched.subcategories.first
                              : "Other";
                        });
                      },
                      currentSelected: selectedCategory,
                      title: "Category",
                    );
                  },
                ),
                TransactionOptionTile(
                  svgAssetPath: _getSubcategoryIconPath(selectedSubcategory),
                  title: "Subcategory",
                  value: selectedSubcategory,
                  onTap: () {
                    final currentCategory = categories.firstWhere(
                      (c) => c.name == selectedCategory,
                      orElse: () => categories.isNotEmpty
                          ? categories.first
                          : CategoryModel(name: '', subcategories: ['Other']),
                    );

                    showPicker(
                      currentCategory.subcategories,
                      (value) {
                        setState(() {
                          selectedSubcategory = value;
                        });
                      },
                      currentSelected: selectedSubcategory,
                      title: "Subcategory",
                    );
                  },
                ),
                TransactionOptionTile(
                  svgAssetPath: 'assets/icons/components/payment.svg',
                  title: "Payment",
                  value: paymentMethod,
                  onTap: () {
                    showPicker(
                      ["Cash", "Credit Card", "Debit Card", "UPI", "Bank"],
                      (value) {
                        setState(() {
                          paymentMethod = value;
                        });
                      },
                      currentSelected: paymentMethod,
                      title: "Payment",
                    );
                  },
                ),
                TransactionOptionTile(
                  svgAssetPath: 'assets/icons/components/profile.svg',
                  title: "Profile",
                  value: profileType,
                  onTap: () {
                    showPicker(
                      ["Personal", "Business"],
                      (value) {
                        setState(() {
                          profileType = value;
                        });
                      },
                      currentSelected: profileType,
                      title: "Profile",
                    );
                  },
                ),
                TransactionOptionTile(
                  svgAssetPath: 'assets/icons/components/calendar.svg',
                  title: "Date",
                  value:
                      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  onTap: selectDate,
                ),
                TransactionOptionTile(
                  svgAssetPath: 'assets/icons/components/invoice.svg',
                  title: "Invoice",
                  trailingWidget: attachments.isNotEmpty
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AttachmentThumbnailView(
                              attachment: attachments.first,
                              size: 34,
                              borderRadius: 6,
                            ),
                            if (attachments.length > 1)
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.purple,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "+${attachments.length - 1}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Text(
                          "Add",
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                  onTap: () {
                    if (attachments.isEmpty) {
                      pickInvoice();
                    } else {
                      _openGallery();
                    }
                  },
                ),
                customInput(
                  controller: merchantController,
                  hint: "Merchant",
                  svgAssetPath: 'assets/icons/components/store.svg',
                ),
                customInput(
                  controller: paymentNameController,
                  hint: "Payment name",
                  svgAssetPath: 'assets/icons/components/wallet.svg',
                ),
                customInput(
                  controller: noteController,
                  hint: "Note",
                  svgAssetPath: 'assets/icons/components/note.svg',
                ),
                const SizedBox(height: 25),
                Center(
                  child: SizedBox(
                    width: 100,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _isSaveHovered = true),
                      onExit: (_) => setState(() => _isSaveHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: _isSaveHovered
                              ? Color.alphaBlend(
                                  Colors.black.withValues(alpha: 0.25),
                                  colors.purple,
                                )
                              : colors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            minimumSize: const Size(
                              0,
                              kMinInteractiveDimension,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: saveTransaction,
                          child: const Text(
                            "Save",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget typeButton(String type) {
    final selected = transactionType == type;
    final colors = context.colors;
    final isHovered = _hoveredTypeButton == type;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredTypeButton = type),
          onExit: (_) => setState(() => _hoveredTypeButton = null),
          child: selected
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? Color.alphaBlend(
                            Colors.black.withValues(alpha: 0.25),
                            colors.purple,
                          )
                        : colors.purple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      minimumSize: const Size(0, kMinInteractiveDimension),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        transactionType = type;
                      });
                    },
                    child: Text(
                      "${type[0].toUpperCase()}${type.substring(1)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, kMinInteractiveDimension),
                    side: BorderSide(
                      color: colors.textSecondary.withOpacity(0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      transactionType = type;
                    });
                  },
                  child: Text(
                    "${type[0].toUpperCase()}${type.substring(1)}",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget customInput({
    required TextEditingController controller,
    required String hint,
    required String svgAssetPath,
  }) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: colors.card),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          icon: Container(
            height: 36,
            width: 36,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.iconCircle,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              svgAssetPath,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(
                colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: colors.textHint,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void showPicker(
    List<String> items,
    Function(String) selected, {
    String? currentSelected,
    String? title,
  }) {
    final colors = context.colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Options List matching Sort/Filter sheet style
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected =
                          currentSelected != null &&
                          (currentSelected.toLowerCase() == item.toLowerCase());

                      return InkWell(
                        onTap: () {
                          selected(item);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.replaceAll("_", " "),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? colors.purple
                                      : colors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
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
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
