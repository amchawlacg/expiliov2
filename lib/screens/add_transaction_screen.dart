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
  String profileType = "personal";
  String paymentMethod = "cash";

  DateTime selectedDate = DateTime.now();
  File? selectedInvoice;
  List<AttachmentModel> attachments = [];
  List<CategoryModel> categories = [];

  final transactionService = TransactionService();
  final attachmentService = AttachmentService();
  final categoryService = CategoryService();

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
      paymentMethod = transaction.paymentMethod ?? "cash";
      transactionType = transaction.transactionType;
      profileType = transaction.profileType;
      selectedDate = transaction.date;

      loadAttachments();
    }
    loadCategories();
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
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];
  final years = List.generate(101, (i) => 2000 + i);

  int tempMonth = selectedDate.month;
  int tempDay = selectedDate.day;
  int tempYear = selectedDate.year;

  // Clean base offsets that are exact multiples of their respective modulo counts
  const int monthBase = 12000; // divisible by 12
  const int dayBase = 12400;   // divisible by 31
  const int yearBase = 12120;  // divisible by 101

  final monthController = FixedExtentScrollController(
    initialItem: monthBase + (tempMonth - 1),
  );
  final dayController = FixedExtentScrollController(
    initialItem: dayBase + (tempDay - 1),
  );
  final yearController = FixedExtentScrollController(
    initialItem: yearBase + years.indexOf(tempYear),
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
          void updateSelectedDate() {
            final maxDays = DateUtils.getDaysInMonth(tempYear, tempMonth);
            final clampedDay = tempDay.clamp(1, maxDays);
            setState(() {
              selectedDate = DateTime(tempYear, tempMonth, clampedDay);
            });
          }

          Widget buildWheel({
            required FixedExtentScrollController controller,
            required int moduloCount,
            required int currentSelectedValue,
            required String Function(int) labelBuilder,
            required ValueChanged<int> onSelectedItemChanged,
          }) {
            return ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 42,
              perspective: 0.0001,
              diameterRatio: 30,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onSelectedItemChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: null,
                builder: (context, index) {
                  final itemVal = ((index % moduloCount) + moduloCount) % moduloCount;
                  final isSelected = itemVal == currentSelectedValue;

                  return Center(
                    child: Text(
                      labelBuilder(index),
                      style: TextStyle(
                        fontSize: isSelected ? 18 : 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: colors.textPrimary.withOpacity(isSelected ? 1.0 : 0.35),
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
                          Expanded(
                            flex: 3,
                            child: buildWheel(
                              controller: monthController,
                              moduloCount: 12,
                              currentSelectedValue: tempMonth - 1,
                              labelBuilder: (i) => months[((i % 12) + 12) % 12],
                              onSelectedItemChanged: (index) {
                                setModalState(() {
                                  tempMonth = (((index % 12) + 12) % 12) + 1;
                                });
                                updateSelectedDate();
                              },
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: buildWheel(
                              controller: dayController,
                              moduloCount: 31,
                              currentSelectedValue: tempDay - 1,
                              labelBuilder: (i) => "${(((i % 31) + 31) % 31) + 1}",
                              onSelectedItemChanged: (index) {
                                setModalState(() {
                                  tempDay = (((index % 31) + 31) % 31) + 1;
                                });
                                updateSelectedDate();
                              },
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: buildWheel(
                              controller: yearController,
                              moduloCount: years.length,
                              currentSelectedValue: years.indexOf(tempYear),
                              labelBuilder: (i) => "${years[((i % years.length) + years.length) % years.length]}",
                              onSelectedItemChanged: (index) {
                                setModalState(() {
                                  tempYear = years[((index % years.length) + years.length) % years.length];
                                });
                                updateSelectedDate();
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
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            widget.transaction == null ? "Add Transaction" : "Edit Transaction",
            style: TextStyle(color: colors.textPrimary),
          ),
          actions: [
            if (widget.transaction != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: colors.expense),
                tooltip: 'Delete',
                onPressed: _confirmDelete,
              ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets
              .zero, // or EdgeInsets.symmetric(vertical: 20) if you only want vertical space
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 46,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
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
              const SizedBox(height: 25),
              TransactionOptionTile(
                icon: Icons.category,
                title: "Category",
                value: selectedCategory,
                onTap: () {
                  if (categories.isEmpty) return;
                  showPicker(categories.map((c) => c.name).toList(), (value) {
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
                  });
                },
              ),
              TransactionOptionTile(
                icon: Icons.list,
                title: "Subcategory",
                value: selectedSubcategory,
                onTap: () {
                  final currentCategory = categories.firstWhere(
                    (c) => c.name == selectedCategory,
                    orElse: () => categories.isNotEmpty
                        ? categories.first
                        : CategoryModel(name: '', subcategories: ['Other']),
                  );

                  showPicker(currentCategory.subcategories, (value) {
                    setState(() {
                      selectedSubcategory = value;
                    });
                  });
                },
              ),
              TransactionOptionTile(
                icon: Icons.payment,
                title: "Payment",
                value: paymentMethod,
                onTap: () {
                  showPicker(
                    ["cash", "credit_card", "debit_card", "upi", "bank"],
                    (value) {
                      setState(() {
                        paymentMethod = value;
                      });
                    },
                  );
                },
              ),
              TransactionOptionTile(
                icon: Icons.person,
                title: "Profile",
                value: profileType,
                onTap: () {
                  showPicker(["personal", "business"], (value) {
                    setState(() {
                      profileType = value;
                    });
                  });
                },
              ),
              TransactionOptionTile(
                icon: Icons.calendar_month,
                title: "Date",
                value:
                    "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                onTap: selectDate,
              ),
              TransactionOptionTile(
                icon: Icons.attach_file,
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
                icon: Icons.store,
              ),
              customInput(
                controller: paymentNameController,
                hint: "Payment name",
                icon: Icons.account_balance_wallet,
              ),
              customInput(
                controller: noteController,
                hint: "Note",
                icon: Icons.notes,
              ),
              const SizedBox(height: 25),
              Center(
                child: SizedBox(
                  width: 100, // 👈 Matches the top buttons exact width
                  child: GestureDetector(
                    onTap: saveTransaction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: colors.purple,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Center(
                        child: Text(
                          "SAVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30), // 👈 Add this below the Save button
            ],
          ),
        ),
      ), // 👈 Closes Scaffold
    ); // 👈 Closes PopScope
  }

  Widget typeButton(String type) {
    final selected = transactionType == type;
    final colors = context.colors;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            transactionType = type;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? colors.purple : colors.card,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              type.toUpperCase(),
              style: TextStyle(
                color: selected ? Colors.white : colors.textSecondary,
                fontWeight: FontWeight.bold,
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
    required IconData icon,
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.iconCircle,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.textPrimary, size: 20),
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

  void showPicker(List<String> items, Function(String) selected) {
    final colors = context.colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SizedBox(
          height: 380, // 👈 Fixed height
          width: double.infinity, // 👈 Explicit full screen width
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Top Drag Handle
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
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    color: colors.textSecondary.withOpacity(0.08),
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      title: Text(
                        item.replaceAll("_", " "),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // 👈 trailing icon removed here
                      onTap: () {
                        selected(item);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
