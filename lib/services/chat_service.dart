import '../database/database_helper.dart';
import '../models/message.dart';
import '../models/transaction.dart';
import '../models/spending_query_models.dart';
import 'gemini_services.dart';
import 'spending_query_service.dart';

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

Future<ChatActionResult?> sendMessage(String text) async {
    final now = DateTime.now();

    // 1. Fetch current conversation history
    final existingMessages = await _database.getMessages();

    // 2. Call Gemini with history
    final aiResult = await _geminiService.processMessage(
      text,
      history: existingMessages,
    );

    // Stop and throw if Gemini returned a fallback error message
    if (aiResult.message.toLowerCase().contains("sorry, i ran into an error")) {
      throw Exception("Gemini processing failed");
    }

    // 2. Only save user message to SQLite AFTER confirming Gemini succeeded
    final userMessage = MessageModel(
      role: "user",
      message: text,
      createdAt: now,
    );
    await _database.insertMessage(userMessage);

    String assistantReply = aiResult.message;
    TransactionModel? draftToOpen;
    List<TransactionModel>? matchedTransactions;

    try {
      // 3. Handle ADD_DRAFT (User logs an expense/income)
      if (aiResult.actionType == AiActionType.addDraft &&
          aiResult.draftTransaction != null) {
        return ChatActionResult(
          draftTransaction: aiResult.draftTransaction,
          matchedTransactions: null,
        );
      }
      // 4. Handle QUERY (User asks questions about spending/income)
      else if (aiResult.actionType == AiActionType.query &&
          aiResult.queryIntent != null) {
        final db = await _database.database;
        final spendingService = SpendingQueryService(db);
        final dynamic queryOutput = await spendingService.executeIntent(
          aiResult.queryIntent!,
          includeTransactions: true,
        );

        if (queryOutput is SpendingSummary) {
          final countText = queryOutput.transactionCount == 1 ? "entry" : "entries";
          assistantReply =
              "$assistantReply\n\nTotal: \$${queryOutput.totalAmount.toStringAsFixed(2)} across ${queryOutput.transactionCount} $countText.";
          // Capture the matched transactions to pass to the UI
          matchedTransactions = queryOutput.transactions;
        } else if (queryOutput is CashFlowSummary) {
          assistantReply =
              "$assistantReply\n\n• Income: \$${queryOutput.totalIncome.toStringAsFixed(2)}\n• Expense: \$${queryOutput.totalExpense.toStringAsFixed(2)}\n• Net Savings: \$${queryOutput.netSavings.toStringAsFixed(2)}";
        } else if (queryOutput is List<CategoryBreakdown>) {
          if (queryOutput.isEmpty) {
            assistantReply = "$assistantReply\n\nNo spending found in that period.";
          } else {
            final lines = queryOutput
                .map((c) => "• ${c.category}: \$${c.total.toStringAsFixed(2)} (${c.count})")
                .join("\n");
            assistantReply = "$assistantReply\n\n$lines";
          }
        } else if (queryOutput is List<MerchantBreakdown>) {
          if (queryOutput.isEmpty) {
            assistantReply = "$assistantReply\n\nNo merchant spending recorded for that period.";
          } else {
            final lines = queryOutput
                .map((m) => "• ${m.merchant}: \$${m.total.toStringAsFixed(2)} (${m.count})")
                .join("\n");
            assistantReply = "$assistantReply\n\n$lines";
          }
        }
      }
    } catch (e) {
      assistantReply = "Found the information, but encountered an issue retrieving the local data.";
    }

    // Extract valid integer IDs from matched transactions
    final List<int> matchedIds = matchedTransactions != null
        ? matchedTransactions
            .map((t) => t.id)
            .whereType<int>()
            .toList()
        : [];

    // 5. Save final assistant response to SQLite with the transaction IDs
    final assistantMessage = MessageModel(
      role: "assistant",
      message: assistantReply,
      createdAt: DateTime.now(),
      transactionIds: matchedIds,
    );
    await _database.insertMessage(assistantMessage);

    // 6. Return the draft and the matched transaction cards for ChatScreen
    return ChatActionResult(
      draftTransaction: draftToOpen,
      matchedTransactions: matchedTransactions,
    );
  }
}