import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    debugPrint('[OpenAI] sendMessage called');
    debugPrint('[OpenAI] Model: $_modelId');
    debugPrint('[OpenAI] Message length: ${message.length}');
    debugPrint('[OpenAI] History count: ${history.length}');

    if (_apiKey.isEmpty) {
      debugPrint('[OpenAI] ERROR: API key not set');
      throw Exception('OpenAI API key not set');
    }

    final url = Uri.parse('${AppConstants.openAIBaseUrl}/chat/completions');
    debugPrint('[OpenAI] URL: $url');
    final messages = _buildMessages(message, history, systemPrompt);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    debugPrint('[OpenAI] Sending request...');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    );
    debugPrint('[OpenAI] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      debugPrint('[OpenAI] ERROR: ${response.body}');
      throw Exception(error['error']?['message'] ?? 'OpenAI API error');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List<dynamic>;
    debugPrint('[OpenAI] Choices count: ${choices.length}');

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
    debugPrint('[OpenAI] sendMessageStream called');
    debugPrint(
      '[OpenAI] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );

    if (_apiKey.isEmpty) {
      debugPrint('[OpenAI] ERROR: API key not set');
      throw Exception('OpenAI API key not set');
    }

    final url = Uri.parse('${AppConstants.openAIBaseUrl}/chat/completions');
    debugPrint('[OpenAI] Stream URL: $url');
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

    debugPrint('[OpenAI] Sending stream request...');
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      debugPrint(
        '[OpenAI] Stream response status: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('[OpenAI] Stream ERROR: ${streamedResponse.statusCode}');
        throw Exception(
          'OpenAI streaming error: ${streamedResponse.statusCode}',
        );
      }

      int chunkCount = 0;
      String buffer = ''; // Buffer for incomplete SSE lines

      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        // Append new data to buffer
        buffer += chunk;

        // Process complete lines from buffer
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);

          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr == '[DONE]') {
              debugPrint('[OpenAI] Stream complete. Total chunks: $chunkCount');
              continue;
            }
            if (jsonStr.isEmpty) continue;

            try {
              final data = jsonDecode(jsonStr);
              final choices = data['choices'] as List<dynamic>?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'];
                final content = delta?['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  chunkCount++;
                  if (chunkCount <= 3) {
                    debugPrint('[OpenAI] Chunk $chunkCount received');
                  }
                  yield content;
                }
              }
            } catch (e) {
              debugPrint('[OpenAI] JSON parse error: $e');
            }
          }
        }
      }
      debugPrint('[OpenAI] Stream finished. Total chunks: $chunkCount');
    } finally {
      client.close();
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
      messages.add({'role': 'system', 'content': systemPrompt});
    }

    // Add conversation history
    for (final msg in history) {
      // Skip error messages and empty content
      if (msg.error != null || msg.content.trim().isEmpty) continue;
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
      messages.add({'role': role, 'content': msg.content});
    }

    // Add current message
    messages.add({'role': 'user', 'content': message});

    return messages;
  }
}
