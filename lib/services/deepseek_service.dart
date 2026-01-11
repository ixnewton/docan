import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import 'ai_service.dart';

/// DeepSeek AI Service Implementation
/// DeepSeek API is OpenAI-compatible
class DeepSeekService implements AIService {
  String _apiKey = '';
  String _modelId = AppConstants.defaultDeepSeekModel;

  DeepSeekService({String? apiKey, String? modelId}) {
    if (apiKey != null) _apiKey = apiKey;
    if (modelId != null) _modelId = modelId;
  }

  @override
  AIProvider get provider => AIProvider.deepseek;

  @override
  String get providerName => 'DeepSeek';

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
    if (_apiKey.isEmpty) {
      return AIProvider.deepseek.availableModels;
    }

    try {
      final url = Uri.parse('${AppConstants.deepSeekBaseUrl}/models');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode != 200) {
        debugPrint('[DeepSeek] Failed to fetch models: ${response.statusCode}');
        return AIProvider.deepseek.availableModels;
      }

      final data = jsonDecode(response.body);
      final models = data['data'] as List<dynamic>?;

      if (models == null || models.isEmpty) {
        return AIProvider.deepseek.availableModels;
      }

      final availableModels = models.map((m) => m['id'] as String).toList()
        ..sort();

      debugPrint('[DeepSeek] Found ${availableModels.length} models');
      return availableModels.isEmpty
          ? AIProvider.deepseek.availableModels
          : availableModels;
    } catch (e) {
      debugPrint('[DeepSeek] Error fetching models: $e');
      return AIProvider.deepseek.availableModels;
    }
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
    List<Attachment>? attachments,
  }) async {
    debugPrint('[DeepSeek] sendMessage called');
    debugPrint('[DeepSeek] Model: $_modelId');
    debugPrint('[DeepSeek] Message length: ${message.length}');
    debugPrint('[DeepSeek] History count: ${history.length}');
    debugPrint('[DeepSeek] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[DeepSeek] ERROR: API key not set');
      throw Exception('DeepSeek API key not set');
    }

    final url = Uri.parse('${AppConstants.deepSeekBaseUrl}/chat/completions');
    debugPrint('[DeepSeek] URL: $url');
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

    debugPrint('[DeepSeek] Sending request...');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    );
    debugPrint('[DeepSeek] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      debugPrint('[DeepSeek] ERROR: ${response.body}');
      throw Exception(error['error']?['message'] ?? 'DeepSeek API error');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List<dynamic>;
    debugPrint('[DeepSeek] Choices count: ${choices.length}');

    if (choices.isEmpty) {
      throw Exception('No response from DeepSeek');
    }

    // Handle reasoning content for deepseek-reasoner model
    final responseMessage = choices[0]['message'];
    final reasoningContent = responseMessage['reasoning_content'] as String?;
    final content = responseMessage['content'] as String? ?? '';

    if (reasoningContent != null && reasoningContent.isNotEmpty) {
      debugPrint('[DeepSeek] Reasoning content received');
      return '<thinking>\n$reasoningContent\n</thinking>\n\n$content';
    }

    return content;
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
    debugPrint('[DeepSeek] sendMessageStream called');
    debugPrint(
      '[DeepSeek] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );
    debugPrint('[DeepSeek] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[DeepSeek] ERROR: API key not set');
      throw Exception('DeepSeek API key not set');
    }

    final url = Uri.parse('${AppConstants.deepSeekBaseUrl}/chat/completions');
    debugPrint('[DeepSeek] Stream URL: $url');
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
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.body = body;

    debugPrint('[DeepSeek] Sending stream request...');
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      debugPrint(
        '[DeepSeek] Stream response status: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('[DeepSeek] Stream ERROR: ${streamedResponse.statusCode}');
        throw Exception(
          'DeepSeek streaming error: ${streamedResponse.statusCode}',
        );
      }

      int chunkCount = 0;
      String buffer = '';
      bool hasReasoningContent = false;
      bool reasoningStarted = false;

      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        buffer += chunk;

        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);

          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr == '[DONE]') {
              debugPrint(
                '[DeepSeek] Stream complete. Total chunks: $chunkCount',
              );
              if (hasReasoningContent) {
                yield '\n</thinking>\n\n';
              }
              continue;
            }
            if (jsonStr.isEmpty) continue;

            try {
              final data = jsonDecode(jsonStr);
              final choices = data['choices'] as List<dynamic>?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'];

                // Handle reasoning content for deepseek-reasoner
                final reasoningContent = delta?['reasoning_content'] as String?;
                if (reasoningContent != null && reasoningContent.isNotEmpty) {
                  if (!reasoningStarted) {
                    reasoningStarted = true;
                    hasReasoningContent = true;
                    yield '<thinking>\n';
                  }
                  chunkCount++;
                  yield reasoningContent;
                }

                final content = delta?['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  if (hasReasoningContent && reasoningStarted) {
                    reasoningStarted = false;
                    yield '\n</thinking>\n\n';
                  }
                  chunkCount++;
                  if (chunkCount <= 3) {
                    debugPrint('[DeepSeek] Chunk $chunkCount received');
                  }
                  yield content;
                }
              }
            } catch (e) {
              debugPrint('[DeepSeek] JSON parse error: $e');
            }
          }
        }
      }
      debugPrint('[DeepSeek] Stream finished. Total chunks: $chunkCount');
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

      // Check if message has image attachments
      if (msg.attachments.any((a) => a.type == AttachmentType.image)) {
        final content = <Map<String, dynamic>>[];

        content.add({'type': 'text', 'text': msg.content});

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

      content.add({
        'type': 'text',
        'text': message.isNotEmpty ? message : 'Describe this image.',
      });

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
