import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/transaction.dart';
import '../models/spending_query_models.dart';
import '../models/message.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:io';

class GeminiService {
  final String apiKey;

  GeminiService({required this.apiKey});

  // Reusable schema definition
  static final Schema _responseSchema = Schema.object(
    properties: {
      'message': Schema.string(
        description: 'A brief, conversational acknowledgement or reply.',
      ),
      'action_type': Schema.string(
        description: 'Must be one of: QUERY, ADD_DRAFT, NONE',
      ),
      'query_intent': Schema.object(
        nullable: true,
        properties: {
          'intent_type': Schema.string(
            description:
                'One of: spending_summary, period_overview, top_categories, top_merchants, list_transactions, unknown',
          ),
          'keywords': Schema.array(
            items: Schema.string(),
            description: 'Search items/subjects. Exclude action verbs.',
          ),
          'start_date': Schema.string(
            nullable: true,
            description: 'YYYY-MM-DD',
          ),
          'end_date': Schema.string(
            nullable: true,
            description: 'YYYY-MM-DD',
          ),
          'transaction_type': Schema.string(
            nullable: true,
            description: 'expense or income',
          ),
          'profile_type': Schema.string(
            nullable: true,
            description: 'Personal or Business',
          ),
          'payment_method': Schema.string(nullable: true),
          'min_amount': Schema.number(nullable: true),
          'max_amount': Schema.number(nullable: true),
          'limit': Schema.integer(nullable: true),
        },
      ),
      'draft_transaction': Schema.object(
        nullable: true,
        properties: {
          'amount': Schema.number(description: 'Numeric amount only.'),
          'currency': Schema.string(
            description:
                '3-letter currency code: USD, INR, EUR, GBP, AED, CAD, AUD.',
          ),
          'transaction_type': Schema.string(
            description: 'expense, income, or transfer',
          ),
          'profile_type': Schema.string(
            description: 'Personal or Business',
          ),
          'category': Schema.string(
            nullable: true,
            description: 'e.g., Food, Travel, Shopping, Bills, Entertainment.',
          ),
          'subcategory': Schema.string(
            nullable: true,
            description: 'e.g., Restaurant, Coffee, Groceries, Flight, Taxi.',
          ),
          'merchant': Schema.string(
            nullable: true,
            description: 'Vendor or shop name (e.g. Starbucks, Uber).',
          ),
          'payment_method': Schema.string(
            nullable: true,
            description: 'Cash, Credit Card, Debit Card, UPI, or Bank.',
          ),
          'payment_name': Schema.string(nullable: true),
          'note': Schema.string(nullable: true),
          'date': Schema.string(
            description: 'Date in YYYY-MM-DD format.',
          ),
        },
      ),
    },
    requiredProperties: ['message', 'action_type'],
  );

