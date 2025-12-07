import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import 'ai_service.dart';

/// Anthropic Claude Service Implementation
class ClaudeService implements AIService {
  String _apiKey = '';
  String _modelId = AppConstants.defaultClaudeModel;

  ClaudeService({String? apiKey, String? modelId}) {
    if (apiKey != null) _apiKey = apiKey;
    if (modelId != null) _modelId = modelId;
  }

  @override
  AIProvider get provider => AIProvider.claude;

  @override
  String get providerName => 'Claude';

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
    return AIProvider.claude.availableModels;
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
      throw Exception('Claude API key not set');
    }

    final url = Uri.parse('${AppConstants.claudeBaseUrl}/messages');
    final messages = _buildMessages(message, history);

    final body = <String, dynamic>{
      'model': _modelId,
      'messages': messages,
      'max_tokens': maxTokens,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? 'Claude API error');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List<dynamic>;
    
    if (content.isEmpty) {
      throw Exception('No response from Claude');
    }

    return content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('');
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
      throw Exception('Claude API key not set');
    }

    final url = Uri.parse('${AppConstants.claudeBaseUrl}/messages');
    final messages = _buildMessages(message, history);

    final body = <String, dynamic>{
      'model': _modelId,
      'messages': messages,
      'max_tokens': maxTokens,
      'stream': true,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.headers['x-api-key'] = _apiKey;
    request.headers['anthropic-version'] = '2023-06-01';
    request.body = jsonEncode(body);

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      throw Exception('Claude streaming error: ${streamedResponse.statusCode}');
    }

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6).trim();
          if (jsonStr.isEmpty) continue;
          
          try {
            final data = jsonDecode(jsonStr);
            final type = data['type'] as String?;
            
            if (type == 'content_block_delta') {
              final delta = data['delta'];
              final text = delta?['text'] as String?;
              if (text != null && text.isNotEmpty) {
                yield text;
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
  ) {
    final messages = <Map<String, dynamic>>[];

    // Add conversation history (Claude doesn't support system role in messages)
    for (final msg in history) {
      if (msg.role == MessageRole.system) continue;
      messages.add({
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
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
