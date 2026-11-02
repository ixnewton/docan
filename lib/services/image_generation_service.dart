import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/ai_provider.dart';
import '../models/usage_stats.dart';
import '../utils/api_error_parser.dart';
import 'storage_service.dart';

/// Image provider for image generation
enum ImageGenProvider { gemini, openai, comfyui, openrouter }

/// Extension methods for ImageGenProvider
extension ImageGenProviderExtension on ImageGenProvider {
  String get displayName {
    switch (this) {
      case ImageGenProvider.gemini:
        return 'Gemini';
      case ImageGenProvider.openai:
        return 'DALL-E';
      case ImageGenProvider.comfyui:
        return 'ComfyUI';
      case ImageGenProvider.openrouter:
        return 'OpenRouter';
    }
  }

  String get description {
    switch (this) {
      case ImageGenProvider.gemini:
        return 'Google Gemini Image Generation';
      case ImageGenProvider.openai:
        return 'OpenAI DALL-E';
      case ImageGenProvider.comfyui:
        return 'ComfyUI Local Image Generation';
      case ImageGenProvider.openrouter:
        return 'OpenRouter image-capable models';
    }
  }

  /// Fallback models when API fetch fails
  List<String> get fallbackModels {
    switch (this) {
      case ImageGenProvider.gemini:
        return ['gemini-2.0-flash-exp-image-generation'];
      case ImageGenProvider.openai:
        return ['dall-e-3', 'dall-e-2', 'gpt-image-1'];
      case ImageGenProvider.comfyui:
        return ['default'];
      case ImageGenProvider.openrouter:
        return [
          'google/gemini-nano-banana-2.1',
          'google/gemini-2.5-flash-image',
        ];
    }
  }

  String get defaultModel {
    switch (this) {
      case ImageGenProvider.gemini:
        return 'gemini-2.0-flash-exp-image-generation';
      case ImageGenProvider.openai:
        return 'dall-e-3';
      case ImageGenProvider.comfyui:
        return 'default';
      case ImageGenProvider.openrouter:
        return 'google/gemini-nano-banana-2.1';
    }
  }

  /// Whether this provider requires a URL instead of an API key
  bool get requiresUrl {
    return this == ImageGenProvider.comfyui;
  }

  /// Icon for the provider
  IconData get icon {
    switch (this) {
      case ImageGenProvider.gemini:
        return Icons.auto_awesome;
      case ImageGenProvider.openai:
        return Icons.palette;
      case ImageGenProvider.comfyui:
        return Icons.brush;
      case ImageGenProvider.openrouter:
        return Icons.hub_outlined;
    }
  }
}

/// Generated image result
class GeneratedImage {
  final String id;
  final String prompt;
  final Uint8List imageData;
  final String mimeType;
  final DateTime timestamp;
  final ImageGenProvider provider;
  final String model;
  final String? revisedPrompt;

