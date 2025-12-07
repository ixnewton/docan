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

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _prefs = await SharedPreferences.getInstance();
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
    }
    return _instance!;
  }

  // API Keys (Secure Storage)

  Future<void> setApiKey(AIProvider provider, String key) async {
    final storageKey = _getApiKeyStorageKey(provider);
    await _secureStorage?.write(key: storageKey, value: key);
  }

  Future<String?> getApiKey(AIProvider provider) async {
    final storageKey = _getApiKeyStorageKey(provider);
    return await _secureStorage?.read(key: storageKey);
  }

  Future<void> deleteApiKey(AIProvider provider) async {
    final storageKey = _getApiKeyStorageKey(provider);
    await _secureStorage?.delete(key: storageKey);
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
