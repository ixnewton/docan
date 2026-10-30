import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/ai_provider.dart';
import '../models/usage_stats.dart';
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
  Map<String, dynamic> get extraBodyParams => {
    'usage': {'include': true},
  };

  Map<String, ModelPricing>? _pricing;
  CreditBalance? _keyInfo;

  /// Well-known vendor domains used to fetch favicon icons for the vendor
  /// menu. Vendors missing from this map fall back to a generic icon.
  static const Map<String, String> _vendorDomains = {
    'amazon': 'amazon.com',
    'anthropic': 'anthropic.com',
    'arcee-ai': 'arcee.ai',
    'baidu': 'baidu.com',
    'bytedance': 'bytedance.com',
    'cohere': 'cohere.com',
    'deepseek': 'deepseek.com',
    'fireworks': 'fireworks.ai',
    'google': 'google.com',
    'ibm-granite': 'ibm.com',
    'liquid': 'liquid.ai',
    'meituan': 'meituan.com',
    'meta': 'meta.com',
    'meta-llama': 'meta.com',
    'microsoft': 'microsoft.com',
    'minimax': 'minimax.io',
    'mistralai': 'mistral.ai',
    'moonshotai': 'moonshot.ai',
    'nousresearch': 'nousresearch.com',
    'nvidia': 'nvidia.com',
    'openai': 'openai.com',
    'openrouter': 'openrouter.ai',
    'perplexity': 'perplexity.ai',
    'qwen': 'qwen.ai',
    'rekaai': 'reka.ai',
    'stepfun': 'stepfun.com',
    'tencent': 'tencent.com',
    'upstage': 'upstage.ai',
    'writer': 'writer.com',
    'x-ai': 'x.ai',
    'xiaomi': 'xiaomi.com',
    'z-ai': 'z.ai',
  };

  /// Favicon URL for a vendor slug, or null when unknown.
  /// "~"-prefixed special vendors map to their base vendor.
  static String? vendorIconUrl(String vendor) {
    final domain = _vendorDomains[vendor] ??
        _vendorDomains[vendor.replaceFirst('~', '')];
    if (domain == null) return null;
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
  }

  Map<String, String>? _vendorIcons;

  /// Map of vendor slug -> favicon URL for every known vendor.
  /// Pass a pre-fetched model list to avoid a second API call.
  Future<Map<String, String>> getVendorIcons([List<String>? models]) async {
    if (_vendorIcons != null) return _vendorIcons!;
    models ??= await getAvailableModels();
    final icons = <String, String>{};
    for (final model in models) {
      final vendor = model.split('/').first;
      if (icons.containsKey(vendor)) continue;
      final url = vendorIconUrl(vendor);
      if (url != null) icons[vendor] = url;
    }
    _vendorIcons = icons;
    return icons;
  }

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

      _pricing = {};
      for (final m in models) {
        final id = m['id'];
        final pricing = parseModelPricing(m as Map<String, dynamic>);
        if (id is String && id.isNotEmpty && pricing != null) {
          _pricing![id] = pricing;
        }
      }

      debugPrint('[OpenRouter] Found ${availableModels.length} models');
      return availableModels.isEmpty
          ? AIProvider.openrouter.availableModels
          : availableModels;
    } catch (e) {
      debugPrint('[OpenRouter] Error fetching models: $e');
      return AIProvider.openrouter.availableModels;
    }
  }

  /// Per-token pricing for every model, from the live /models response.
  Future<Map<String, ModelPricing>> getModelPricing() async {
    if (_pricing == null) {
      await getAvailableModels();
    }
    return _pricing ?? const {};
  }

  void resetCaches() {
    _pricing = null;
    _keyInfo = null;
    _vendorIcons = null;
  }

  /// Credit balance for the API key, from GET /key (OpenRouter).
  /// Returns null when unavailable or when no spending limit is set.
  Future<CreditBalance?> getKeyInfo() async {
    if (_keyInfo != null) return _keyInfo;
    if (apiKey.isEmpty) return null;
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/key'), headers: authHeaders);
      if (response.statusCode != 200) {
        debugPrint('[$logTag] Failed to fetch key info: ${response.statusCode}');
        return null;
      }
      final body = jsonDecode(response.body);
      final data = body['data'];
      if (data is! Map<String, dynamic>) return null;
      _keyInfo = parseKeyInfo(data);
      return _keyInfo;
    } catch (e) {
      debugPrint('[OpenRouter] Error fetching key info: $e');
      return null;
    }
  }

  /// Parses a /key data payload into a CreditBalance.
  static CreditBalance? parseKeyInfo(Map<String, dynamic> data) {
    double? asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    final used = asDouble(data['usage']);
    if (used == null) return null;
    final limit = asDouble(data['limit']);
    return CreditBalance(used: used, limit: limit);
  }

  /// Parses a /models entry's pricing block (USD per token, as strings)
  /// into per-million rates. Returns null when pricing is absent/invalid.
  static ModelPricing? parseModelPricing(Map<String, dynamic> model) {
    final pricing = model['pricing'];
    if (pricing is! Map<String, dynamic>) return null;
    final prompt = double.tryParse(pricing['prompt']?.toString() ?? '');
    final completion = double.tryParse(pricing['completion']?.toString() ?? '');
    if (prompt == null || completion == null) return null;
    return ModelPricing(
      promptPerMillion: prompt * 1000000,
      completionPerMillion: completion * 1000000,
    );
  }
}
