import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import 'ai_service.dart';

/// OpenAI ChatGPT Service Implementation
class OpenAIService implements AIService {
  String _apiKey = '';
  String _modelId = AppConstants.defaultOpenAIModel;

  OpenAIService({String? apiKey, String? modelId}) {
    if (apiKey != null) _apiKey = apiKey;
    if (modelId != null) _modelId = modelId;
  }

  @override
  AIProvider get provider => AIProvider.openai;

  @override
  String get providerName => 'ChatGPT';

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
    return AIProvider.openai.availableModels;
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
      throw Exception('OpenAI API key not set');
    }

    final url = Uri.parse('${AppConstants.openAIBaseUrl}/chat/completions');
    final messages = _buildMessages(message, history, systemPrompt);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? 'OpenAI API error');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List<dynamic>;
    
    if (choices.isEmpty) {
      throw Exception('No response from OpenAI');
    }

    return choices[0]['message']['content'] ?? '';
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
      throw Exception('OpenAI API key not set');
    }

    final url = Uri.parse('${AppConstants.openAIBaseUrl}/chat/completions');
    final messages = _buildMessages(message, history, systemPrompt);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
    });

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.body = body;

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      throw Exception('OpenAI streaming error: ${streamedResponse.statusCode}');
    }

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6).trim();
          if (jsonStr == '[DONE]') continue;
          if (jsonStr.isEmpty) continue;
          
          try {
            final data = jsonDecode(jsonStr);
            final choices = data['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (e) {
            // Skip malformed JSON
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _buildMessages(
    String message,
    List<ChatMessage> history,
    String? systemPrompt,
  ) {
    final messages = <Map<String, dynamic>>[];

    // Add system prompt
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }

    // Add conversation history
    for (final msg in history) {
      String role;
      switch (msg.role) {
        case MessageRole.user:
          role = 'user';
          break;
        case MessageRole.assistant:
          role = 'assistant';
          break;
        case MessageRole.system:
          role = 'system';
          break;
      }
      messages.add({
        'role': role,
        'content': msg.content,
      });
    }

    // Add current message
    messages.add({
      'role': 'user',
      'content': message,
    });

    return messages;
  }
}
