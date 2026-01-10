import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    if (_apiKey.isEmpty) {
      return AIProvider.claude.availableModels;
    }
    
    try {
      final url = Uri.parse('${AppConstants.claudeBaseUrl}/models');
      final response = await http.get(
        url,
        headers: {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
      );
      
      if (response.statusCode != 200) {
        debugPrint('[Claude] Failed to fetch models: ${response.statusCode}');
        return AIProvider.claude.availableModels;
      }
      
      final data = jsonDecode(response.body);
      final models = data['data'] as List<dynamic>?;
      
      if (models == null || models.isEmpty) {
        return AIProvider.claude.availableModels;
      }
      
      final availableModels = models
          .map((m) => m['id'] as String)
          .where((id) => id.startsWith('claude-'))
          .toList();
      
      debugPrint('[Claude] Found ${availableModels.length} models');
      return availableModels.isEmpty ? AIProvider.claude.availableModels : availableModels;
    } catch (e) {
      debugPrint('[Claude] Error fetching models: $e');
      return AIProvider.claude.availableModels;
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
    debugPrint('[Claude] sendMessage called');
    debugPrint('[Claude] Model: $_modelId');
    debugPrint('[Claude] Message length: ${message.length}');
    debugPrint('[Claude] History count: ${history.length}');
    debugPrint('[Claude] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[Claude] ERROR: API key not set');
      throw Exception('Claude API key not set');
    }

    final url = Uri.parse('${AppConstants.claudeBaseUrl}/messages');
    debugPrint('[Claude] URL: $url');
    final messages = _buildMessages(message, history, attachments: attachments);

    final body = <String, dynamic>{
      'model': _modelId,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    debugPrint('[Claude] Sending request...');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(body),
    );
    debugPrint('[Claude] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      debugPrint('[Claude] ERROR: ${response.body}');
      throw Exception(error['error']?['message'] ?? 'Claude API error');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List<dynamic>;
    debugPrint('[Claude] Content blocks: ${content.length}');

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
    List<Attachment>? attachments,
  }) async* {
    debugPrint('[Claude] sendMessageStream called');
    debugPrint(
      '[Claude] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );
    debugPrint('[Claude] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[Claude] ERROR: API key not set');
      throw Exception('Claude API key not set');
    }

    final url = Uri.parse('${AppConstants.claudeBaseUrl}/messages');
    debugPrint('[Claude] Stream URL: $url');
    final messages = _buildMessages(message, history, attachments: attachments);

    final body = <String, dynamic>{
      'model': _modelId,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
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

    debugPrint('[Claude] Sending stream request...');
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      debugPrint(
        '[Claude] Stream response status: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('[Claude] Stream ERROR: ${streamedResponse.statusCode}');
        throw Exception(
          'Claude streaming error: ${streamedResponse.statusCode}',
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
            if (jsonStr.isEmpty) continue;

            try {
              final data = jsonDecode(jsonStr);
              final type = data['type'] as String?;

              if (type == 'content_block_delta') {
                final delta = data['delta'];
                final text = delta?['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  chunkCount++;
                  if (chunkCount <= 3) {
                    debugPrint('[Claude] Chunk $chunkCount received');
                  }
                  yield text;
                }
              } else if (type == 'message_stop') {
                debugPrint(
                  '[Claude] Stream complete. Total chunks: $chunkCount',
                );
              }
            } catch (e) {
              debugPrint('[Claude] JSON parse error: $e');
            }
          }
        }
      }
      debugPrint('[Claude] Stream finished. Total chunks: $chunkCount');
    } finally {
      client.close();
    }
  }

  List<Map<String, dynamic>> _buildMessages(
    String message,
    List<ChatMessage> history, {
    List<Attachment>? attachments,
  }) {
    final messages = <Map<String, dynamic>>[];

    // Add conversation history (Claude doesn't support system role in messages)
    for (final msg in history) {
      if (msg.role == MessageRole.system) continue;
      // Skip error messages and empty content
      if (msg.error != null || msg.content.trim().isEmpty) continue;
      
      // Check if message has image attachments
      if (msg.attachments.any((a) => a.type == AttachmentType.image)) {
        final content = <Map<String, dynamic>>[];
        
        // Add images first
        for (final attachment in msg.attachments) {
          if (attachment.type == AttachmentType.image) {
            content.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': attachment.mimeType,
                'data': attachment.base64Data,
              },
            });
          }
        }
        
        // Add text
        content.add({
          'type': 'text',
          'text': msg.content,
        });
        
        messages.add({
          'role': msg.role == MessageRole.user ? 'user' : 'assistant',
          'content': content,
        });
      } else {
        messages.add({
          'role': msg.role == MessageRole.user ? 'user' : 'assistant',
          'content': msg.content,
        });
      }
    }

    // Build current message content
    if (attachments != null && attachments.any((a) => a.type == AttachmentType.image)) {
      final content = <Map<String, dynamic>>[];
      
      // Add images first
      for (final attachment in attachments) {
        if (attachment.type == AttachmentType.image) {
          content.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': attachment.mimeType,
              'data': attachment.base64Data,
            },
          });
        }
      }
      
      // Add text
      content.add({
        'type': 'text',
        'text': message.isNotEmpty ? message : 'Describe this image.',
      });
      
      messages.add({'role': 'user', 'content': content});
    } else {
      messages.add({'role': 'user', 'content': message});
    }

    return messages;
  }
}
