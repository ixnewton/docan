import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/ai_provider.dart';
import '../utils/api_error_parser.dart';
import 'storage_service.dart';

/// Image provider for image generation
enum ImageGenProvider { gemini, openai }

/// Extension methods for ImageGenProvider
extension ImageGenProviderExtension on ImageGenProvider {
  String get displayName {
    switch (this) {
      case ImageGenProvider.gemini:
        return 'Gemini';
      case ImageGenProvider.openai:
        return 'DALL-E';
    }
  }

  String get description {
    switch (this) {
      case ImageGenProvider.gemini:
        return 'Google Gemini Image Generation';
      case ImageGenProvider.openai:
        return 'OpenAI DALL-E';
    }
  }

  /// Fallback models when API fetch fails
  List<String> get fallbackModels {
    switch (this) {
      case ImageGenProvider.gemini:
        return ['gemini-2.0-flash-exp-image-generation'];
      case ImageGenProvider.openai:
        return ['dall-e-3', 'dall-e-2', 'gpt-image-1'];
    }
  }

  String get defaultModel {
    switch (this) {
      case ImageGenProvider.gemini:
        return 'gemini-2.0-flash-exp-image-generation';
      case ImageGenProvider.openai:
        return 'dall-e-3';
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

/// Image generation service
class ImageGenerationService extends ChangeNotifier {
  final StorageService _storage;

  ImageGenProvider _selectedProvider = ImageGenProvider.gemini;
  String _selectedModel = ImageGenProvider.gemini.defaultModel;
  bool _isGenerating = false;
  String? _error;
  List<GeneratedImage> _generatedImages = [];

  ImageGenerationService(this._storage);

  // Getters
  ImageGenProvider get selectedProvider => _selectedProvider;
  String get selectedModel => _selectedModel;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  List<GeneratedImage> get generatedImages => _generatedImages;

  /// Initialize the service
  Future<void> initialize() async {
    // Load any saved settings if needed
    notifyListeners();
  }

  /// Set the selected provider
  void setProvider(ImageGenProvider provider) {
    _selectedProvider = provider;
    _selectedModel = provider.defaultModel;
    notifyListeners();
  }

  /// Set the selected model
  void setModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  /// Get configured providers (has API key)
  Future<Map<ImageGenProvider, bool>> getConfiguredProviders() async {
    final result = <ImageGenProvider, bool>{};
    for (final provider in ImageGenProvider.values) {
      final aiProvider = provider == ImageGenProvider.gemini
          ? AIProvider.gemini
          : AIProvider.openai;
      final hasKey = await _storage.hasApiKey(aiProvider);
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
    }
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
