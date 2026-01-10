import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import 'ai_service.dart';

/// LM Studio Service Implementation (OpenAI-compatible API)
class LMStudioService implements AIService {
  String _baseUrl = AppConstants.lmStudioDefaultUrl;
  String _modelId = AppConstants.defaultLMStudioModel;

  LMStudioService({String? baseUrl, String? modelId}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (modelId != null) _modelId = modelId;
  }

  @override
  AIProvider get provider => AIProvider.lmstudio;

  @override
  String get providerName => 'LM Studio';

  @override
  String get modelId => _modelId;

  @override
  void setModel(String modelId) {
    _modelId = modelId;
  }

  @override
  void setApiKey(String apiKey) {
    // For LM Studio, apiKey is actually the base URL
    if (apiKey.isNotEmpty) {
      _baseUrl = apiKey;
    }
  }

  /// Set the base URL for LM Studio
  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  @override
  Future<List<String>> getAvailableModels() async {
    try {
      final url = Uri.parse('$_baseUrl/models');
      debugPrint('[LMStudio] Fetching models from: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Connection timed out');
            },
          );

      if (response.statusCode != 200) {
        debugPrint('[LMStudio] Failed to fetch models: ${response.statusCode}');
        return AIProvider.lmstudio.availableModels;
      }

      final data = jsonDecode(response.body);
      final models = data['data'] as List<dynamic>?;

      if (models == null || models.isEmpty) {
        debugPrint('[LMStudio] No models found');
        return AIProvider.lmstudio.availableModels;
      }

      final availableModels = models.map((m) => m['id'] as String).toList()
        ..sort();

      debugPrint('[LMStudio] Found ${availableModels.length} models');
      return availableModels.isEmpty
          ? AIProvider.lmstudio.availableModels
          : availableModels;
    } catch (e) {
      debugPrint('[LMStudio] Error fetching models: $e');
      return AIProvider.lmstudio.availableModels;
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$_baseUrl/models');
      debugPrint('[LMStudio] Testing connection to: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Connection timed out');
            },
          );

      final success = response.statusCode == 200;
      debugPrint(
        '[LMStudio] Connection test: ${success ? 'SUCCESS' : 'FAILED'}',
      );
      return success;
    } catch (e) {
      debugPrint('[LMStudio] Connection test error: $e');
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
    List<Attachment>? attachments,
  }) async {
    debugPrint('[LMStudio] sendMessage called');
    debugPrint('[LMStudio] Model: $_modelId');
    debugPrint('[LMStudio] Base URL: $_baseUrl');
    debugPrint('[LMStudio] Message length: ${message.length}');
    debugPrint('[LMStudio] History count: ${history.length}');
    debugPrint('[LMStudio] Attachments: ${attachments?.length ?? 0}');

    final url = Uri.parse('$_baseUrl/chat/completions');
    debugPrint('[LMStudio] URL: $url');
    final messages = _buildMessages(
      message,
      history,
      systemPrompt,
      attachments: attachments,
    );

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    debugPrint('[LMStudio] Sending request...');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    debugPrint('[LMStudio] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('[LMStudio] ERROR: ${response.body}');
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['error']?['message'] ?? 'LM Studio API error');
      } catch (e) {
        throw Exception('LM Studio API error: ${response.statusCode}');
      }
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List<dynamic>;
    debugPrint('[LMStudio] Choices count: ${choices.length}');

    if (choices.isEmpty) {
      throw Exception('No response from LM Studio');
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
    List<Attachment>? attachments,
  }) async* {
    debugPrint('[LMStudio] sendMessageStream called');
    debugPrint(
      '[LMStudio] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );
    debugPrint('[LMStudio] Attachments: ${attachments?.length ?? 0}');

    final url = Uri.parse('$_baseUrl/chat/completions');
    debugPrint('[LMStudio] Stream URL: $url');
    final messages = _buildMessages(
      message,
      history,
      systemPrompt,
      attachments: attachments,
    );

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
    });

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = body;

    debugPrint('[LMStudio] Sending stream request...');
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      debugPrint(
        '[LMStudio] Stream response status: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('[LMStudio] Stream ERROR: ${streamedResponse.statusCode}');
        throw Exception(
          'LM Studio streaming error: ${streamedResponse.statusCode}',
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
              debugPrint(
                '[LMStudio] Stream complete. Total chunks: $chunkCount',
              );
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
                    debugPrint('[LMStudio] Chunk $chunkCount received');
                  }
                  yield content;
                }
              }
            } catch (e) {
              debugPrint('[LMStudio] JSON parse error: $e');
            }
          }
        }
      }
      debugPrint('[LMStudio] Stream finished. Total chunks: $chunkCount');
    } finally {
      client.close();
    }
  }

  List<Map<String, dynamic>> _buildMessages(
    String message,
    List<ChatMessage> history,
    String? systemPrompt, {
    List<Attachment>? attachments,
  }) {
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

      // Check if message has image attachments (LM Studio may support vision models)
      if (msg.attachments.any((a) => a.type == AttachmentType.image)) {
        final content = <Map<String, dynamic>>[];

        // Add text first
        content.add({'type': 'text', 'text': msg.content});

        // Add images
        for (final attachment in msg.attachments) {
          if (attachment.type == AttachmentType.image) {
            content.add({
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:${attachment.mimeType};base64,${attachment.base64Data}',
              },
            });
          }
        }

        messages.add({'role': role, 'content': content});
      } else {
        messages.add({'role': role, 'content': msg.content});
      }
    }

    // Build current message content
    if (attachments != null &&
        attachments.any((a) => a.type == AttachmentType.image)) {
      final content = <Map<String, dynamic>>[];

      // Add text first
      content.add({
        'type': 'text',
        'text': message.isNotEmpty ? message : 'Describe this image.',
      });

      // Add images
      for (final attachment in attachments) {
        if (attachment.type == AttachmentType.image) {
          content.add({
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${attachment.mimeType};base64,${attachment.base64Data}',
            },
          });
        }
      }

      messages.add({'role': 'user', 'content': content});
    } else {
      messages.add({'role': 'user', 'content': message});
    }

    return messages;
  }
}
