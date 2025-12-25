import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    debugPrint('[Ollama] getAvailableModels called');
    debugPrint('[Ollama] Base URL: $_baseUrl');
    try {
      final url = Uri.parse('$_baseUrl/api/tags');
      final response = await http.get(url);
      debugPrint('[Ollama] Models response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('[Ollama] Failed to get models, using defaults');
        return AIProvider.ollama.availableModels;
      }

      final data = jsonDecode(response.body);
      final models = data['models'] as List<dynamic>?;
      debugPrint('[Ollama] Found ${models?.length ?? 0} models');

      if (models == null || models.isEmpty) {
        return AIProvider.ollama.availableModels;
      }

      final modelNames = models.map((m) => m['name'] as String).toList();
      debugPrint('[Ollama] Available models: $modelNames');
      return modelNames;
    } catch (e) {
      debugPrint('[Ollama] Error getting models: $e');
      return AIProvider.ollama.availableModels;
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$_baseUrl/api/tags');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
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
    debugPrint('[Ollama] sendMessage called');
    debugPrint('[Ollama] Model: $_modelId, Base URL: $_baseUrl');
    debugPrint('[Ollama] Message length: ${message.length}');
    debugPrint('[Ollama] History count: ${history.length}');

    final url = Uri.parse('$_baseUrl/api/chat');
    debugPrint('[Ollama] URL: $url');
    final messages = _buildMessages(message, history, systemPrompt);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'stream': false,
      'options': {'temperature': temperature, 'num_predict': maxTokens},
    });

    debugPrint('[Ollama] Sending request...');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    debugPrint('[Ollama] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('[Ollama] ERROR: ${response.body}');
      throw Exception('Ollama API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final content = data['message']?['content'] ?? '';
    debugPrint('[Ollama] Response length: ${content.length}');
    return content;
  }

  @override
  Stream<String> sendMessageStream(
    String message,
    List<ChatMessage> history, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    debugPrint('[Ollama] sendMessageStream called');
    debugPrint(
      '[Ollama] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );

    final url = Uri.parse('$_baseUrl/api/chat');
    debugPrint('[Ollama] Stream URL: $url');
    final messages = _buildMessages(message, history, systemPrompt);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'stream': true,
      'options': {'temperature': temperature, 'num_predict': maxTokens},
    });

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = body;

    debugPrint('[Ollama] Sending stream request...');
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      debugPrint(
        '[Ollama] Stream response status: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('[Ollama] Stream ERROR: ${streamedResponse.statusCode}');
        throw Exception(
          'Ollama streaming error: ${streamedResponse.statusCode}',
        );
      }

      int chunkCount = 0;
      String buffer = ''; // Buffer for incomplete lines

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

          if (line.isEmpty) continue;

          try {
            final data = jsonDecode(line);
            final content = data['message']?['content'] as String?;
            final done = data['done'] as bool? ?? false;
            if (content != null && content.isNotEmpty) {
              chunkCount++;
              if (chunkCount <= 3) {
                debugPrint('[Ollama] Chunk $chunkCount received');
              }
              yield content;
            }
            if (done) {
              debugPrint('[Ollama] Stream complete. Total chunks: $chunkCount');
            }
          } catch (e) {
            debugPrint('[Ollama] JSON parse error for line: $line');
            debugPrint('[Ollama] Error: $e');
          }
        }
      }

      // Process any remaining data in buffer
      if (buffer.trim().isNotEmpty) {
        try {
          final data = jsonDecode(buffer.trim());
          final content = data['message']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            chunkCount++;
            debugPrint('[Ollama] Final buffer chunk received');
            yield content;
          }
        } catch (e) {
          debugPrint('[Ollama] JSON parse error for final buffer: $e');
        }
      }

      debugPrint('[Ollama] Stream finished. Total chunks: $chunkCount');
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
