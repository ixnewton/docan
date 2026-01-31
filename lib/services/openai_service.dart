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
      final url = Uri.parse('${AppConstants.openAIBaseUrl}/models');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );
      
      if (response.statusCode != 200) {
        debugPrint('[OpenAI] Failed to fetch models: ${response.statusCode}');
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
      
      debugPrint('[OpenAI] Found ${availableModels.length} GPT models');
      return availableModels.isEmpty ? AIProvider.openai.availableModels : availableModels;
    } catch (e) {
      debugPrint('[OpenAI] Error fetching models: $e');
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
    debugPrint('[OpenAI] sendMessage called');
    debugPrint('[OpenAI] Model: $_modelId');
    debugPrint('[OpenAI] Message length: ${message.length}');
    debugPrint('[OpenAI] History count: ${history.length}');
    debugPrint('[OpenAI] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[OpenAI] ERROR: API key not set');
      throw Exception('OpenAI API key not set');
    }

    final url = Uri.parse('${AppConstants.openAIBaseUrl}/chat/completions');
    debugPrint('[OpenAI] URL: $url');
    final messages = _buildMessages(message, history, systemPrompt, attachments: attachments);

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
    List<Attachment>? attachments,
  }) async* {
    debugPrint('[OpenAI] sendMessageStream called');
    debugPrint(
      '[OpenAI] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );
    debugPrint('[OpenAI] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[OpenAI] ERROR: API key not set');
      throw Exception('OpenAI API key not set');
    }

    final url = Uri.parse('${AppConstants.openAIBaseUrl}/chat/completions');
    debugPrint('[OpenAI] Stream URL: $url');
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
            debugPrint('[OpenAI] Skipping attachment ${attachment.name}: $validationError');
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
          debugPrint('[OpenAI] Skipping attachment ${attachment.name}: $validationError');
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
