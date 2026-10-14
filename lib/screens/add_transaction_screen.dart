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
import '../constants/currency_constants.dart';

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

import '../widgets/app_snackbar.dart';
import '../services/preference_service.dart';

import '../widgets/transaction_input_tile.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_exchange_rate_dialog.dart';

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
  String baseCurrencyCode =
      "USD"; // 👈 Stores user's default currency (e.g. INR, USD)

  String? _hoveredToggleTab;

  final exchangeRateController = TextEditingController(text: "1.0");
  double exchangeRate = 1.0;

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

Future<void> _onCurrencyChanged(String newCurrency) async {
  setState(() {
    selectedCurrency = newCurrency;
  });

  final db = await DatabaseHelper.instance.database;
  final currencyData = await db.query(
    'currencies',
    where: 'code = ?',
    whereArgs: [newCurrency],
    limit: 1,
  );

  final double rate = currencyData.isNotEmpty
      ? (currencyData.first['rate_to_base'] as num).toDouble()
      : CurrencyConstants.getDefaultExchangeRate(newCurrency);

  if (mounted) {
    setState(() {
      exchangeRateController.text = rate.toString();
    });
  }
}


  @override
  void initState() {
    super.initState();
    _loadBaseCurrency(); // 👈 Add this

    // 👈 If initial attachments were passed from chat, pre-populate them
    if (widget.initialAttachments != null &&
        widget.initialAttachments!.isNotEmpty) {
      attachments = List.from(widget.initialAttachments!);
      selectedInvoice = File(
        attachments.last.localPath ?? attachments.last.fileName,
      );
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

  Future<void> _loadBaseCurrency() async {
    final raw = await PreferencesService.getBaseCurrency();
    final code = raw.split(' ').first.trim();
    if (!mounted) return;

    // Fetch the actual rate for the default currency
    final db = await DatabaseHelper.instance.database;
    final currencyData = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    final double rate = currencyData.isNotEmpty
        ? (currencyData.first['rate_to_base'] as num).toDouble()
        : CurrencyConstants.getDefaultExchangeRate(code);

    setState(() {
      baseCurrencyCode = code;
      if (widget.transaction == null && widget.draftTransaction == null) {
        selectedCurrency = code;
        exchangeRateController.text = rate.toString(); // 👈 Populates 1.08 for EUR, not 1.0
      }
    });
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
                              ? FontWeight.w500
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
                          fontWeight: FontWeight.w600,
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
          final String? thumbPath = await attachmentService
              .generatePdfThumbnailBestEffort(savedPdfPath, fileName);

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
          selectedInvoice = File(
            newAttachments.last.localPath ?? newAttachments.last.fileName,
          );
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      HapticFeedback.vibrate();
      context.showSnackBar(
        "User session not found. Please sign in again.",
        type: SnackBarType.error,
      );
      return;
    }

    final rawAmount = amountController.text.trim();

    // 1. Validate empty input
    if (rawAmount.isEmpty) {
      HapticFeedback.vibrate();
      context.showSnackBar("Please enter an amount", type: SnackBarType.error);
      return;
    }

    // 2. Validate parseable number
    final amount = double.tryParse(rawAmount);
    if (amount == null) {
      HapticFeedback.vibrate();
      context.showSnackBar(
        "Please enter a valid numeric amount",
        type: SnackBarType.error,
      );
      return;
    }

    // 3. Validate non-zero positive amount
    if (amount <= 0) {
      HapticFeedback.vibrate();
      context.showSnackBar(
        "Amount must be greater than 0",
        type: SnackBarType.error,
      );
      return;
    }

    // 4. Validate category existence
    if (selectedCategory.trim().isEmpty) {
      HapticFeedback.vibrate();
      context.showSnackBar(
        "Please select a category",
        type: SnackBarType.error,
      );
      return;
    }

    // 5. Resolve rate to USD anchor (Check DB table first, fallback to constants)
    final db = await DatabaseHelper.instance.database;
    final currencyData = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: [selectedCurrency],
      limit: 1,
    );

    final double dbRate = currencyData.isNotEmpty
        ? (currencyData.first['rate_to_base'] as num).toDouble()
        : CurrencyConstants.getDefaultExchangeRate(selectedCurrency);

    // Only use customRate if user is dealing with a foreign currency exchange rate dialog
    // Otherwise use dbRate (1.08 for EUR, 0.012 for INR, 1.0 for USD)
    final customRate = double.tryParse(exchangeRateController.text.trim());
    final double effectiveRate = (selectedCurrency == "USD")
        ? 1.0
        : ((customRate != null && customRate > 0 && customRate != 1.0)
            ? customRate
            : dbRate);

    // 6. Base amount calculation (ALWAYS anchored to USD)
    final double calculatedBase = amount * effectiveRate;
    final double finalBaseAmount = calculatedBase > 0 ? calculatedBase : amount;

    final transaction = TransactionModel(
      id: widget.transaction?.id,
      userId: user.uid,
      amount: amount,
      currency: selectedCurrency,
      exchangeRate: effectiveRate,
      baseAmount: finalBaseAmount, // 👈 Saved in USD anchor
      transactionType: transactionType,
      profileType: profileType,
      category: selectedCategory,
      subCategory: selectedSubcategory,
      note: noteController.text.trim(),
      merchant: merchantController.text.trim(),
      paymentMethod: paymentMethod,
      paymentName: paymentNameController.text.trim(),
      date: selectedDate,
      source: "manual",
      createdAt: widget.transaction?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final List<AttachmentModel> attachmentsToSave = List.from(attachments);

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

      for (final att in attachmentsToSave) {
        if (att.id == null) {
          final newAttachment = att.copyWith(
            transactionId: widget.transaction!.id,
          );
          await DatabaseHelper.instance.insertAttachment(newAttachment);
        }
      }
    }

    
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
                            duration: const Duration(milliseconds: 200),
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
                              duration: const Duration(milliseconds: 200),
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
                                  CurrencyConstants.supportedCurrencies,
                                  (value) async =>
                                      await _onCurrencyChanged(value),
                                  currentSelected: selectedCurrency,
                                  title: "Currency",
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Text(
                                  CurrencyConstants.getSymbol(selectedCurrency),
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: colors.hero,
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
                    svgAssetPath: 'assets/icons/addtransaction/payment.svg',
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
                    svgAssetPath: 'assets/icons/addtransaction/profile.svg',
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
                    svgAssetPath: 'assets/icons/addtransaction/date.svg',
                    title: "Date",
                    value:
                        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                    onTap: selectDate,
                  ),
                  if (selectedCurrency != baseCurrencyCode) ...[
                    _buildDivider(),
                    TransactionOptionTile(
                      svgAssetPath: 'assets/icons/addtransaction/exchange.svg',
                      title:
                          "Exchange Rate (1 $selectedCurrency = $baseCurrencyCode)",
                      value: exchangeRateController.text,
                      onTap: () async {
                        final updatedRate = await CustomExchangeRateDialog.show(
                          context,
                          initialRate: exchangeRateController.text,
                          sourceCurrency: selectedCurrency,
                          baseCurrency: baseCurrencyCode,
                        );

                        if (updatedRate != null && mounted) {
                          setState(() {
                            exchangeRateController.text = updatedRate;
                          });
                        }
                      },
                    ),
                  ],
                  _buildDivider(),
                  TransactionOptionTile(
                    svgAssetPath: 'assets/icons/addtransaction/invoice.svg',
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
                                      color: colors.hero,
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
                              //fontWeight: FontWeight.w500,
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
                  TransactionInputTile(
                    controller: merchantController,
                    hintText: "Merchant",
                    svgAssetPath: 'assets/icons/addtransaction/merchant.svg',
                  ),
                  _buildDivider(),
                  TransactionInputTile(
                    controller: paymentNameController,
                    hintText: "Payment name",
                    svgAssetPath: 'assets/icons/addtransaction/name.svg',
                  ),
                  _buildDivider(),
                  TransactionInputTile(
                    controller: noteController,
                    hintText: "Note",
                    svgAssetPath: 'assets/icons/addtransaction/note.svg',
                  ),
                ]),

                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 14),
                  child: Center(
                    child: SizedBox(
                      width: 100,
                      height:
                          38, // 👈 Explicitly locks height to match the 38px toggle system
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _isSaveHovered = true),
                        onExit: (_) => setState(() => _isSaveHovered = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: _isSaveHovered
                                ? colors.heroLight
                                : colors.hero,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              backgroundColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              overlayColor: Colors.transparent,
                              minimumSize: Size
                                  .zero, // 👈 Removes the default 48px constraint
                              padding: EdgeInsets
                                  .zero, // 👈 Ensures clean text centering within 38px
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: saveTransaction,
                            child: const Text(
                              "Save",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight
                                    .w600, // 👈 Matches toggle typography weight
                                fontSize:
                                    13, // 👈 Matches toggle 13px font size
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
        height: 38,
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
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      left: selectedIndex * tabWidth,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _hoveredToggleTab == transactionType
                              ? colors.heroLight
                              : colors.hero,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),

                    // 2. Interactive Buttons & Hover Targets
                    Row(
                      children: types.map((type) {
                        final isSelected = transactionType == type;
                        final isHovered = _hoveredToggleTab == type;

                        // Background color for non-selected items
                        Color? tabBackground;
                        if (!isSelected) {
                          tabBackground = isHovered
                              ? colors.secondaryLight
                              : colors
                                    .secondary; // or Colors.transparent if unhovered has no fill
                        }

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
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: tabBackground,
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
                        fontWeight: FontWeight.w600,
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
                                        ? colors.textPrimary
                                        : colors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check,
                                    color: colors.textPrimary,
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
