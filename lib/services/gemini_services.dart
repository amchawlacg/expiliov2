import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/ai_response.dart';

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system('''
You are Expilio, a personal finance assistant.
Always return JSON:
{
  "message": "Conversational reply or advice",
  "action": {
    "type": "ADD_TRANSACTION" | "QUERY_TOTAL" | "LIST_TRANSACTIONS",
    "category": string or null,
    "amount": number or null,
    "date_range": "today" | "yesterday" | "this_month" | "last_month" | null
  } or null
}
If the user asks casual questions or advice, set action to null.
'''),
    );
  }

  Future<AiResponse> processMessage(String prompt) async {
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final rawText = response.text ?? '{}';
      final Map<String, dynamic> jsonMap = jsonDecode(rawText);
      return AiResponse.fromJson(jsonMap);
    } catch (e) {
      return AiResponse(
        message: "Sorry, I had trouble processing that. Please try again.",
        action: null,
      );
    }
  }
}