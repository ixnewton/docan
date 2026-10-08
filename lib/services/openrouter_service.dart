import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/ai_provider.dart';
import 'openai_service.dart';

/// OpenRouter Service Implementation
///
/// OpenRouter exposes an OpenAI-compatible API, so this subclasses
/// OpenAIService and only overrides identity, endpoint, headers and the
/// model listing (OpenRouter returns every vendor's models, with ids in
/// "vendor/model" form).
class OpenRouterService extends OpenAIService {
  OpenRouterService({super.apiKey, String? modelId})
    : super(modelId: modelId ?? AppConstants.defaultOpenRouterModel);

  @override
  AIProvider get provider => AIProvider.openrouter;

  @override
  String get providerName => 'OpenRouter';

  @override
  String get logTag => 'OpenRouter';

  @override
  String get baseUrl => AppConstants.openRouterBaseUrl;

  @override
  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer $apiKey',
    // Recommended attribution headers for OpenRouter rankings
    'HTTP-Referer': 'https://github.com/CxOrg/openrouter-mcp',
    'X-Title': 'Docan',
  };

  @override
  Future<List<String>> getAvailableModels() async {
    if (apiKey.isEmpty) {
      return AIProvider.openrouter.availableModels;
    }

    try {
      final url = Uri.parse('$baseUrl/models');
      final response = await http.get(url, headers: authHeaders);

      if (response.statusCode != 200) {
        debugPrint(
          '[$logTag] Failed to fetch models: ${response.statusCode}',
        );
        return AIProvider.openrouter.availableModels;
      }

      final data = jsonDecode(response.body);
      final models = data['data'] as List<dynamic>?;

      if (models == null || models.isEmpty) {
        return AIProvider.openrouter.availableModels;
      }

      // Keep all models (ids are "vendor/model"); sort for the picker
      final availableModels = models
          .map((m) => m['id'] as String)
          .where((id) => id.isNotEmpty)
          .toList()
        ..sort();

      debugPrint('[OpenRouter] Found ${availableModels.length} models');
      return availableModels.isEmpty
          ? AIProvider.openrouter.availableModels
          : availableModels;
    } catch (e) {
      debugPrint('[OpenRouter] Error fetching models: $e');
      return AIProvider.openrouter.availableModels;
    }
  }
}
