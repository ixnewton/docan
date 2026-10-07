import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../config/constants.dart';
import '../models/conversation.dart';
import '../models/ai_provider.dart';

/// Service for managing local storage
class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;
  static FlutterSecureStorage? _secureStorage;
  static bool _secureStorageAvailable = true;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _prefs = await SharedPreferences.getInstance();
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        lOptions: LinuxOptions(),
      );

      // Test if secure storage is available with a write/read test
      try {
        const testKey = '_docan_storage_test';
        const testValue = 'test_value';
        await _secureStorage?.write(key: testKey, value: testValue);
        final readValue = await _secureStorage?.read(key: testKey);
        await _secureStorage?.delete(key: testKey);
        _secureStorageAvailable = readValue == testValue;
        if (!_secureStorageAvailable) {
          debugPrint(
            'Secure storage test failed (read mismatch), using fallback',
          );
        }
      } catch (e) {
        debugPrint(
          'Secure storage not available, falling back to shared preferences: $e',
        );
        _secureStorageAvailable = false;
      }

      // Migrate any existing keys from secure storage to shared prefs if secure storage is unavailable
      if (!_secureStorageAvailable) {
        await _migrateToSharedPrefs();
      }
    }
    return _instance!;
  }

  static Future<void> _migrateToSharedPrefs() async {
    // Try to read any existing keys from secure storage and migrate them
    try {
      final secureStorage = const FlutterSecureStorage(
        lOptions: LinuxOptions(),
      );
      for (final provider in AIProvider.values) {
        final key = _getStaticApiKeyStorageKey(provider);
        final value = await secureStorage.read(key: key);
        if (value != null && value.isNotEmpty) {
          await _prefs?.setString('_api_$key', value);
          debugPrint('Migrated $key to shared preferences');
        }
      }
    } catch (e) {
      debugPrint('Migration from secure storage failed (expected): $e');
    }
  }

  static String _getStaticApiKeyStorageKey(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return AppConstants.keyGeminiApiKey;
      case AIProvider.openai:
        return AppConstants.keyOpenAIApiKey;
      case AIProvider.claude:
        return AppConstants.keyClaudeApiKey;
      case AIProvider.deepseek:
        return AppConstants.keyDeepSeekApiKey;
      case AIProvider.ollama:
        return AppConstants.keyOllamaUrl;
      case AIProvider.lmstudio:
        return AppConstants.keyLMStudioUrl;
    }
  }

  // API Keys (Secure Storage with fallback)

  Future<void> setApiKey(AIProvider provider, String key) async {
    final storageKey = _getApiKeyStorageKey(provider);
    final fallbackKey = '_api_$storageKey';

    if (_secureStorageAvailable) {
      try {
        await _secureStorage?.write(key: storageKey, value: key);
        // Also save to shared prefs as backup
        await _prefs?.setString(fallbackKey, key);
        return;
      } catch (e) {
        debugPrint('Secure storage write failed, using fallback: $e');
        _secureStorageAvailable = false;
      }
    }
    // Fallback to shared preferences (less secure but works)
    await _prefs?.setString(fallbackKey, key);
  }

  Future<String?> getApiKey(AIProvider provider) async {
    final storageKey = _getApiKeyStorageKey(provider);
    final fallbackKey = '_api_$storageKey';

    if (_secureStorageAvailable) {
      try {
        final value = await _secureStorage?.read(key: storageKey);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      } catch (e) {
        debugPrint('Secure storage read failed, using fallback: $e');
        _secureStorageAvailable = false;
      }
    }
    // Fallback to shared preferences
    return _prefs?.getString(fallbackKey);
  }

  Future<void> deleteApiKey(AIProvider provider) async {
    final storageKey = _getApiKeyStorageKey(provider);
    if (_secureStorageAvailable) {
      try {
        await _secureStorage?.delete(key: storageKey);
        return;
      } catch (e) {
        debugPrint('Secure storage delete failed, using fallback: $e');
        _secureStorageAvailable = false;
      }
    }
    // Fallback to shared preferences
    await _prefs?.remove('_api_$storageKey');
  }

  Future<bool> hasApiKey(AIProvider provider) async {
    final key = await getApiKey(provider);
    return key != null && key.isNotEmpty;
  }

  String _getApiKeyStorageKey(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return AppConstants.keyGeminiApiKey;
      case AIProvider.openai:
        return AppConstants.keyOpenAIApiKey;
      case AIProvider.claude:
        return AppConstants.keyClaudeApiKey;
      case AIProvider.deepseek:
        return AppConstants.keyDeepSeekApiKey;
      case AIProvider.ollama:
        return AppConstants.keyOllamaUrl;
      case AIProvider.lmstudio:
        return AppConstants.keyLMStudioUrl;
    }
  }

  // Ollama URL

  Future<void> setOllamaUrl(String url) async {
    await _prefs?.setString(AppConstants.keyOllamaUrl, url);
  }

  Future<String> getOllamaUrl() async {
    return _prefs?.getString(AppConstants.keyOllamaUrl) ??
        AppConstants.ollamaDefaultUrl;
  }

  // LM Studio URL

  Future<void> setLMStudioUrl(String url) async {
    await _prefs?.setString(AppConstants.keyLMStudioUrl, url);
  }

  Future<String> getLMStudioUrl() async {
    return _prefs?.getString(AppConstants.keyLMStudioUrl) ??
        AppConstants.lmStudioDefaultUrl;
  }

  // ComfyUI URL

  Future<void> setComfyUIUrl(String url) async {
    await _prefs?.setString(AppConstants.keyComfyUIUrl, url);
  }

  Future<String> getComfyUIUrl() async {
    return _prefs?.getString(AppConstants.keyComfyUIUrl) ??
        AppConstants.comfyUIDefaultUrl;
  }

  Future<bool> hasComfyUIUrl() async {
    final url = await getComfyUIUrl();
    return url.isNotEmpty;
  }

  // Theme Settings

  Future<void> setTheme(String theme) async {
    await _prefs?.setString(AppConstants.keyThemeMode, theme);
  }

  Future<String> getTheme() async {
    final themeName = _prefs?.getString(AppConstants.keyThemeMode);
    return themeName ?? 'light';
  }

  // AI Parameters

  Future<void> setTemperature(double temperature) async {
    await _prefs?.setDouble(AppConstants.keyTemperature, temperature);
  }

  Future<double> getTemperature() async {
    return _prefs?.getDouble(AppConstants.keyTemperature) ??
        AppConstants.defaultTemperature;
  }

  Future<void> setMaxTokens(int maxTokens) async {
    await _prefs?.setInt(AppConstants.keyMaxTokens, maxTokens);
  }

  Future<int> getMaxTokens() async {
    return _prefs?.getInt(AppConstants.keyMaxTokens) ??
        AppConstants.defaultMaxTokens;
  }

  Future<void> setSystemPrompt(String prompt) async {
    await _prefs?.setString(AppConstants.keySystemPrompt, prompt);
  }

  Future<String> getSystemPrompt() async {
    return _prefs?.getString(AppConstants.keySystemPrompt) ?? '';
  }

  // Selected Provider & Model

  Future<void> setSelectedProvider(AIProvider provider) async {
    await _prefs?.setString(AppConstants.keySelectedProvider, provider.name);
  }

  Future<AIProvider> getSelectedProvider() async {
    final providerName = _prefs?.getString(AppConstants.keySelectedProvider);
    if (providerName == null) return AIProvider.gemini;
    return AIProvider.values.firstWhere(
      (e) => e.name == providerName,
      orElse: () => AIProvider.gemini,
    );
  }

  Future<void> setSelectedModel(String modelId) async {
    await _prefs?.setString(AppConstants.keySelectedModel, modelId);
  }

  Future<String?> getSelectedModel() async {
    return _prefs?.getString(AppConstants.keySelectedModel);
  }

  // Per-provider selected model (remembers last-used model for each provider)

  Future<void> setSelectedModelForProvider(
    AIProvider provider,
    String modelId,
  ) async {
    await _prefs?.setString(
      '${AppConstants.keySelectedModelPrefix}${provider.name}',
      modelId,
    );
  }

  Future<String?> getSelectedModelForProvider(AIProvider provider) async {
    return _prefs?.getString(
      '${AppConstants.keySelectedModelPrefix}${provider.name}',
    );
  }

  // Conversations

  static Directory? _supportDir;

  /// Conversations live in their own file (not shared_preferences) so the
  /// prefs file stays small and fast to rewrite.
  Future<File> _conversationsFile() async {
    _supportDir ??= await getApplicationSupportDirectory();
    return File('${_supportDir!.path}/conversations.json');
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final jsonList = conversations.map((c) => c.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    try {
      // Write to a temp file first so a crash can't corrupt the data
      final file = await _conversationsFile();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonString, flush: true);
      await tmp.rename(file.path);
      // Drop the legacy in-prefs copy once the file write succeeds
      await _prefs?.remove(AppConstants.keyConversations);
    } catch (e) {
      debugPrint('Conversations file write failed, using prefs: $e');
      await _prefs?.setString(AppConstants.keyConversations, jsonString);
    }
  }

  Future<List<Conversation>> loadConversations() async {
    List<Conversation>? parse(String jsonString) {
      try {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList
            .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading conversations: $e');
        return null;
      }
    }

    final legacy = _prefs?.getString(AppConstants.keyConversations);

    try {
      final file = await _conversationsFile();
      if (await file.exists()) {
        // The file wins; clean up the legacy prefs copy if present
        if (legacy != null) {
          await _prefs?.remove(AppConstants.keyConversations);
        }
        return parse(await file.readAsString()) ?? [];
      }
    } catch (e) {
      debugPrint('Error reading conversations file: $e');
    }

    // Migrate: write the legacy prefs copy to the file, then remove it
    if (legacy == null || legacy.isEmpty) return [];
    final parsed = parse(legacy);
    if (parsed != null) {
      await saveConversations(parsed);
    }
    return parsed ?? [];
  }

  Future<void> saveConversation(Conversation conversation) async {
    final conversations = await loadConversations();
    final existingIndex = conversations.indexWhere(
      (c) => c.id == conversation.id,
    );

    if (existingIndex >= 0) {
      conversations[existingIndex] = conversation;
    } else {
      conversations.insert(0, conversation);
    }

    await saveConversations(conversations);
  }

  Future<void> deleteConversation(String conversationId) async {
    final conversations = await loadConversations();
    conversations.removeWhere((c) => c.id == conversationId);
    await saveConversations(conversations);
  }

  Future<void> clearAllConversations() async {
    await _prefs?.remove(AppConstants.keyConversations);
    try {
      final file = await _conversationsFile();
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Error deleting conversations file: $e');
    }
  }

  // Clear all data

  Future<void> clearAllData() async {
    await _prefs?.clear();
    await _secureStorage?.deleteAll();
    try {
      final file = await _conversationsFile();
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Error deleting conversations file: $e');
    }
  }
}
