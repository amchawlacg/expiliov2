import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';

class ExportService {
  /// Converts a list of transactions to a CSV file and opens the OS share sheet.
  /// [sourceContext] is needed to properly anchor the share popup on iPad/desktop.
  static Future<bool> exportTransactionsToCsv({
    required List<TransactionModel> transactions,
    required BuildContext context,
    String? customFileNamePrefix,
  }) async {
    if (transactions.isEmpty) return false;

    // 1. Define standard headers
    final List<List<dynamic>> csvRows = [
      [
        "Transaction ID",
        "Date",
        "Type",
        "Profile",
        "Category",
        "Subcategory",
        "Amount",
        "Currency",
        "Exchange Rate",
        "Base Amount (USD)",
        "Merchant",
        "Payment Method",
        "Note",
        "Has Receipt",
        "Receipt File Name",
      ],
    ];

    // 2. Populate transaction rows
    for (final t in transactions) {
      final hasReceipt = t.attachments.isNotEmpty;
      final receiptFileName = hasReceipt
          ? t.attachments.map((a) => a.fileName).join('; ')
          : "None";

      csvRows.add([
        t.id ?? '',
        t.date,
        t.transactionType,
        t.profileType,
        t.category ?? 'Uncategorized',
        t.subCategory ?? '',
        t.amount,
        t.currency,
        t.exchangeRate,
        t.baseAmount,
        t.merchant ?? '',
        t.paymentMethod ?? '',
        t.note ?? '',
        hasReceipt ? 'Yes' : 'No',
        receiptFileName,
      ]);
    }

    // 3. Convert to CSV format
    final String csvContent = const ListToCsvConverter().convert(csvRows);

    // 4. Save to temporary directory
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final prefix = customFileNamePrefix ?? 'expilio_export';
    final filePath = "${tempDir.path}/${prefix}_$dateStr.csv";
    final file = File(filePath);
    await file.writeAsString(csvContent);

    // 5. Trigger native OS share sheet
    final box = context.findRenderObject() as RenderBox?;
    final result = await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/csv')],
      text: "Expilio Export ($dateStr)",
      subject: "Expilio Transaction Records",
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );

    return result.status == ShareResultStatus.success ||
        result.status == ShareResultStatus.dismissed;
  }
}