import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import 'ai_service.dart';

/// Ollama Local AI Service Implementation
class OllamaService implements AIService {
  String _baseUrl = AppConstants.ollamaDefaultUrl;
  String _modelId = AppConstants.defaultOllamaModel;

  OllamaService({String? baseUrl, String? modelId}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (modelId != null) _modelId = modelId;
  }

  @override
  AIProvider get provider => AIProvider.ollama;

  @override
  String get providerName => 'Ollama';

  @override
  String get modelId => _modelId;

  @override
  void setModel(String modelId) {
    _modelId = modelId;
  }

  @override
  void setApiKey(String apiKey) {
    // Ollama uses URL instead of API key
    _baseUrl = apiKey.isNotEmpty ? apiKey : AppConstants.ollamaDefaultUrl;
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  @override
  Future<List<String>> getAvailableModels() async {
    try {
      final url = Uri.parse('$_baseUrl/api/tags');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return AIProvider.ollama.availableModels;
      }

      final data = jsonDecode(response.body);
      final models = data['models'] as List<dynamic>?;
      
      if (models == null || models.isEmpty) {
        return AIProvider.ollama.availableModels;
      }

      return models.map((m) => m['name'] as String).toList();
    } catch (e) {
      return AIProvider.ollama.availableModels;
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$_baseUrl/api/tags');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
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
    final url = Uri.parse('$_baseUrl/api/chat');
    final messages = _buildMessages(message, history, systemPrompt);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'stream': false,
      'options': {
        'temperature': temperature,
        'num_predict': maxTokens,
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Ollama API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['message']?['content'] ?? '';
  }

  @override
  Stream<String> sendMessageStream(
    String message,
    List<ChatMessage> history, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    final url = Uri.parse('$_baseUrl/api/chat');
    final messages = _buildMessages(message, history, systemPrompt);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'stream': true,
      'options': {
        'temperature': temperature,
        'num_predict': maxTokens,
      },
    });

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = body;

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      throw Exception('Ollama streaming error: ${streamedResponse.statusCode}');
    }

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          final data = jsonDecode(line);
          final content = data['message']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (e) {
          // Skip malformed JSON
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
