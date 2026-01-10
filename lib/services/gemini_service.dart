import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import '../utils/api_error_parser.dart';
import 'ai_service.dart';

/// Google Gemini AI Service Implementation
class GeminiService implements AIService {
  String _apiKey = '';
  String _modelId = AppConstants.defaultGeminiModel;

  GeminiService({String? apiKey, String? modelId}) {
    if (apiKey != null) _apiKey = apiKey;
    if (modelId != null) _modelId = modelId;
  }

  /// Check if the current model supports image generation
  bool get _isImageModel =>
      _modelId.contains('-image') || _modelId == 'gemini-3-pro-image-preview';

  @override
  AIProvider get provider => AIProvider.gemini;

  @override
  String get providerName => 'Gemini';

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
      return AIProvider.gemini.availableModels;
    }

    try {
      final url = Uri.parse(
        '${AppConstants.geminiBaseUrl}/models?key=$_apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('[Gemini] Failed to fetch models: ${response.statusCode}');
        return AIProvider.gemini.availableModels;
      }

      final data = jsonDecode(response.body);
      final models = data['models'] as List<dynamic>?;

      if (models == null || models.isEmpty) {
        return AIProvider.gemini.availableModels;
      }

      // Filter to only include generateContent-capable models
      final availableModels = models
          .where((m) {
            final methods = m['supportedGenerationMethods'] as List<dynamic>?;
            return methods?.contains('generateContent') ?? false;
          })
          .map((m) {
            final name = m['name'] as String;
            // Strip 'models/' prefix
            return name.startsWith('models/') ? name.substring(7) : name;
          })
          .where((name) => !name.contains('embedding') && !name.contains('aqa'))
          .toList();

      debugPrint('[Gemini] Found ${availableModels.length} models');
      return availableModels.isEmpty
          ? AIProvider.gemini.availableModels
          : availableModels;
    } catch (e) {
      debugPrint('[Gemini] Error fetching models: $e');
      return AIProvider.gemini.availableModels;
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
    debugPrint('[Gemini] sendMessage called');
    debugPrint('[Gemini] Model: $_modelId');
    debugPrint('[Gemini] Message length: ${message.length}');
    debugPrint('[Gemini] History count: ${history.length}');
    debugPrint('[Gemini] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[Gemini] ERROR: API key not set');
      throw Exception('Gemini API key not set');
    }

    final url = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$_modelId:generateContent?key=$_apiKey',
    );
    debugPrint('[Gemini] URL: ${url.toString().replaceAll(_apiKey, '***')}');

    final contents = _buildContents(
      message,
      history,
      systemPrompt,
      attachments: attachments,
    );

    final generationConfig = <String, dynamic>{
      'temperature': temperature,
      'maxOutputTokens': maxTokens,
      'topP': 0.95,
      'topK': 40,
    };

    // Add response modalities for image generation models
    if (_isImageModel) {
      generationConfig['responseModalities'] = ['TEXT', 'IMAGE'];
    }

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': generationConfig,
    });

    debugPrint('[Gemini] Sending request...');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    debugPrint('[Gemini] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      debugPrint('[Gemini] ERROR: ${response.body}');
      final errorMessage = error['error']?['message'] ?? 'Gemini API error';
      throw Exception(ApiErrorParser.parse(errorMessage, response.statusCode));
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List<dynamic>?;
    debugPrint('[Gemini] Candidates count: ${candidates?.length ?? 0}');

    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    final content = candidates[0]['content'];
    final parts = content['parts'] as List<dynamic>;

    // Process parts - handle both text and images
    final result = StringBuffer();
    for (final part in parts) {
      // Skip thought parts (for thinking models)
      if (part['thought'] == true) continue;

      if (part['text'] != null) {
        result.write(part['text']);
      } else if (part['inlineData'] != null || part['inline_data'] != null) {
        final inlineData = part['inlineData'] ?? part['inline_data'];
        final mimeType =
            inlineData['mimeType'] ?? inlineData['mime_type'] ?? 'image/png';
        final data = inlineData['data'];
        if (data != null) {
          // Return image as a special marker that can be parsed by the chat bubble
          result.write('\n![Generated Image](data:$mimeType;base64,$data)\n');
        }
      }
    }

    return result.toString();
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
    debugPrint('[Gemini] sendMessageStream called');
    debugPrint(
      '[Gemini] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );
    debugPrint('[Gemini] Attachments: ${attachments?.length ?? 0}');

    if (_apiKey.isEmpty) {
      debugPrint('[Gemini] ERROR: API key not set');
      throw Exception('Gemini API key not set');
    }

    final url = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$_modelId:streamGenerateContent?key=$_apiKey&alt=sse',
    );
    debugPrint(
      '[Gemini] Stream URL: ${url.toString().replaceAll(_apiKey, '***')}',
    );

    final contents = _buildContents(
      message,
      history,
      systemPrompt,
      attachments: attachments,
    );

    final generationConfig = <String, dynamic>{
      'temperature': temperature,
      'maxOutputTokens': maxTokens,
      'topP': 0.95,
      'topK': 40,
    };

    // Add response modalities for image generation models
    if (_isImageModel) {
      generationConfig['responseModalities'] = ['TEXT', 'IMAGE'];
    }

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': generationConfig,
    });

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = body;

    debugPrint('[Gemini] Sending stream request...');
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      debugPrint(
        '[Gemini] Stream response status: ${streamedResponse.statusCode}',
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('[Gemini] Stream ERROR: ${streamedResponse.statusCode}');
        throw Exception(
          ApiErrorParser.parse(
            'Gemini streaming error',
            streamedResponse.statusCode,
          ),
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
            final jsonStr = line.substring(6);
            if (jsonStr.trim().isEmpty) continue;

            try {
              final data = jsonDecode(jsonStr);
              final candidates = data['candidates'] as List<dynamic>?;
              if (candidates != null && candidates.isNotEmpty) {
                final content = candidates[0]['content'];
                final parts = content?['parts'] as List<dynamic>?;
                if (parts != null && parts.isNotEmpty) {
                  for (final part in parts) {
                    // Skip thought parts (for thinking models)
                    if (part['thought'] == true) continue;

                    final text = part['text'];
                    if (text != null && text.isNotEmpty) {
                      chunkCount++;
                      if (chunkCount <= 3) {
                        debugPrint('[Gemini] Chunk $chunkCount received');
                      }
                      yield text;
                    }

                    // Handle inline image data
                    final inlineData =
                        part['inlineData'] ?? part['inline_data'];
                    if (inlineData != null) {
                      final mimeType =
                          inlineData['mimeType'] ??
                          inlineData['mime_type'] ??
                          'image/png';
                      final imageData = inlineData['data'];
                      if (imageData != null) {
                        chunkCount++;
                        debugPrint('[Gemini] Image chunk received');
                        yield '\n![Generated Image](data:$mimeType;base64,$imageData)\n';
                      }
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('[Gemini] JSON parse error for line: $line');
              debugPrint('[Gemini] Error: $e');
            }
          }
        }
      }

      // Process any remaining data in buffer (in case stream ended without final newline)
      if (buffer.trim().isNotEmpty && buffer.startsWith('data: ')) {
        final jsonStr = buffer.substring(6).trim();
        if (jsonStr.isNotEmpty) {
          try {
            final data = jsonDecode(jsonStr);
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                for (final part in parts) {
                  // Skip thought parts
                  if (part['thought'] == true) continue;

                  final text = part['text'];
                  if (text != null && text.isNotEmpty) {
                    chunkCount++;
                    debugPrint('[Gemini] Final buffer text chunk received');
                    yield text;
                  }

                  // Handle inline image data
                  final inlineData = part['inlineData'] ?? part['inline_data'];
                  if (inlineData != null) {
                    final mimeType =
                        inlineData['mimeType'] ??
                        inlineData['mime_type'] ??
                        'image/png';
                    final imageData = inlineData['data'];
                    if (imageData != null) {
                      chunkCount++;
                      debugPrint('[Gemini] Final buffer image chunk received');
                      yield '\n![Generated Image](data:$mimeType;base64,$imageData)\n';
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[Gemini] JSON parse error for final buffer: $e');
          }
        }
      }

      debugPrint('[Gemini] Stream complete. Total chunks: $chunkCount');
    } finally {
      client.close();
    }
  }

  List<Map<String, dynamic>> _buildContents(
    String message,
    List<ChatMessage> history,
    String? systemPrompt, {
    List<Attachment>? attachments,
  }) {
    final contents = <Map<String, dynamic>>[];

    // Add system prompt as first user message if provided
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'System: $systemPrompt'},
        ],
      });
      contents.add({
        'role': 'model',
        'parts': [
          {'text': 'Understood. I will follow these instructions.'},
        ],
      });
    }

    // Add conversation history
    for (final msg in history) {
      if (msg.role == MessageRole.system) continue;
      // Skip error messages and empty content
      if (msg.error != null || msg.content.trim().isEmpty) continue;

      final parts = <Map<String, dynamic>>[];

      // Add any image attachments from history
      if (msg.attachments.isNotEmpty) {
        for (final attachment in msg.attachments) {
          if (attachment.type == AttachmentType.image) {
            parts.add({
              'inline_data': {
                'mime_type': attachment.mimeType,
                'data': attachment.base64Data,
              },
            });
          }
        }
      }

      // Add text content
      parts.add({'text': msg.content});

      contents.add({
        'role': msg.role == MessageRole.user ? 'user' : 'model',
        'parts': parts,
      });
    }

    // Build parts for current message
    final currentParts = <Map<String, dynamic>>[];

    // Add image attachments first
    if (attachments != null) {
      for (final attachment in attachments) {
        if (attachment.type == AttachmentType.image) {
          currentParts.add({
            'inline_data': {
              'mime_type': attachment.mimeType,
              'data': attachment.base64Data,
            },
          });
        }
      }
    }

    // Add text content
    currentParts.add({
      'text': message.isNotEmpty ? message : 'Describe this image.',
    });

    // Add current message
    contents.add({'role': 'user', 'parts': currentParts});

    return contents;
  }
}
