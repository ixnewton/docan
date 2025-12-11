import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import 'ai_service.dart';

/// Google Gemini AI Service Implementation
class GeminiService implements AIService {
  String _apiKey = '';
  String _modelId = AppConstants.defaultGeminiModel;

  GeminiService({String? apiKey, String? modelId}) {
    if (apiKey != null) _apiKey = apiKey;
    if (modelId != null) _modelId = modelId;
  }

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
    return AIProvider.gemini.availableModels;
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
    debugPrint('[Gemini] sendMessage called');
    debugPrint('[Gemini] Model: $_modelId');
    debugPrint('[Gemini] Message length: ${message.length}');
    debugPrint('[Gemini] History count: ${history.length}');

    if (_apiKey.isEmpty) {
      debugPrint('[Gemini] ERROR: API key not set');
      throw Exception('Gemini API key not set');
    }

    final url = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$_modelId:generateContent?key=$_apiKey',
    );
    debugPrint('[Gemini] URL: ${url.toString().replaceAll(_apiKey, '***')}');

    final contents = _buildContents(message, history, systemPrompt);

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'topP': 0.95,
        'topK': 40,
      },
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
      throw Exception(error['error']?['message'] ?? 'Gemini API error');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List<dynamic>?;
    debugPrint('[Gemini] Candidates count: ${candidates?.length ?? 0}');

    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    final content = candidates[0]['content'];
    final parts = content['parts'] as List<dynamic>;

    return parts.map((p) => p['text'] ?? '').join('');
  }

  @override
  Stream<String> sendMessageStream(
    String message,
    List<ChatMessage> history, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    debugPrint('[Gemini] sendMessageStream called');
    debugPrint(
      '[Gemini] Model: $_modelId, Temp: $temperature, MaxTokens: $maxTokens',
    );

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

    final contents = _buildContents(message, history, systemPrompt);

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'topP': 0.95,
        'topK': 40,
      },
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
          'Gemini streaming error: ${streamedResponse.statusCode}',
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
                  final text = parts[0]['text'] ?? '';
                  if (text.isNotEmpty) {
                    chunkCount++;
                    if (chunkCount <= 3)
                      debugPrint('[Gemini] Chunk $chunkCount received');
                    yield text;
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
                final text = parts[0]['text'] ?? '';
                if (text.isNotEmpty) {
                  chunkCount++;
                  debugPrint('[Gemini] Final buffer chunk received');
                  yield text;
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
    String? systemPrompt,
  ) {
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
      contents.add({
        'role': msg.role == MessageRole.user ? 'user' : 'model',
        'parts': [
          {'text': msg.content},
        ],
      });
    }

    // Add current message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': message},
      ],
    });

    return contents;
  }
}
