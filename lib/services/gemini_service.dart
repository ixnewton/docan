import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import 'ai_service.dart';

/// Google Gemini AI Service Implementation
class GeminiService implements AIService {
  String _apiKey = '';
  String _modelId = AppConstants.defaultGeminiModel;

  GeminiService({String? apiKey, String? modelId}) {
    if (apiKey != null) _apiKey = apiKey;
    if (modelId != null) _modelId = modelId;
  }

  @override
  AIProvider get provider => AIProvider.gemini;

  @override
  String get providerName => 'Gemini';

  @override
  String get modelId => _modelId;

  @override
  void setModel(String modelId) {
    _modelId = modelId;
  }

  @override
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  @override
  Future<List<String>> getAvailableModels() async {
    return AIProvider.gemini.availableModels;
  }

  @override
  Future<bool> testConnection() async {
    if (_apiKey.isEmpty) return false;
    
    try {
      final response = await sendMessage('Hello', []);
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key not set');
    }

    final url = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$_modelId:generateContent?key=$_apiKey',
    );

    final contents = _buildContents(message, history, systemPrompt);

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'topP': 0.95,
        'topK': 40,
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? 'Gemini API error');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List<dynamic>?;
    
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    final content = candidates[0]['content'];
    final parts = content['parts'] as List<dynamic>;
    
    return parts.map((p) => p['text'] ?? '').join('');
  }

  @override
  Stream<String> sendMessageStream(
    String message,
    List<ChatMessage> history, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key not set');
    }

    final url = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$_modelId:streamGenerateContent?key=$_apiKey&alt=sse',
    );

    final contents = _buildContents(message, history, systemPrompt);

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'topP': 0.95,
        'topK': 40,
      },
    });

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = body;

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      throw Exception('Gemini streaming error: ${streamedResponse.statusCode}');
    }

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      // Parse SSE data
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          if (jsonStr.trim().isEmpty) continue;
          
          try {
            final data = jsonDecode(jsonStr);
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text'] ?? '';
                if (text.isNotEmpty) {
                  yield text;
                }
              }
            }
          } catch (e) {
            // Skip malformed JSON
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _buildContents(
    String message,
    List<ChatMessage> history,
    String? systemPrompt,
  ) {
    final contents = <Map<String, dynamic>>[];

    // Add system prompt as first user message if provided
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [{'text': 'System: $systemPrompt'}],
      });
      contents.add({
        'role': 'model',
        'parts': [{'text': 'Understood. I will follow these instructions.'}],
      });
    }

    // Add conversation history
    for (final msg in history) {
      if (msg.role == MessageRole.system) continue;
      contents.add({
        'role': msg.role == MessageRole.user ? 'user' : 'model',
        'parts': [{'text': msg.content}],
      });
    }

    // Add current message
    contents.add({
      'role': 'user',
      'parts': [{'text': message}],
    });

    return contents;
  }
}
