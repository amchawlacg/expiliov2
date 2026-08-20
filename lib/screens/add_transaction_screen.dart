import 'dart:io';

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

  String selectedCategory = "Food";
  String selectedSubcategory = "Restaurant";
  String transactionType = "expense";
  String profileType = "personal";
  String paymentMethod = "cash";

  DateTime selectedDate = DateTime.now();
  File? selectedInvoice;
  List<AttachmentModel> attachments = [];

  final transactionService = TransactionService();
  final attachmentService = AttachmentService();

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
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> pickInvoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

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

    final amount = double.tryParse(
      amountController.text.trim(),
    );

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
    appLog('🟢 [UI] Transaction & attachments saved. Triggering SyncService...');
    SyncService().processSyncQueue();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(
          color: colors.textPrimary,
        ),
        title: Text(
          widget.transaction == null ? "Add Transaction" : "Edit Transaction",
          style: TextStyle(
            color: colors.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 430,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    prefixText: "₹ ",
                    prefixStyle: TextStyle(
                      color: colors.textPrimary,
                    ),
                    hintText: "0",
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    typeButton("expense"),
                    typeButton("income"),
                    typeButton("transfer"),
                  ],
                ),
                const SizedBox(height: 25),
                TransactionOptionTile(
                  icon: Icons.category,
                  title: "Category",
                  value: selectedCategory,
                  onTap: () {
                    showPicker(
                      ExpenseCategories.categories.keys.toList(),
                      (value) {
                        setState(() {
                          selectedCategory = value;
                          selectedSubcategory =
                              ExpenseCategories.categories[value]!.first;
                        });
                      },
                    );
                  },
                ),
                TransactionOptionTile(
                  icon: Icons.list,
                  title: "Subcategory",
                  value: selectedSubcategory,
                  onTap: () {
                    showPicker(
                      ExpenseCategories.categories[selectedCategory]!,
                      (value) {
                        setState(() {
                          selectedSubcategory = value;
                        });
                      },
                    );
                  },
                ),
                TransactionOptionTile(
                  icon: Icons.payment,
                  title: "Payment",
                  value: paymentMethod,
                  onTap: () {
                    showPicker(
                      [
                        "cash",
                        "credit_card",
                        "debit_card",
                        "upi",
                        "bank",
                      ],
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
                    showPicker(
                      [
                        "personal",
                        "business",
                      ],
                      (value) {
                        setState(() {
                          profileType = value;
                        });
                      },
                    );
                  },
                ),
                TransactionOptionTile(
                  icon: Icons.calendar_month,
                  title: "Date",
                  value: "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
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
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: saveTransaction,
                    child: const Text(
                      "Save Transaction",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4, // Keeps text perfectly centered with the circular icon
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: colors.textPrimary, // Forces white text on user input
          fontSize: 16,                 // Matches the Option Tile size exactly
          fontWeight: FontWeight.w600, // Matches the Option Tile thickness exactly
        ),
        decoration: InputDecoration(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black, // Pure black circle backdrop
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white, // Pure white icon color
              size: 20,
            ),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: colors.textHint, // Keeps your soft placeholder color when empty
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
  Function(String) selected,
) {
  final colors = context.colors; // 👈 1. Get colors from context

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 430,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.textSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                ...items.map((item) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      selected(item);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.replaceAll("_", " "),
                              style: TextStyle( // 👈 2. Removed const
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon( // 👈 3. Removed const
                            Icons.chevron_right,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}