  GenerativeModel _getModel() {
    final now = DateTime.now();
    final today =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _responseSchema,
      ),
      systemInstruction: Content.system('''
You are Expilio, a personal finance assistant.
Today's Date: $today (${now.year}).

DECISION RULES:
1. "action_type": Must be strictly one of ["QUERY", "ADD_DRAFT", "NONE"].
2. "ADD_DRAFT": Choose when the user records spending, buying, earning, or receiving money (e.g., "I spent \$10 on coffee today at Starbucks").
   - Extract: amount, currency (default "USD" unless specified), merchant ("Starbucks"), category ("Food"), subcategory ("Coffee"), payment_method (if mentioned, else "Cash"), and note.
   - Resolve relative dates ("today", "yesterday", "last Friday") into exact YYYY-MM-DD dates using Today's Date.
   - Set "query_intent" to null.
3. "QUERY": Choose when the user asks questions about their existing transactions, totals, or history (e.g., "How much did I spend on coffee in May?").
   - Extract keywords and date ranges into "query_intent".
   - "intent_type" must be strictly one of: ["spending_summary", "period_overview", "top_categories", "top_merchants", "list_transactions", "unknown"].
   - Set "draft_transaction" to null.
4. "NONE": Choose for casual conversation or non-transaction advice. Set both nested objects to null.
5. "IMAGE / RECEIPT ATTACHED": If an image/document is provided, treat it as a receipt or bill. Extract the total amount, merchant/store name, transaction date, and likely category into "ADD_DRAFT".
'''),
    );
  }

  Future<GeminiChatResult> processMessage(
    String prompt, {
    List<MessageModel> history = const [],
    Uint8List? attachmentBytes,
    String? attachmentMimeType,
  }) async {
    try {
      // 1. Sliding window: keep only the last 6 messages (3 turns of conversation)
      const int contextLimit = 6;
      final recentHistory = history.length > contextLimit
          ? history.sublist(history.length - contextLimit)
          : history;

      // 2. Convert and sanitize history to enforce strict user/model alternation
      final List<Content> contents = [];
      String? lastRole;

      for (final msg in recentHistory) {
        if (msg.message.trim().isEmpty ||
            msg.message.toLowerCase().contains("sorry, i ran into an error")) {
          continue;
        }

        final role = (msg.role == 'user') ? 'user' : 'model';

        // Discard consecutive identical roles to guarantee strict alternating turns
        if (role == lastRole) {
          continue;
        }

        contents.add(Content(role, [TextPart(msg.message)]));
        lastRole = role;
      }

      // 3. Ensure history does NOT end with a 'user' role before appending prompt
      if (contents.isNotEmpty && contents.last.role == 'user') {
        contents.removeLast();
      }

      // 4. Append current user prompt (supports multimodal image input)
      final List<Part> userParts = [];

      if (attachmentBytes != null &&
          attachmentMimeType != null &&
          attachmentBytes.isNotEmpty) {
        userParts.add(DataPart(attachmentMimeType, attachmentBytes));
      }

      final effectivePrompt = prompt.trim().isNotEmpty
          ? prompt.trim()
          : "Scan this receipt and log the transaction.";
      userParts.add(TextPart(effectivePrompt));

      contents.add(Content.multi(userParts));

      // 5. Send to model generated with current date
      final model = _getModel();
      final response = await model.generateContent(contents);
      final rawText = response.text;

      if (rawText == null || rawText.trim().isEmpty) {
        return GeminiChatResult(
          message: "I couldn't process that. Please try again.",
          actionType: AiActionType.none,
        );
      }

      final Map<String, dynamic> json = jsonDecode(rawText);
      final rawAction = json['action_type'] as String? ?? 'NONE';
      final message = json['message'] as String? ?? '';

      if (rawAction == 'ADD_DRAFT' && json['draft_transaction'] != null) {
        final draftMap = Map<String, dynamic>.from(json['draft_transaction']);
        final now = DateTime.now();

        DateTime parsedDate = now;
        if (draftMap['date'] != null &&
            (draftMap['date'] as String).trim().isNotEmpty) {
          final d = DateTime.tryParse(draftMap['date']);
          if (d != null) parsedDate = d;
        }

        final rawAmount = (draftMap['amount'] as num?)?.toDouble() ?? 0.0;
        final currency = draftMap['currency'] as String? ?? 'USD';

        final draft = TransactionModel(
          userId: 'local_user',
          amount: rawAmount,
          currency: currency,
          exchangeRate: 1.0,
          baseAmount: rawAmount,
          transactionType:
              (draftMap['transaction_type'] as String?)?.toLowerCase() ??
                  'expense',
          profileType: draftMap['profile_type'] as String? ?? 'Personal',
          category: draftMap['category'] as String? ?? 'Food',
          subCategory: draftMap['subcategory'] as String? ?? 'Coffee',
          merchant: draftMap['merchant'] as String?,
          paymentMethod: draftMap['payment_method'] as String? ?? 'Cash',
          paymentName: draftMap['payment_name'] as String?,
          note:
              draftMap['note'] as String? ?? draftMap['subcategory'] as String?,
          date: parsedDate,
          source: 'chat',
          createdAt: now,
          updatedAt: now,
        );

        return GeminiChatResult(
          message: message.isNotEmpty ? message : "Opening transaction form...",
          actionType: AiActionType.addDraft,
          draftTransaction: draft,
        );
      }

      if (rawAction == 'QUERY' && json['query_intent'] != null) {
        final intentMap = Map<String, dynamic>.from(json['query_intent']);
        intentMap['intent'] = intentMap['intent_type'];

        return GeminiChatResult(
          message: message,
          actionType: AiActionType.query,
          queryIntent: SpendingQueryIntent.fromJson(intentMap),
        );
      }

      return GeminiChatResult(
        message: message,
        actionType: AiActionType.none,
      );
    } catch (e, stack) {
      debugPrint("💥 REAL GEMINI EXCEPTION: $e");
      debugPrint("💥 STACK: $stack");
      return GeminiChatResult(
        message: "Sorry, I ran into an error processing that.",
        actionType: AiActionType.none,
      );
    }
  }
}