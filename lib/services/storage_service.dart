import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';
import '../config/themes.dart';
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
          debugPrint('Secure storage test failed (read mismatch), using fallback');
        }
      } catch (e) {
        debugPrint('Secure storage not available, falling back to shared preferences: $e');
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
      final secureStorage = const FlutterSecureStorage(lOptions: LinuxOptions());
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
      case AIProvider.ollama:
        return AppConstants.keyOllamaUrl;
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
      case AIProvider.ollama:
        return AppConstants.keyOllamaUrl;
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

  // Theme Settings

  Future<void> setTheme(LiquidGlassTheme theme) async {
    await _prefs?.setString(AppConstants.keyThemeMode, theme.name);
  }

  Future<LiquidGlassTheme> getTheme() async {
    final themeName = _prefs?.getString(AppConstants.keyThemeMode);
    if (themeName == null) return LiquidGlassTheme.light;
    return LiquidGlassTheme.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => LiquidGlassTheme.light,
    );
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

  // Conversations

  Future<void> saveConversations(List<Conversation> conversations) async {
    final jsonList = conversations.map((c) => c.toJson()).toList();
    await _prefs?.setString(
      AppConstants.keyConversations,
      jsonEncode(jsonList),
    );
  }

  Future<List<Conversation>> loadConversations() async {
    final jsonString = _prefs?.getString(AppConstants.keyConversations);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      return [];
    }
  }

  Future<void> saveConversation(Conversation conversation) async {
    final conversations = await loadConversations();
    final existingIndex = conversations.indexWhere((c) => c.id == conversation.id);
    
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
  }

  // Clear all data

  Future<void> clearAllData() async {
    await _prefs?.clear();
    await _secureStorage?.deleteAll();
  }
}
