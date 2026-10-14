import 'dart:convert';
import '../database/database_helper.dart';
import '../models/message.dart';
import '../models/transaction.dart';
import '../models/spending_query_models.dart';
import 'gemini_services.dart';
import 'spending_query_service.dart';
import 'preference_service.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/attachment.dart';

class ChatActionResult {
  final TransactionModel? draftTransaction;
  final List<TransactionModel>? matchedTransactions;

  ChatActionResult({
    this.draftTransaction,
    this.matchedTransactions,
  });
}

class ChatService {
  final DatabaseHelper _database = DatabaseHelper.instance;

  // Insert your Gemini API key here
  final GeminiService _geminiService = GeminiService(
    apiKey: 'AQ.Ab8RN6KtXIEP221HV9-P9It3bBPky2P8fijpksUQaMSfiz6MnQ',
  );

  Future<List<MessageModel>> getMessages() async {
    return await _database.getMessages();
  }

  Future<ChatActionResult?> sendMessage(
    String text, {
    int? existingFailedMessageId,
    AttachmentModel? attachment,
  }) async {
    final now = DateTime.now();
    late final int activeUserMessageId;

    // 1. If retrying a previously failed message, reset its status to 'sent'
    if (existingFailedMessageId != null) {
      activeUserMessageId = existingFailedMessageId;
      final db = await _database.database;
      await db.update(
        'messages',
        {
          'metadata': jsonEncode({
            'transaction_ids': <int>[],
            'status': 'sent',
          }),
        },
        where: 'id = ?',
        whereArgs: [activeUserMessageId],
      );
    } else {
      // 2. Otherwise insert fresh message with status 'sent'
      final userMessage = MessageModel(
        role: "user",
        message: text,
        createdAt: now,
        status: 'sent',
      );
      activeUserMessageId = await _database.insertMessage(userMessage);
    }

    try {
      // Read attachment bytes if an attachment is provided
      // Read attachment bytes if an attachment is provided
      Uint8List? attachmentBytes;
      String? mimeType;
      final path = attachment?.localPath;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          attachmentBytes = await file.readAsBytes();
          final type = attachment?.fileType;
          mimeType = (type != null && type.isNotEmpty) ? type : 'image/jpeg';
        }
      }

      // 3. Fetch history, filtering out other failed messages and current prompt
      final existingMessages = await _database.getMessages();
      final validHistory = existingMessages
          .where((m) => m.status != 'failed' && m.id != activeUserMessageId)
          .toList();

      // 4. Call Gemini with history and optional attachment
      final aiResult = await _geminiService.processMessage(
        text,
        history: validHistory,
        attachmentBytes: attachmentBytes,
        attachmentMimeType: mimeType,
      );

      // Stop and throw if Gemini returned a fallback error message
      if (aiResult.message.toLowerCase().contains("sorry, i ran into an error")) {
        throw Exception("Gemini processing failed");
      }

      String assistantReply = aiResult.message;
      TransactionModel? draftToOpen;
      List<TransactionModel>? matchedTransactions;

      try {
        // 5. Handle ADD_DRAFT (User logs an expense/income)
        if (aiResult.actionType == AiActionType.addDraft &&
            aiResult.draftTransaction != null) {
          draftToOpen = aiResult.draftTransaction;
        }
        // 6. Handle QUERY (User asks questions about spending/income)
        else if (aiResult.actionType == AiActionType.query &&
            aiResult.queryIntent != null) {
          final db = await _database.database;
          final spendingService = SpendingQueryService(db);
          final dynamic queryOutput = await spendingService.executeIntent(
            aiResult.queryIntent!,
            includeTransactions: true,
          );

          final String symbol = await PreferencesService.getBaseCurrencySymbol();

          if (queryOutput is SpendingSummary) {
            final countText =
                queryOutput.transactionCount == 1 ? "entry" : "entries";
            assistantReply =
                "$assistantReply\n\nTotal: $symbol${queryOutput.totalAmount.toStringAsFixed(2)} across ${queryOutput.transactionCount} $countText.";
            matchedTransactions = queryOutput.transactions;
          } else if (queryOutput is CashFlowSummary) {
            assistantReply =
                "$assistantReply\n\n• Income: $symbol${queryOutput.totalIncome.toStringAsFixed(2)}\n• Expense: $symbol${queryOutput.totalExpense.toStringAsFixed(2)}\n• Net Savings: $symbol${queryOutput.netSavings.toStringAsFixed(2)}";
          } else if (queryOutput is List<CategoryBreakdown>) {
            if (queryOutput.isEmpty) {
              assistantReply =
                  "$assistantReply\n\nNo spending found in that period.";
            } else {
              final lines = queryOutput
                  .map((c) =>
                      "• ${c.category}: $symbol${c.total.toStringAsFixed(2)} (${c.count})")
                  .join("\n");
              assistantReply = "$assistantReply\n\n$lines";
            }
          } else if (queryOutput is List<MerchantBreakdown>) {
            if (queryOutput.isEmpty) {
              assistantReply =
                  "$assistantReply\n\nNo merchant spending recorded for that period.";
            } else {
              final lines = queryOutput
                  .map((m) =>
                      "• ${m.merchant}: $symbol${m.total.toStringAsFixed(2)} (${m.count})")
                  .join("\n");
              assistantReply = "$assistantReply\n\n$lines";
            }
          }
        }
      } catch (e) {
        assistantReply =
            "Found the information, but encountered an issue retrieving the local data.";
      }

      // Extract valid integer IDs from matched transactions
      final List<int> matchedIds = matchedTransactions != null
          ? matchedTransactions
              .map((t) => t.id)
              .whereType<int>()
              .toList()
          : [];

      // 7. Save assistant message (also handles the ADD_DRAFT message case)
      final assistantMessage = MessageModel(
        role: "assistant",
        message: assistantReply,
        createdAt: DateTime.now(),
        transactionIds: matchedIds,
        status: 'sent',
      );
      await _database.insertMessage(assistantMessage);

      // 8. Return results
      return ChatActionResult(
        draftTransaction: draftToOpen,
        matchedTransactions: matchedTransactions,
      );
    } catch (e) {
      // 9. If anything fails, persist 'failed' status to metadata in SQLite
      final db = await _database.database;
      await db.update(
        'messages',
        {
          'metadata': jsonEncode({
            'transaction_ids': <int>[],
            'status': 'failed',
          }),
        },
        where: 'id = ?',
        whereArgs: [activeUserMessageId],
      );
      rethrow;
    }
  }



}