import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import '../utils/file_processor.dart';
import 'ai_service.dart';

/// OpenAI ChatGPT Service Implementation
class OpenAIService implements AIService {
  String _apiKey = '';
  String _modelId = AppConstants.defaultOpenAIModel;

  OpenAIService({String? apiKey, String? modelId}) {
    if (apiKey != null) _apiKey = apiKey;
    if (modelId != null) _modelId = modelId;
  }

  /// Base URL of the OpenAI-compatible API (overridable by subclasses
  /// such as OpenRouter, which uses the same wire format)
  @protected
  String get baseUrl => AppConstants.openAIBaseUrl;

  /// Auth headers sent with each request (overridable by subclasses)
  @protected
  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer $_apiKey',
  };

  /// Log prefix used in debug output (overridable by subclasses)
  @protected
  String get logTag => 'OpenAI';

  /// API key, exposed for subclasses
  @protected
  String get apiKey => _apiKey;

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
    if (_apiKey.isEmpty) {
      return AIProvider.openai.availableModels;
    }
    
    try {
      final url = Uri.parse('$baseUrl/models');
      final response = await http.get(
        url,
        headers: authHeaders,
      );
      
      if (response.statusCode != 200) {
        debugPrint('[$logTag] Failed to fetch models: ${response.statusCode}');
        return AIProvider.openai.availableModels;
      }
      
      final data = jsonDecode(response.body);
      final models = data['data'] as List<dynamic>?;
      
      if (models == null || models.isEmpty) {
        return AIProvider.openai.availableModels;
      }
      
      // Filter to only include GPT chat models
      final availableModels = models
          .map((m) => m['id'] as String)
          .where((id) => id.startsWith('gpt-') && !id.contains('instruct'))
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Sort descending (newer first)
      
      debugPrint('[$logTag] Found ${availableModels.length} GPT models');
      return availableModels.isEmpty ? AIProvider.openai.availableModels : availableModels;
    } catch (e) {
      debugPrint('[$logTag] Error fetching models: $e');
      return AIProvider.openai.availableModels;
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
    debugPrint('[$logTag] sendMessage called');
    debugPrint('[$logTag] Model: $_modelId');
    debugPrint('[$logTag] Message length: ${message.length}');
    debugPrint('[$logTag] History count: ${history.length}');
    debugPrint('[$logTag] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[$logTag] ERROR: API key not set');
      throw Exception('$providerName API key not set');
    }

    final url = Uri.parse('$baseUrl/chat/completions');
    debugPrint('[$logTag] URL: $url');
    final messages = _buildMessages(message, history, systemPrompt, attachments: attachments);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    debugPrint('[$logTag] Sending request...');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        ...authHeaders,
      },
      body: body,
    );
    debugPrint('[$logTag] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      debugPrint('[$logTag] ERROR: ${response.body}');
      throw Exception(error['error']?['message'] ?? '$providerName API error');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List<dynamic>;
    debugPrint('[$logTag] Choices count: ${choices.length}');

    if (choices.isEmpty) {
      throw Exception('No response from $providerName');
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
    debugPrint('[$logTag] sendMessageStream called');
    debugPrint(
      '[$logTag] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );
    debugPrint('[$logTag] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[$logTag] ERROR: API key not set');
      throw Exception('$providerName API key not set');
    }

    final url = Uri.parse('$baseUrl/chat/completions');
    debugPrint('[$logTag] Stream URL: $url');
    final messages = _buildMessages(message, history, systemPrompt, attachments: attachments);

    final body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
    });

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.headers.addAll(authHeaders);
    request.body = body;

    debugPrint('[$logTag] Sending stream request...');
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      debugPrint(
        '[$logTag] Stream response status: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode != 200) {
        // Read the error body to surface OpenAI's actual reason
        // (e.g. rate_limit_exceeded vs insufficient_quota)
        final errorBody = await streamedResponse.stream.bytesToString();
        String errorMessage =
            '$providerName streaming error: ${streamedResponse.statusCode}';
        try {
          final error = jsonDecode(errorBody);
          final message = error['error']?['message'] as String?;
          final type = error['error']?['type'] as String?;
          if (message != null && message.isNotEmpty) {
            errorMessage =
                '$errorMessage - $message${type != null ? ' [$type]' : ''}';
          }
        } catch (_) {
          // Body wasn't JSON; keep the status-code-only message
        }
        debugPrint('[$logTag] Stream ERROR: $errorMessage');
        throw Exception(errorMessage);
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
              debugPrint('[$logTag] Stream complete. Total chunks: $chunkCount');
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
                    debugPrint('[$logTag] Chunk $chunkCount received');
                  }
                  yield content;
                }
              }
            } catch (e) {
              debugPrint('[$logTag] JSON parse error: $e');
            }
          }
        }
      }
      debugPrint('[$logTag] Stream finished. Total chunks: $chunkCount');
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
      
      // Check if message has any attachments
      if (msg.attachments.isNotEmpty) {
        final content = <Map<String, dynamic>>[];
        
        // Add text first
        content.add({
          'type': 'text',
          'text': msg.content,
        });
        
        // Add attachments
        for (final attachment in msg.attachments) {
          // Validate attachment for OpenAI
          final validationError = FileProcessor.validateAttachment(attachment, providerName);
          if (validationError != null) {
            debugPrint('[$logTag] Skipping attachment ${attachment.name}: $validationError');
            continue;
          }
          
          if (attachment.type == AttachmentType.image) {
            content.add({
              'type': 'image_url',
              'image_url': {
                'url': 'data:${attachment.mimeType};base64,${attachment.base64Data}',
              },
            });
          } else if (attachment.type == AttachmentType.file) {
            // For files, we'll include them as document data
            content.add({
              'type': 'text',
              'text': '\n\n--- Document: ${attachment.name} ---\n${FileProcessor.formatFileInfo(attachment)}\n',
            });
          }
        }
        
        messages.add({'role': role, 'content': content});
      } else {
        messages.add({'role': role, 'content': msg.content});
      }
    }

    // Build current message content
    if (attachments != null && attachments.isNotEmpty) {
      final content = <Map<String, dynamic>>[];
      
      // Add text first
      content.add({
        'type': 'text',
        'text': message.isNotEmpty ? message : 'Please analyze the attached file(s).',
      });
      
      // Add attachments
      for (final attachment in attachments) {
        // Validate attachment for OpenAI
        final validationError = FileProcessor.validateAttachment(attachment, providerName);
        if (validationError != null) {
          debugPrint('[$logTag] Skipping attachment ${attachment.name}: $validationError');
          continue;
        }
        
        if (attachment.type == AttachmentType.image) {
          content.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:${attachment.mimeType};base64,${attachment.base64Data}',
            },
          });
        } else if (attachment.type == AttachmentType.file) {
          // For files, extract text content and include it
          final textContent = FileProcessor.extractTextContentSync(attachment);
          content.add({
            'type': 'text',
            'text': '\n\n--- Document: ${attachment.name} ---\n${FileProcessor.formatFileInfo(attachment)}\n\n$textContent',
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
