import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import '../utils/file_processor.dart';
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
    debugPrint('[Claude] Messages: ${_sanitizeMessagesForDebug(messages)}');

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

    debugPrint('[Claude] Request body: ${_sanitizeRequestBodyForDebug(request.body)}');
    debugPrint('[Claude] Sending stream request...');
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      debugPrint(
        '[Claude] Stream response status: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('[Claude] Stream ERROR: ${streamedResponse.statusCode}');
        final responseBody = await streamedResponse.stream.bytesToString();
        debugPrint('[Claude] Stream ERROR body: $responseBody');
        throw Exception(
          'Claude streaming error: ${streamedResponse.statusCode} - $responseBody',
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
      
      // Check if message has any attachments
      if (msg.attachments.isNotEmpty) {
        final content = <Map<String, dynamic>>[];
        
        // Add text content first (Claude prefers text first)
        content.add({
          'type': 'text',
          'text': msg.content,
        });
        
        // Add attachments
        for (final attachment in msg.attachments) {
          // Validate attachment for Claude
          final validationError = FileProcessor.validateAttachment(attachment, providerName);
          if (validationError != null) {
            debugPrint('[Claude] Skipping attachment ${attachment.name}: $validationError');
            continue;
          }
          
          if (attachment.type == AttachmentType.image) {
            content.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': attachment.mimeType,
                'data': attachment.base64Data,
              },
            });
          } else if (attachment.type == AttachmentType.file) {
            // For files, extract text content and include it as a document
            final textContent = FileProcessor.extractTextContentSync(attachment);
            content.add({
              'type': 'text',
              'text': '\n\n--- Document: ${attachment.name} ---\n${FileProcessor.formatFileInfo(attachment)}\n\n$textContent',
            });
          }
        }
        
        // Only add message if content is not empty
        if (content.isNotEmpty) {
          messages.add({
            'role': msg.role == MessageRole.user ? 'user' : 'assistant',
            'content': content,
          });
        }
      } else {
        messages.add({
          'role': msg.role == MessageRole.user ? 'user' : 'assistant',
          'content': msg.content,
        });
      }
    }

    // Build current message content
    if (attachments != null && attachments.isNotEmpty) {
      final content = <Map<String, dynamic>>[];
      
      // Add text first (Claude prefers text first)
      content.add({
        'type': 'text',
        'text': message.isNotEmpty ? message : 'Please analyze the attached file(s).',
      });
      
      // Add attachments
      for (final attachment in attachments) {
        // Validate attachment for Claude
        final validationError = FileProcessor.validateAttachment(attachment, providerName);
        if (validationError != null) {
          debugPrint('[Claude] Skipping attachment ${attachment.name}: $validationError');
          continue;
        }
        
        if (attachment.type == AttachmentType.image) {
          content.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': attachment.mimeType,
              'data': attachment.base64Data,
            },
          });
        } else if (attachment.type == AttachmentType.file) {
          // For files, extract text content and include it as a document
          final textContent = FileProcessor.extractTextContentSync(attachment);
          content.add({
            'type': 'text',
            'text': '\n\n--- Document: ${attachment.name} ---\n${FileProcessor.formatFileInfo(attachment)}\n\n$textContent',
          });
        }
      }
      
      // Only add message if content is not empty
      if (content.isNotEmpty) {
        messages.add({'role': 'user', 'content': content});
      }
    } else {
      messages.add({'role': 'user', 'content': message});
    }

    return messages;
  }

  /// Sanitize messages for debug output to prevent sensitive data exposure
  String _sanitizeMessagesForDebug(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return '[]';
    
    final sanitized = messages.map((msg) {
      final role = msg['role'] ?? 'unknown';
      final content = msg['content'];
      
      if (content is String) {
        // Truncate long text content
        final truncated = content.length > 100 
            ? '${content.substring(0, 100)}...' 
            : content;
        return {'role': role, 'content': truncated};
      } else if (content is List) {
        // Handle mixed content (text + images)
        final sanitizedContent = content.map((item) {
          if (item is Map && item['type'] == 'text') {
            final text = item['text'] as String? ?? '';
            final truncated = text.length > 100 
                ? '${text.substring(0, 100)}...' 
                : text;
            return {'type': 'text', 'text': truncated};
          } else if (item is Map && item['type'] == 'image') {
            return {'type': 'image', 'source': '[IMAGE_DATA]'};
          }
          return item;
        }).toList();
        return {'role': role, 'content': sanitizedContent};
      }
      
      return {'role': role, 'content': '[UNSUPPORTED_CONTENT_TYPE]'};
    }).toList();
    
    return jsonEncode(sanitized);
  }

  /// Sanitize request body for debug output
  String _sanitizeRequestBodyForDebug(String requestBody) {
    try {
      final body = jsonDecode(requestBody) as Map<String, dynamic>;
      final sanitized = Map<String, dynamic>.from(body);
      
      // Sanitize messages if present
      if (sanitized['messages'] != null) {
        sanitized['messages'] = jsonDecode(_sanitizeMessagesForDebug(
          List<Map<String, dynamic>>.from(sanitized['messages'])
        ));
      }
      
      // Sanitize system prompt if present
      if (sanitized['system'] != null && sanitized['system'].toString().length > 100) {
        sanitized['system'] = '${sanitized['system'].toString().substring(0, 100)}...';
      }
      
      return jsonEncode(sanitized);
    } catch (e) {
      return '[REQUEST_BODY_PARSE_ERROR]';
    }
  }
}
