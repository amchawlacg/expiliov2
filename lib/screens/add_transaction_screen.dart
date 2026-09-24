import 'dart:io';

import 'package:flutter/cupertino.dart';
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
import '../services/sync_service.dart';

import '../database/database_helper.dart';
import '../utils/app_logger.dart';

import '../widgets/attachment_thumbnail_view.dart';
import 'attachment_gallery_screen.dart';

import '../models/category_model.dart';
import '../services/category_service.dart';

import '../widgets/app_alert_dialog.dart';

import 'package:flutter_svg/flutter_svg.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final TransactionModel? draftTransaction;
  final List<AttachmentModel>? initialAttachments; // 👈 Add this

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.draftTransaction,
    this.initialAttachments, // 👈 Add this
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
  String selectedCurrency = "USD";

  String? _hoveredToggleTab;

  final exchangeRateController = TextEditingController(text: "1.0");
  double exchangeRate = 1.0;

  final Map<String, String> currencySymbols = {
    "INR": "₹",
    "USD": "\$",
    "EUR": "€",
    "GBP": "£",
    "AED": "د.إ",
    "CAD": "C\$",
    "AUD": "A\$",
  };

  DateTime selectedDate = DateTime.now();
  File? selectedInvoice;
  List<AttachmentModel> attachments = [];
  List<CategoryModel> categories = [];

  final transactionService = TransactionService();
  final attachmentService = AttachmentService();
  final categoryService = CategoryService();

  String? _hoveredTypeButton;
  bool _isSaveHovered = false;
  bool _isBackHovered = false;
  bool _isDeleteHovered = false;

  void _onCurrencyChanged(String newCurrency) {
    setState(() {
      selectedCurrency = newCurrency;
      if (newCurrency == "USD") {
        exchangeRateController.text = "1.0";
      } else {
        const defaultRatesToUSD = {
          "INR": 0.012,
          "EUR": 1.08,
          "GBP": 1.27,
          "AED": 0.27,
          "CAD": 0.73,
          "AUD": 0.65,
        };
        final rate = defaultRatesToUSD[newCurrency] ?? 1.0;
        exchangeRateController.text = rate.toString();
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // 👈 If initial attachments were passed from chat, pre-populate them
    if (widget.initialAttachments != null && widget.initialAttachments!.isNotEmpty) {
      attachments = List.from(widget.initialAttachments!);
      selectedInvoice = File(attachments.last.localPath ?? attachments.last.fileName);
    }

    final transaction = widget.transaction ?? widget.draftTransaction;

    if (transaction != null) {
      amountController.text = transaction.amount.toString();
      selectedCategory = transaction.category ?? "Food";
      selectedSubcategory = transaction.subCategory ?? "Restaurant";
      noteController.text = transaction.note ?? "";
      merchantController.text = transaction.merchant ?? "";
      paymentNameController.text = transaction.paymentName ?? "";
      paymentMethod = transaction.paymentMethod ?? "Cash";
      selectedCurrency = transaction.currency;
      exchangeRateController.text = transaction.exchangeRate.toString();
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
    if (widget.transaction == null) return;
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

    const int yearBase = 12120;
    const int monthBase = 12000;

    int currentDaysCount = DateUtils.getDaysInMonth(tempYear, tempMonth);
    int dayBase = (12000 ~/ currentDaysCount) * currentDaysCount;

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
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final daysInCurrentMonth = DateUtils.getDaysInMonth(
              tempYear,
              tempMonth,
            );

            if (daysInCurrentMonth != currentDaysCount) {
              currentDaysCount = daysInCurrentMonth;
              if (tempDay > daysInCurrentMonth) tempDay = daysInCurrentMonth;
              dayBase = (12000 ~/ currentDaysCount) * currentDaysCount;
              dayController.dispose();
              dayController = FixedExtentScrollController(
                initialItem: dayBase + (tempDay - 1),
              );
            }

            void updateDate() {
              if (tempDay > daysInCurrentMonth) tempDay = daysInCurrentMonth;
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

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      const SizedBox(height: 14),
                      Text(
                        "Select Date",
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 42,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: colors.iconCircle.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: buildInfiniteWheel(
                                    key: const ValueKey('year_wheel'),
                                    controller: yearController,
                                    moduloCount: years.length,
                                    currentSelectedValue: years.indexOf(
                                      tempYear,
                                    ),
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
                                Expanded(
                                  flex: 2,
                                  child: buildInfiniteWheel(
                                    key: ValueKey(
                                      'day_wheel_$daysInCurrentMonth',
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
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<AttachmentModel>> pickInvoice() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: true, // 👈 Allows multi-file selection
    );

    if (result == null || result.files.isEmpty) return [];

    final List<AttachmentModel> newAttachments = [];

    for (final file in result.files) {
      if (file.path == null) continue;

      final String pickedPath = file.path!;
      final String fileName = file.name;
      final String ext = pickedPath.split('.').last.toLowerCase();
      final bool isPdf = ext == 'pdf';

      AttachmentModel model;

      if (isPdf) {
        // 1. Copy the PDF to permanent sandboxed storage immediately
        final String savedPdfPath = await attachmentService.copyToAppStorage(
          pickedPath,
          fileName,
        );

        // 2. Best-effort Page 1 render (returns file path if successful, null if protected)
        final String? thumbPath = await attachmentService.generatePdfThumbnailBestEffort(
          savedPdfPath,
          fileName,
        );

        final now = DateTime.now();
        model = AttachmentModel(
          transactionId: widget.transaction?.id,
          fileName: fileName,
          localPath: savedPdfPath,
          localThumbnailPath: thumbPath, // 👈 Real Page 1 thumbnail or null
          fileType: 'application/pdf',
          isSynced: false,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        model = await attachmentService.processPickedFilePath(
          pickedPath,
          transactionId: widget.transaction?.id,
        );
      }

      newAttachments.add(model);
    }

    if (newAttachments.isNotEmpty) {
      setState(() {
        selectedInvoice = File(newAttachments.last.localPath ?? newAttachments.last.fileName);
        attachments.addAll(newAttachments);
      });
    }

    return newAttachments;
  } catch (e, stack) {
    debugPrint("❌ Error picking invoice: $e\n$stack");
    return [];
  }
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
  if (amountController.text.trim().isEmpty) return;
  final amount = double.tryParse(amountController.text.trim());
  if (amount == null) return;

  final rate = double.tryParse(exchangeRateController.text.trim()) ?? 1.0;

  final transaction = TransactionModel(
    id: widget.transaction?.id,
    userId: "local_user",
    amount: amount,
    currency: selectedCurrency,
    exchangeRate: rate,
    baseAmount: amount * rate,
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

  // 'attachments' already contains all existing + newly picked files
  final List<AttachmentModel> attachmentsToSave = List.from(attachments);

  if (widget.transaction == null) {
    // New transaction
    if (attachmentsToSave.isNotEmpty) {
      await DatabaseHelper.instance.insertTransactionWithAttachments(
        transaction,
        attachmentsToSave,
      );
    } else {
      await DatabaseHelper.instance.insertTransaction(transaction);
    }
  } else {
    // Updating existing transaction
    await DatabaseHelper.instance.updateTransaction(transaction);

    // Save newly added attachments (those without a database primary key id)
    for (final att in attachmentsToSave) {
      if (att.id == null) {
        final newAttachment = att.copyWith(
          transactionId: widget.transaction!.id,
        );
        await DatabaseHelper.instance.insertAttachment(newAttachment);
      }
    }
  }

  appLog(
    '🟢 [UI] Transaction & attachments saved. Triggering SyncService...',
  );
  SyncService().processSyncQueue();

  if (mounted) Navigator.pop(context, true);
}

  Future<bool> _onWillPop() async {
    final initial = widget.transaction ?? widget.draftTransaction;

    bool hasInput;
    if (initial != null) {
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
      final currencyChanged = selectedCurrency != initial.currency;
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
          currencyChanged ||
          dateChanged ||
          attachmentChanged;
    } else {
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
    final shouldDiscard = await AppAlertDialog.show(
      context,
      title: "Discard Changes?",
      message:
          "You have unsaved changes. Are you sure you want to exit without saving?",
      confirmText: "Discard",
      cancelText: "Keep Editing",
      isDestructive: true,
    );

    return shouldDiscard ?? false;
  }

  Future<void> _confirmDelete() async {
    if (widget.transaction?.id == null) return;

    final shouldDelete = await AppAlertDialog.show(
      context,
      title: "Delete Transaction",
      message: "Are you sure you want to delete this transaction?",
      confirmText: "Delete",
      cancelText: "Cancel",
      isDestructive: true,
    );

    if (shouldDelete == true && mounted) {
      await DatabaseHelper.instance.deleteTransaction(widget.transaction!.id!);
      SyncService().processSyncQueue();
      if (mounted) Navigator.pop(context, true);
    }
  }

  // --- Scaffolding Helpers ---

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.colors.cardLight.withValues(alpha: 0.6),
      indent: 16,
      endIndent: 16,
    );
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
            padding: const EdgeInsets.only(top: 8, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Buttons (scroll out of view naturally)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _isBackHovered = true),
                        onExit: (_) => setState(() => _isBackHovered = false),
                        child: GestureDetector(
                          onTap: () async {
                            final shouldPop = await _onWillPop();
                            if (shouldPop && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
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

                      // Trash Button
                      if (widget.transaction != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => _isDeleteHovered = true),
                          onExit: (_) =>
                              setState(() => _isDeleteHovered = false),
                          child: GestureDetector(
                            onTap: _confirmDelete,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(8),
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
                        )
                      else
                        const SizedBox(width: 36, height: 36),
                    ],
                  ),
                ),

                // 2. Amount Row (shifted upward via negative offset)
                Transform.translate(
                  offset: const Offset(
                    0,
                    -26,
                  ), // 👈 Adjust if you want it slightly higher/lower
                  child: Column(
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            // Clickable currency symbol
                            GestureDetector(
                              onTap: () {
                                showPicker(
                                  currencySymbols.keys.toList(),
                                  (value) => _onCurrencyChanged(value),
                                  currentSelected: selectedCurrency,
                                  title: "Currency",
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Text(
                                  currencySymbols[selectedCurrency] ??
                                      selectedCurrency,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: colors.purple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // Input field
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                maxWidth: 220,
                              ),
                              child: IntrinsicWidth(
                                child: TextField(
                                  controller: amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}'),
                                    ),
                                  ],
                                  style: TextStyle(
                                    fontSize: 32,
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: "0",
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      _buildTypeToggle(),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Card Container with Horizontal Margin & Structured Dividers
                _buildCardContainer([
                  TransactionOptionTile(
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
                            selectedSubcategory =
                                matched.subcategories.isNotEmpty
                                ? matched.subcategories.first
                                : "Other";
                          });
                        },
                        currentSelected: selectedCategory,
                        title: "Category",
                      );
                    },
                  ),
                  _buildDivider(),
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
                        (value) => setState(() => selectedSubcategory = value),
                        currentSelected: selectedSubcategory,
                        title: "Subcategory",
                      );
                    },
                  ),
                  _buildDivider(),
                  TransactionOptionTile(
                    svgAssetPath: 'assets/icons/components/payment.svg',
                    title: "Payment",
                    value: paymentMethod,
                    onTap: () {
                      showPicker(
                        ["Cash", "Credit Card", "Debit Card", "UPI", "Bank"],
                        (value) => setState(() => paymentMethod = value),
                        currentSelected: paymentMethod,
                        title: "Payment",
                      );
                    },
                  ),
                  _buildDivider(),
                  TransactionOptionTile(
                    svgAssetPath: 'assets/icons/components/profile.svg',
                    title: "Profile",
                    value: profileType,
                    onTap: () {
                      showPicker(
                        ["Personal", "Business"],
                        (value) => setState(() => profileType = value),
                        currentSelected: profileType,
                        title: "Profile",
                      );
                    },
                  ),
                  _buildDivider(),
                  TransactionOptionTile(
                    svgAssetPath: 'assets/icons/components/calendar.svg',
                    title: "Date",
                    value:
                        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                    onTap: selectDate,
                  ),
                  if (selectedCurrency != "USD") ...[
                    _buildDivider(),
                    TransactionOptionTile(
                      svgAssetPath: 'assets/icons/components/wallet.svg',
                      title: "Exchange Rate (1 $selectedCurrency = \$ USD)",
                      value: exchangeRateController.text,
                      onTap: () async {
                        final inputController = TextEditingController(
                          text: exchangeRateController.text,
                        );
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: colors.card,
                            title: Text(
                              "Custom Exchange Rate",
                              style: TextStyle(color: colors.textPrimary),
                            ),
                            content: TextField(
                              controller: inputController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(color: colors.textPrimary),
                              decoration: InputDecoration(
                                labelText: "1 $selectedCurrency in USD",
                                labelStyle: TextStyle(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (inputController.text.trim().isNotEmpty) {
                                    setState(() {
                                      exchangeRateController.text =
                                          inputController.text.trim();
                                    });
                                  }
                                  Navigator.pop(ctx);
                                },
                                child: Text(
                                  "Apply",
                                  style: TextStyle(color: colors.purple),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  _buildDivider(),
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
                  _buildDivider(),
                  customInput(
                    controller: merchantController,
                    hint: "Merchant",
                    svgAssetPath: 'assets/icons/components/store.svg',
                  ),
                  _buildDivider(),
                  customInput(
                    controller: paymentNameController,
                    hint: "Payment name",
                    svgAssetPath: 'assets/icons/components/wallet.svg',
                  ),
                  _buildDivider(),
                  customInput(
                    controller: noteController,
                    hint: "Note",
                    svgAssetPath: 'assets/icons/components/note.svg',
                  ),
                ]),

                Padding(
                  padding: const EdgeInsets.only(
                    top: 14,
                    bottom: 14,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 100,
                      height: 38, // 👈 Explicitly locks height to match the 38px toggle system
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _isSaveHovered = true),
                        onExit: (_) => setState(() => _isSaveHovered = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: _isSaveHovered
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
                              overlayColor: Colors.transparent,
                              minimumSize: Size.zero, // 👈 Removes the default 48px constraint
                              padding: EdgeInsets.zero, // 👈 Ensures clean text centering within 38px
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: saveTransaction,
                            child: const Text(
                              "Save",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600, // 👈 Matches toggle typography weight
                                fontSize: 13, // 👈 Matches toggle 13px font size
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
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    final colors = context.colors;
    const types = ["expense", "income", "transfer"];
    final selectedIndex = types.indexOf(transactionType).clamp(0, 2);

    return Center(
      child: SizedBox(
        width: 380,
        height: 38, // 👈 Matches the rendered 38px Save button
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colors.cardLight.withValues(alpha: 0.8),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / types.length;

                return Stack(
                  children: [
                    // 1. Sliding Active Purple Pill
                    // 1. Sliding Active Purple Pill
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      left: selectedIndex * tabWidth,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: AnimatedContainer(
                        // 👈 Use AnimatedContainer so the color transition matches the 200ms ease
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _hoveredToggleTab == transactionType
                              ? colors.purpleLight
                              : colors.purple,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),

                    // 2. Interactive Buttons & Hover Targets
                    Row(
                      children: types.map((type) {
                        final isSelected = transactionType == type;
                        final isHovered = _hoveredToggleTab == type;

                        return Expanded(
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _hoveredToggleTab = type),
                            onExit: (_) =>
                                setState(() => _hoveredToggleTab = null),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => transactionType = type);
                              },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: (!isSelected && isHovered)
                                      ? colors.cardLight.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  "${type[0].toUpperCase()}${type.substring(1)}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
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
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          icon: SizedBox(
            width: 24,
            height: 24,
            child: Center(
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
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: colors.textHint,
            fontSize: 14,
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected =
                            currentSelected != null &&
                            (currentSelected.toLowerCase() ==
                                item.toLowerCase());

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
          ),
        );
      },
    );
  }
}