  GeneratedImage({
    String? id,
    required this.prompt,
    required this.imageData,
    this.mimeType = 'image/png',
    DateTime? timestamp,
    required this.provider,
    required this.model,
    this.revisedPrompt,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  String get base64Data => base64Encode(imageData);
}

/// ComfyUI generation settings
class ComfyUISettings {
  final int steps;
  final double cfgScale;
  final int width;
  final int height;
  final int seed;
  final String sampler;
  final String scheduler;
  final String negativePrompt;
  final double denoise;

  const ComfyUISettings({
    this.steps = 20,
    this.cfgScale = 7.0,
    this.width = 512,
    this.height = 512,
    this.seed = -1, // -1 means random
    this.sampler = 'euler',
    this.scheduler = 'normal',
    this.negativePrompt = 'bad quality, blurry, distorted',
    this.denoise = 1.0,
  });

  ComfyUISettings copyWith({
    int? steps,
    double? cfgScale,
    int? width,
    int? height,
    int? seed,
    String? sampler,
    String? scheduler,
    String? negativePrompt,
    double? denoise,
  }) {
    return ComfyUISettings(
      steps: steps ?? this.steps,
      cfgScale: cfgScale ?? this.cfgScale,
      width: width ?? this.width,
      height: height ?? this.height,
      seed: seed ?? this.seed,
      sampler: sampler ?? this.sampler,
      scheduler: scheduler ?? this.scheduler,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      denoise: denoise ?? this.denoise,
    );
  }

  /// Available samplers in ComfyUI
  static const List<String> availableSamplers = [
    'euler',
    'euler_ancestral',
    'heun',
    'heunpp2',
    'dpm_2',
    'dpm_2_ancestral',
    'lms',
    'dpm_fast',
    'dpm_adaptive',
    'dpmpp_2s_ancestral',
    'dpmpp_sde',
    'dpmpp_sde_gpu',
    'dpmpp_2m',
    'dpmpp_2m_sde',
    'dpmpp_2m_sde_gpu',
    'dpmpp_3m_sde',
    'dpmpp_3m_sde_gpu',
    'ddpm',
    'lcm',
    'ddim',
    'uni_pc',
    'uni_pc_bh2',
  ];

  /// Available schedulers in ComfyUI
  static const List<String> availableSchedulers = [
    'normal',
    'karras',
    'exponential',
    'sgm_uniform',
    'simple',
    'ddim_uniform',
    'beta',
  ];

  /// Common resolution presets
  static const List<Map<String, int>> resolutionPresets = [
    {'width': 512, 'height': 512},
    {'width': 768, 'height': 768},
    {'width': 1024, 'height': 1024},
    {'width': 512, 'height': 768},
    {'width': 768, 'height': 512},
    {'width': 768, 'height': 1024},
    {'width': 1024, 'height': 768},
    {'width': 1024, 'height': 1536},
    {'width': 1536, 'height': 1024},
  ];
}

/// Image size options
enum ImageSize { small, medium, large, hd }

extension ImageSizeExtension on ImageSize {
  String get displayName {
    switch (this) {
      case ImageSize.small:
        return '256x256';
      case ImageSize.medium:
        return '512x512';
      case ImageSize.large:
        return '1024x1024';
      case ImageSize.hd:
        return '1792x1024';
    }
  }

  String get dalleSize {
    switch (this) {
      case ImageSize.small:
        return '256x256';
      case ImageSize.medium:
        return '512x512';
      case ImageSize.large:
        return '1024x1024';
      case ImageSize.hd:
        return '1792x1024';
    }
  }
}

/// A saved image recorded in the image history
class SavedImageRecord {
  final String fileName;
  final String prompt;
  final String provider;
  final String model;
  final DateTime savedAt;

  const SavedImageRecord({
    required this.fileName,
    required this.prompt,
    required this.provider,
    required this.model,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'prompt': prompt,
    'provider': provider,
    'model': model,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  factory SavedImageRecord.fromJson(Map<String, dynamic> json) {
    return SavedImageRecord(
      fileName: json['fileName']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['savedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  static List<SavedImageRecord> listFromJson(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SavedImageRecord.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String listToJson(List<SavedImageRecord> records) {
    return jsonEncode(records.map((r) => r.toJson()).toList());
  }
}

/// Image generation service
class ImageGenerationService extends ChangeNotifier {
  final StorageService _storage;

  ImageGenProvider _selectedProvider = ImageGenProvider.gemini;
  String _selectedModel = ImageGenProvider.gemini.defaultModel;
  bool _isGenerating = false;
  String? _error;
  final List<GeneratedImage> _generatedImages = [];
  ComfyUISettings _comfyUISettings = const ComfyUISettings();
  Map<String, Map<String, UsageStats>> _imageUsage = {};
  List<SavedImageRecord> _imageHistory = [];
  String? _saveFolderOverride;

  /// Billed cost of the most recent generation (null when not reported)
  double? lastGenerationCost;

  ImageGenerationService(this._storage);

  // Getters
  ImageGenProvider get selectedProvider => _selectedProvider;
  String get selectedModel => _selectedModel;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  List<GeneratedImage> get generatedImages => _generatedImages;
  ComfyUISettings get comfyUISettings => _comfyUISettings;

  /// Initialize the service
  Future<void> initialize() async {
    final savedName = await _storage.getImageProvider();
    final savedProvider = ImageGenProvider.values
        .where((p) => p.name == savedName)
        .firstOrNull;
    if (savedProvider != null) {
      _selectedProvider = savedProvider;
      _selectedModel =
          await _storage.getImageModelForProvider(savedProvider.name) ??
          savedProvider.defaultModel;
    }
    _imageUsage = usageStatsFromJson(
      await _storage.getImageUsageStats() ?? '',
    );
    _imageHistory = List.of(
      SavedImageRecord.listFromJson(
        await _storage.getImageHistory() ?? '',
      ),
    );
    _saveFolderOverride = await _storage.getImageSaveFolder();
    final trimmed = _saveFolderOverride?.trim();
    _saveFolderOverride =
        (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    notifyListeners();
  }

  /// Set the selected provider (remembers the provider's last-used model)
  Future<void> setProvider(ImageGenProvider provider) async {
    _selectedProvider = provider;
    _selectedModel =
        await _storage.getImageModelForProvider(provider.name) ??
        provider.defaultModel;
    await _storage.setImageProvider(provider.name);
    await _storage.setImageModelForProvider(provider.name, _selectedModel);
    notifyListeners();
  }

  /// Set the selected model (persisted per provider)
  Future<void> setModel(String model) async {
    _selectedModel = model;
    await _storage.setImageModelForProvider(_selectedProvider.name, model);
    notifyListeners();
  }

  /// Update ComfyUI settings
  void updateComfyUISettings(ComfyUISettings settings) {
    _comfyUISettings = settings;
    notifyListeners();
  }

  void _recordImageUsage(Map<String, dynamic> usage) {
    final cost = (usage['cost'] as num?)?.toDouble();
    lastGenerationCost = cost;
    final tokenUsage = TokenUsage(
      promptTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (usage['total_tokens'] as num?)?.toInt() ?? 0,
      costUsd: cost,
    );
    if (tokenUsage.totalTokens == 0 && cost == null) return;
    final models = _imageUsage.putIfAbsent(_selectedProvider.name, () => {});
    final stats = models.putIfAbsent(_selectedModel, () => UsageStats());
    stats.add(tokenUsage);
    _storage.setImageUsageStats(usageStatsToJson(_imageUsage));
  }

  /// Aggregated image-generation usage for a provider across its models
  UsageStats? imageUsageForProvider(ImageGenProvider provider) {
    final models = _imageUsage[provider.name];
    if (models == null || models.isEmpty) return null;
    final total = UsageStats();
    for (final stats in models.values) {
      total.addAll(stats);
    }
    return total;
  }

  // Saved-image history

  /// Saved-image records in creation order (oldest first)
  List<SavedImageRecord> get imageHistory =>
      List.unmodifiable(_imageHistory);

  /// The configured save folder override (null = default Documents/Docan)
  String? get saveFolderOverride => _saveFolderOverride;

  Future<void> setSaveFolderOverride(String? path) async {
    _saveFolderOverride = (path != null && path.trim().isEmpty)
        ? null
        : path;
    if (_saveFolderOverride != null) {
      await _storage.setImageSaveFolder(_saveFolderOverride!);
    } else {
      await _storage.setImageSaveFolder('');
    }
    notifyListeners();
  }

  /// Resolves the save folder: the settings override when set, otherwise
  /// ~/Documents/Docan (created when missing)
  Future<String> resolveSaveFolder() async {
    String base;
    if (_saveFolderOverride != null) {
      base = _saveFolderOverride!;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      base = '${docs.path}${Platform.pathSeparator}Docan';
    }
    final dir = Directory(base);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return base;
  }

  /// Saves an image into the resolved save folder and records it in the
  /// history (file name + prompt, in creation order). Returns the path.
  Future<String> saveImageToHistory(GeneratedImage image) async {
    final folder = await resolveSaveFolder();
    final fileName = 'docan_image_${DateTime.now().millisecondsSinceEpoch}.png';
    final filePath = '$folder${Platform.pathSeparator}$fileName';
    await File(filePath).writeAsBytes(image.imageData);

    _imageHistory.add(
      SavedImageRecord(
        fileName: fileName,
        prompt: image.prompt,
        provider: image.provider.name,
        model: image.model,
        savedAt: DateTime.now(),
      ),
    );
    await _storage.setImageHistory(
      SavedImageRecord.listToJson(_imageHistory),
    );
    notifyListeners();
    return filePath;
  }

  /// History records grouped by calendar day, newest day first. Records
  /// whose file is missing from the save folder are dropped.
  Future<Map<DateTime, List<SavedImageRecord>>> historyByDay({
    String? folder,
  }) async {
    final resolvedFolder = folder ?? await resolveSaveFolder();
    DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
    final groups = <DateTime, List<SavedImageRecord>>{};
    for (final record in _imageHistory) {
      if (!File('$resolvedFolder${Platform.pathSeparator}${record.fileName}')
          .existsSync()) {
        continue;
      }
      groups.putIfAbsent(dayKey(record.savedAt), () => []).add(record);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final key in sortedKeys) key: groups[key]!};
  }

  /// Get configured providers (has API key)
  Future<Map<ImageGenProvider, bool>> getConfiguredProviders() async {
    final result = <ImageGenProvider, bool>{};
    for (final provider in ImageGenProvider.values) {
      bool hasKey;
      if (provider == ImageGenProvider.comfyui) {
        hasKey = await _storage.hasComfyUIUrl();
      } else {
        final aiProvider = switch (provider) {
          ImageGenProvider.gemini => AIProvider.gemini,
          ImageGenProvider.openai => AIProvider.openai,
          ImageGenProvider.openrouter => AIProvider.openrouter,
          _ => AIProvider.gemini,
        };
        hasKey = await _storage.hasApiKey(aiProvider);
      }
      result[provider] = hasKey;
    }
    return result;
  }

  /// Get available models for a provider (fetches from API)
  Future<List<String>> getAvailableModels(ImageGenProvider provider) async {
    switch (provider) {
      case ImageGenProvider.gemini:
        return _fetchGeminiImageModels();
      case ImageGenProvider.openai:
        return _fetchOpenAIImageModels();
      case ImageGenProvider.comfyui:
        return _fetchComfyUIWorkflows();
      case ImageGenProvider.openrouter:
        return _fetchOpenRouterImageModels();
    }
  }

  /// Fetch OpenRouter image models. Primary: GET /images/models — the
  /// authoritative list of models the Image API serves (the same set as
  /// OpenRouter's image-models collection). Fallback: /models filtered to
  /// image output modalities (chat-completions image models).
  Future<List<String>> _fetchOpenRouterImageModels() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConstants.openRouterBaseUrl}/images/models'))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['data'] as List<dynamic>?;
        if (models != null) {
          final ids = models
              .whereType<Map<String, dynamic>>()
              .map((m) => m['id'])
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList()
            ..sort();
          if (ids.isNotEmpty) return ids;
        }
      }
      debugPrint(
        '[ImageGen] /images/models unavailable (${response.statusCode}); '
        'falling back to /models filtering',
      );
    } catch (e) {
      debugPrint('[ImageGen] Error fetching /images/models: $e');
    }

    final apiKey = await _storage.getApiKey(AIProvider.openrouter);
    if (apiKey == null || apiKey.isEmpty) {
      return ImageGenProvider.openrouter.fallbackModels;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.openRouterBaseUrl}/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[ImageGen] Failed to fetch OpenRouter models: ${response.statusCode}',
        );
        return ImageGenProvider.openrouter.fallbackModels;
      }

      final data = jsonDecode(response.body);
      final models = data['data'] as List<dynamic>?;
      if (models == null) {
        return ImageGenProvider.openrouter.fallbackModels;
      }

      final imageModels = filterImageModels(models)..sort();
      return imageModels.isEmpty
          ? ImageGenProvider.openrouter.fallbackModels
          : imageModels;
    } catch (e) {
      debugPrint('[ImageGen] Error fetching OpenRouter models: $e');
      return ImageGenProvider.openrouter.fallbackModels;
    }
  }

  /// Filters a /models payload to image-capable model ids
  static List<String> filterImageModels(List<dynamic> models) {
    return models
        .whereType<Map<String, dynamic>>()
        .where((m) {
          final arch = m['architecture'];
          final modalities =
              arch is Map<String, dynamic> ? arch['output_modalities'] : null;
          return modalities is List && modalities.contains('image');
        })
        .map((m) => m['id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Extracts an inline base64 image from a model response that embeds it
  /// as a markdown data URL. Returns (mimeType, base64) or null.
  static (String, String)? extractImageData(String content) {
    final match = RegExp(
      r'!\[[^\]]*\]\(data:image/([a-zA-Z0-9.+-]+);base64,([A-Za-z0-9+/=]+)\)',
    ).firstMatch(content);
    if (match == null) return null;
    return (match.group(1)!, match.group(2)!);
  }

  /// Fetch available Gemini image models from API
  Future<List<String>> _fetchGeminiImageModels() async {
    final apiKey = await _storage.getApiKey(AIProvider.gemini);
    if (apiKey == null || apiKey.isEmpty) {
      return ImageGenProvider.gemini.fallbackModels;
    }

    try {
      final url = Uri.parse(
        '${AppConstants.geminiBaseUrl}/models?key=$apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('[ImageGen] Failed to fetch Gemini models: ${response.statusCode}');
        return ImageGenProvider.gemini.fallbackModels;
      }

      final data = jsonDecode(response.body);
      final models = data['models'] as List<dynamic>?;

      if (models == null || models.isEmpty) {
        return ImageGenProvider.gemini.fallbackModels;
      }

      // Filter to only include image generation capable models
      final imageModels = models
          .where((m) {
            final methods = m['supportedGenerationMethods'] as List<dynamic>?;
            final name = (m['name'] as String?)?.toLowerCase() ?? '';
            // Include models that support generateContent and have 'image' in name
            // or are known image generation models
            return (methods?.contains('generateContent') ?? false) &&
                (name.contains('image') || name.contains('imagen'));
          })
          .map((m) {
            final name = m['name'] as String;
            return name.startsWith('models/') ? name.substring(7) : name;
          })
          .toList();

      debugPrint('[ImageGen] Found ${imageModels.length} Gemini image models');
      return imageModels.isEmpty
          ? ImageGenProvider.gemini.fallbackModels
          : imageModels;
    } catch (e) {
      debugPrint('[ImageGen] Error fetching Gemini models: $e');
      return ImageGenProvider.gemini.fallbackModels;
    }
  }

  /// Fetch available OpenAI image models from API
  Future<List<String>> _fetchOpenAIImageModels() async {
    final apiKey = await _storage.getApiKey(AIProvider.openai);
    if (apiKey == null || apiKey.isEmpty) {
      return ImageGenProvider.openai.fallbackModels;
    }

    try {
      final url = Uri.parse('${AppConstants.openAIBaseUrl}/models');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode != 200) {
        debugPrint('[ImageGen] Failed to fetch OpenAI models: ${response.statusCode}');
        return ImageGenProvider.openai.fallbackModels;
      }

      final data = jsonDecode(response.body);
      final models = data['data'] as List<dynamic>?;

      if (models == null || models.isEmpty) {
        return ImageGenProvider.openai.fallbackModels;
      }

      // Filter to only include DALL-E and image models
      final imageModels = models
          .map((m) => m['id'] as String)
          .where((id) => id.contains('dall-e') || id.contains('image'))
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Sort descending (newer first)

      debugPrint('[ImageGen] Found ${imageModels.length} OpenAI image models');
      return imageModels.isEmpty
          ? ImageGenProvider.openai.fallbackModels
          : imageModels;
    } catch (e) {
      debugPrint('[ImageGen] Error fetching OpenAI models: $e');
      return ImageGenProvider.openai.fallbackModels;
    }
  }

  /// Generate an image
  Future<GeneratedImage?> generateImage(
    String prompt, {
    ImageSize size = ImageSize.large,
  }) async {
    if (prompt.trim().isEmpty) {
      _error = 'Please enter a prompt';
      notifyListeners();
      return null;
    }

    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      GeneratedImage? image;

      switch (_selectedProvider) {
        case ImageGenProvider.gemini:
          image = await _generateWithGemini(prompt, size);
          break;
        case ImageGenProvider.openai:
          image = await _generateWithOpenAI(prompt, size);
          break;
        case ImageGenProvider.comfyui:
          image = await _generateWithComfyUI(prompt, size);
          break;
        case ImageGenProvider.openrouter:
          image = await _generateWithOpenRouter(prompt, size);
          break;
      }

      if (image != null) {
        _generatedImages.insert(0, image);
      }

      _isGenerating = false;
      notifyListeners();
      return image;
    } catch (e) {
      _error = e.toString();
      _isGenerating = false;
      notifyListeners();
      return null;
    }
  }

  /// Generate image with Gemini
  Future<GeneratedImage?> _generateWithGemini(
    String prompt,
    ImageSize size,
  ) async {
    final apiKey = await _storage.getApiKey(AIProvider.gemini);
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key not set');
    }

    final url = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$_selectedModel:generateContent?key=$apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['TEXT', 'IMAGE'],
      },
    });

    debugPrint('[ImageGen] Sending request to Gemini...');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    debugPrint('[ImageGen] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      final errorMessage = error['error']?['message'] ?? 'Gemini API error';
      throw Exception(ApiErrorParser.parse(errorMessage, response.statusCode));
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    final content = candidates[0]['content'];
    final parts = content['parts'] as List<dynamic>;

    // Find image data
    for (final part in parts) {
      if (part['inlineData'] != null || part['inline_data'] != null) {
        final inlineData = part['inlineData'] ?? part['inline_data'];
        final mimeType =
            inlineData['mimeType'] ?? inlineData['mime_type'] ?? 'image/png';
        final imageDataStr = inlineData['data'] as String;
        final imageData = base64Decode(imageDataStr);

        return GeneratedImage(
          prompt: prompt,
          imageData: imageData,
          mimeType: mimeType,
          provider: ImageGenProvider.gemini,
          model: _selectedModel,
        );
      }
    }

    throw Exception('No image generated');
  }

  /// Generate image with OpenAI DALL-E
  Future<GeneratedImage?> _generateWithOpenAI(
    String prompt,
    ImageSize size,
  ) async {
    final apiKey = await _storage.getApiKey(AIProvider.openai);
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API key not set');
    }

    final url = Uri.parse('${AppConstants.openAIBaseUrl}/images/generations');

    // DALL-E 2 only supports 256x256, 512x512, 1024x1024
    // DALL-E 3 supports 1024x1024, 1792x1024, 1024x1792
    String dalleSize;
    if (_selectedModel == 'dall-e-3') {
      dalleSize = size == ImageSize.hd ? '1792x1024' : '1024x1024';
    } else {
      dalleSize = size == ImageSize.small
          ? '256x256'
          : size == ImageSize.medium
          ? '512x512'
          : '1024x1024';
    }

    final body = jsonEncode({
      'model': _selectedModel,
      'prompt': prompt,
      'n': 1,
      'size': dalleSize,
      'response_format': 'b64_json',
    });

    debugPrint('[ImageGen] Sending request to OpenAI DALL-E...');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    debugPrint('[ImageGen] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      final errorMessage = error['error']?['message'] ?? 'OpenAI API error';
      throw Exception(ApiErrorParser.parse(errorMessage, response.statusCode));
    }

    final data = jsonDecode(response.body);
    final images = data['data'] as List<dynamic>?;

    if (images == null || images.isEmpty) {
      throw Exception('No image generated');
    }

    final imageDataStr = images[0]['b64_json'] as String;
    final revisedPrompt = images[0]['revised_prompt'] as String?;
    final imageData = base64Decode(imageDataStr);

    return GeneratedImage(
      prompt: prompt,
      imageData: imageData,
      mimeType: 'image/png',
      provider: ImageGenProvider.openai,
      model: _selectedModel,
      revisedPrompt: revisedPrompt,
    );
  }

  /// Fetch available ComfyUI checkpoints/models
  Future<List<String>> _fetchComfyUIWorkflows() async {
    final baseUrl = await _storage.getComfyUIUrl();
    if (baseUrl.isEmpty) {
      return ImageGenProvider.comfyui.fallbackModels;
    }

    try {
      // Fetch object_info to get available checkpoints
      final url = Uri.parse('$baseUrl/object_info/CheckpointLoaderSimple');
      debugPrint('[ImageGen] Fetching ComfyUI checkpoints from $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.statusCode != 200) {
        debugPrint('[ImageGen] ComfyUI object_info failed: ${response.statusCode}');
        return ImageGenProvider.comfyui.fallbackModels;
      }

      final data = jsonDecode(response.body);
      final checkpointLoader = data['CheckpointLoaderSimple'];
      if (checkpointLoader == null) {
        debugPrint('[ImageGen] CheckpointLoaderSimple not found in response');
        return ImageGenProvider.comfyui.fallbackModels;
      }

      final input = checkpointLoader['input'];
      final required = input?['required'];
      final ckptName = required?['ckpt_name'];
      
      if (ckptName != null && ckptName is List && ckptName.isNotEmpty) {
        final checkpoints = ckptName[0];
        if (checkpoints is List) {
          final models = checkpoints.cast<String>().toList();
          debugPrint('[ImageGen] Found ${models.length} ComfyUI checkpoints');
          return models.isEmpty ? ImageGenProvider.comfyui.fallbackModels : models;
        }
      }

      debugPrint('[ImageGen] Could not parse ComfyUI checkpoints');
      return ImageGenProvider.comfyui.fallbackModels;
    } catch (e) {
      debugPrint('[ImageGen] Error fetching ComfyUI checkpoints: $e');
      return ImageGenProvider.comfyui.fallbackModels;
    }
  }

  /// Generate image via OpenRouter. Primary path: the dedicated /images
  /// endpoint (returns b64_json plus billed cost). Fallback: chat
  /// completions, which returns the image in message.images.
  Future<GeneratedImage?> _generateWithOpenRouter(
    String prompt,
    ImageSize size,
  ) async {
    final apiKey = await _storage.getApiKey(AIProvider.openrouter);
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key not set');
    }

    debugPrint('[ImageGen] OpenRouter generating with $_selectedModel...');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'https://github.com/CxOrg/openrouter-mcp',
      'X-Title': 'Docan',
    };

    http.Response response = await http
        .post(
          Uri.parse('${AppConstants.openRouterBaseUrl}/images'),
          headers: headers,
          body: jsonEncode({
            'model': _selectedModel,
            'prompt': prompt,
            'aspect_ratio': size == ImageSize.hd ? '16:9' : '1:1',
          }),
        )
        .timeout(const Duration(minutes: 3));

    // Some models are not routed through /images — fall back to chat
    // completions, which returns the image in message.images
    if (response.statusCode == 404 || response.statusCode == 400) {
      debugPrint(
        '[ImageGen] /images unsupported (${response.statusCode}); '
        'trying chat completions',
      );
      response = await http
          .post(
            Uri.parse('${AppConstants.openRouterBaseUrl}/chat/completions'),
            headers: headers,
            body: jsonEncode({
              'model': _selectedModel,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
              'modalities': ['image', 'text'],
              'usage': {'include': true},
            }),
          )
          .timeout(const Duration(minutes: 3));
    }

    debugPrint('[ImageGen] OpenRouter response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      String errorMessage = 'OpenRouter API error';
      try {
        final error = jsonDecode(response.body);
        errorMessage = error['error']?['message'] ?? errorMessage;
      } catch (_) {}
      throw Exception(
        ApiErrorParser.parse(errorMessage, response.statusCode),
      );
    }

    final data = jsonDecode(response.body);
    final (mimeType, base64Data) = extractOpenRouterImage(data);
    if (base64Data == null || base64Data.isEmpty) {
      throw Exception('The model did not return an image');
    }

    final usage = data['usage'];
    if (usage is Map<String, dynamic>) {
      _recordImageUsage(usage);
    }

    return GeneratedImage(
      prompt: prompt,
      imageData: base64Decode(base64Data),
      mimeType: mimeType,
      provider: ImageGenProvider.openrouter,
      model: _selectedModel,
    );
  }

  /// Extracts (mimeType, base64) from an OpenRouter image response:
  /// /images returns data[0].b64_json; chat completions returns the image
  /// in message.images (image_url data URLs) or inline in the content.
  static (String, String?) extractOpenRouterImage(Map<String, dynamic> data) {
    final dataList = data['data'];
    if (dataList is List && dataList.isNotEmpty) {
      final first = dataList[0];
      final b64 = first is Map<String, dynamic>
          ? first['b64_json']?.toString()
          : null;
      if (b64 != null && b64.isNotEmpty) {
        return (detectImageMime(base64Decode(b64)), b64);
      }
    }

    dynamic message;
    if (data['choices'] is List && (data['choices'] as List).isNotEmpty) {
      final choice = (data['choices'] as List)[0];
      if (choice is Map<String, dynamic>) message = choice['message'];
    }
    if (message is Map<String, dynamic>) {
      final images = message['images'];
      if (images is List) {
        for (final image in images) {
          final url = image is Map<String, dynamic>
              ? (image['image_url'] is Map<String, dynamic>
                  ? image['image_url']['url']?.toString()
                  : null)
              : image?.toString();
          if (url != null && url.startsWith('data:image/')) {
            final parsed = parseDataUrl(url);
            if (parsed != null) return parsed;
          }
        }
      }
      final content = message['content'];
      if (content is String) {
        final extracted = extractImageData(content);
        if (extracted != null) return ('image/${extracted.$1}', extracted.$2);
      } else if (content is List) {
        for (final part in content) {
          if (part is! Map<String, dynamic>) continue;
          final url = part['image_url'] is Map<String, dynamic>
              ? part['image_url']['url']?.toString()
              : null;
          if (url != null && url.startsWith('data:image/')) {
            final parsed = parseDataUrl(url);
            if (parsed != null) return parsed;
          }
        }
      }
    }
    return ('image/png', null);
  }

  /// Parses a data URL into (full mime type, base64)
  static (String, String)? parseDataUrl(String url) {
    final match = RegExp(
      r'^data:image/([a-zA-Z0-9.+-]+);base64,(.+)$',
      dotAll: true,
    ).firstMatch(url);
    if (match == null) return null;
    return ('image/${match.group(1)!}', match.group(2)!);
  }

  /// Detects the image mime type from magic bytes
  static String detectImageMime(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif';
    }
    return 'image/png';
  }

  /// Generate image with ComfyUI
  Future<GeneratedImage?> _generateWithComfyUI(
    String prompt,
    ImageSize size,
  ) async {
    final baseUrl = await _storage.getComfyUIUrl();
    if (baseUrl.isEmpty) {
      throw Exception('ComfyUI URL not configured');
    }

    // Use ComfyUI settings for dimensions (ignore size parameter when using ComfyUI)
    final settings = _comfyUISettings;
    final width = settings.width;
    final height = settings.height;
    
    // Generate seed - use random if -1
    final seed = settings.seed == -1 
        ? DateTime.now().millisecondsSinceEpoch % 4294967295
        : settings.seed;

    // Create a txt2img workflow for ComfyUI using the settings
    final workflow = {
      "3": {
        "class_type": "KSampler",
        "inputs": {
          "cfg": settings.cfgScale,
          "denoise": settings.denoise,
          "latent_image": ["5", 0],
          "model": ["4", 0],
          "negative": ["7", 0],
          "positive": ["6", 0],
          "sampler_name": settings.sampler,
          "scheduler": settings.scheduler,
          "seed": seed,
          "steps": settings.steps
        }
      },
      "4": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": _selectedModel}
      },
      "5": {
        "class_type": "EmptyLatentImage",
        "inputs": {"batch_size": 1, "height": height, "width": width}
      },
      "6": {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": ["4", 1], "text": prompt}
      },
      "7": {
        "class_type": "CLIPTextEncode",
        "inputs": {
          "clip": ["4", 1],
          "text": settings.negativePrompt
        }
      },
      "8": {
        "class_type": "VAEDecode",
        "inputs": {"samples": ["3", 0], "vae": ["4", 2]}
      },
      "9": {
        "class_type": "SaveImage",
        "inputs": {"filename_prefix": "ComfyUI", "images": ["8", 0]}
      }
    };

    debugPrint('[ImageGen] ComfyUI Settings: steps=${settings.steps}, cfg=${settings.cfgScale}, '
        'size=${width}x$height, seed=$seed, sampler=${settings.sampler}, scheduler=${settings.scheduler}');

    try {
      // Queue the prompt
      final queueUrl = Uri.parse('$baseUrl/prompt');
      debugPrint('[ImageGen] Sending request to ComfyUI at $queueUrl...');

      final queueResponse = await http.post(
        queueUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': workflow}),
      );

      if (queueResponse.statusCode != 200) {
        debugPrint('[ImageGen] ComfyUI queue error: ${queueResponse.body}');
        throw Exception('ComfyUI error: ${queueResponse.statusCode}');
      }

      final queueData = jsonDecode(queueResponse.body);
      final promptId = queueData['prompt_id'] as String?;

      if (promptId == null) {
        throw Exception('Failed to queue prompt in ComfyUI');
      }

      debugPrint('[ImageGen] ComfyUI prompt queued: $promptId');

      // Poll for completion
      Uint8List? imageData;
      int attempts = 0;
      const maxAttempts = 120; // 2 minutes max

      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;

        final historyUrl = Uri.parse('$baseUrl/history/$promptId');
        final historyResponse = await http.get(historyUrl);

        if (historyResponse.statusCode == 200) {
          final historyData = jsonDecode(historyResponse.body);

          if (historyData[promptId] != null) {
            final outputs = historyData[promptId]['outputs'];
            if (outputs != null && outputs['9'] != null) {
              final images = outputs['9']['images'] as List<dynamic>?;
              if (images != null && images.isNotEmpty) {
                final imageInfo = images[0];
                final filename = imageInfo['filename'] as String;
                final subfolder = imageInfo['subfolder'] as String? ?? '';
                final type = imageInfo['type'] as String? ?? 'output';

                // Fetch the image
                final imageUrl = Uri.parse(
                  '$baseUrl/view?filename=$filename&subfolder=$subfolder&type=$type',
                );
                final imageResponse = await http.get(imageUrl);

                if (imageResponse.statusCode == 200) {
                  imageData = imageResponse.bodyBytes;
                  break;
                }
              }
            }
          }
        }
      }

      if (imageData == null) {
        throw Exception('ComfyUI generation timed out or failed');
      }

      return GeneratedImage(
        prompt: prompt,
        imageData: imageData,
        mimeType: 'image/png',
        provider: ImageGenProvider.comfyui,
        model: _selectedModel,
      );
    } catch (e) {
      debugPrint('[ImageGen] ComfyUI error: $e');
      rethrow;
    }
  }

  /// Clear generated images
  void clearImages() {
    _generatedImages.clear();
    notifyListeners();
  }

  /// Delete a specific image
  void deleteImage(String id) {
    _generatedImages.removeWhere((img) => img.id == id);
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
