import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/ai_provider.dart';
import '../models/agent_config.dart';
import 'ai_service.dart';
import 'gemini_service.dart';
import 'openai_service.dart';
import 'claude_service.dart';
import 'ollama_service.dart';
import 'storage_service.dart';

/// Chat service for managing conversations and AI interactions
class ChatService extends ChangeNotifier {
  final StorageService _storage;
  
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  AIProvider _selectedProvider = AIProvider.gemini;
  String _selectedModel = '';
  AgentPreset? _selectedAgent;
  bool _isLoading = false;
  String? _error;
  double _temperature = 0.7;
  int _maxTokens = 2048;

  // AI Services
  final Map<AIProvider, AIService> _services = {};

  ChatService(this._storage) {
    _initServices();
  }

  void _initServices() {
    _services[AIProvider.gemini] = GeminiService();
    _services[AIProvider.openai] = OpenAIService();
    _services[AIProvider.claude] = ClaudeService();
    _services[AIProvider.ollama] = OllamaService();
  }

  // Getters
  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  AIProvider get selectedProvider => _selectedProvider;
  String get selectedModel => _selectedModel.isEmpty 
      ? _selectedProvider.defaultModel 
      : _selectedModel;
  AgentPreset? get selectedAgent => _selectedAgent;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;

  AIService get currentService => _services[_selectedProvider]!;

  /// Initialize the chat service
  Future<void> initialize() async {
    // Load conversations
    _conversations = await _storage.loadConversations();
    
    // Load settings
    _selectedProvider = await _storage.getSelectedProvider();
    _selectedModel = await _storage.getSelectedModel() ?? _selectedProvider.defaultModel;
    _temperature = await _storage.getTemperature();
    _maxTokens = await _storage.getMaxTokens();

    // Load API keys
    for (final provider in AIProvider.values) {
      final apiKey = await _storage.getApiKey(provider);
      if (apiKey != null && apiKey.isNotEmpty) {
        _services[provider]?.setApiKey(apiKey);
      }
    }

    // Set models
    for (final service in _services.values) {
      service.setModel(_selectedModel);
    }

    notifyListeners();
  }

  /// Set the selected provider
  Future<void> setProvider(AIProvider provider) async {
    _selectedProvider = provider;
    _selectedModel = provider.defaultModel;
    await _storage.setSelectedProvider(provider);
    await _storage.setSelectedModel(_selectedModel);
    notifyListeners();
  }

  /// Set the selected model
  Future<void> setModel(String modelId) async {
    _selectedModel = modelId;
    currentService.setModel(modelId);
    await _storage.setSelectedModel(modelId);
    notifyListeners();
  }

  /// Set API key for a provider
  Future<void> setApiKey(AIProvider provider, String apiKey) async {
    await _storage.setApiKey(provider, apiKey);
    _services[provider]?.setApiKey(apiKey);
    notifyListeners();
  }

  /// Set temperature
  Future<void> setTemperature(double temp) async {
    _temperature = temp;
    await _storage.setTemperature(temp);
    notifyListeners();
  }

  /// Set max tokens
  Future<void> setMaxTokens(int tokens) async {
    _maxTokens = tokens;
    await _storage.setMaxTokens(tokens);
    notifyListeners();
  }

  /// Select an agent preset
  void selectAgent(AgentPreset? agent) {
    _selectedAgent = agent;
    if (agent != null) {
      _selectedProvider = agent.provider;
      _selectedModel = agent.modelId;
      _temperature = agent.temperature;
      currentService.setModel(agent.modelId);
    }
    notifyListeners();
  }

  /// Create a new conversation
  Conversation createConversation({String? title}) {
    final conversation = Conversation.create(
      title: title,
      provider: _selectedProvider,
      modelId: selectedModel,
    );
    _conversations.insert(0, conversation);
    _currentConversation = conversation;
    _saveConversations();
    notifyListeners();
    return conversation;
  }

  /// Select a conversation
  void selectConversation(Conversation conversation) {
    _currentConversation = conversation;
    _selectedProvider = conversation.provider;
    _selectedModel = conversation.modelId;
    notifyListeners();
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    _conversations.removeWhere((c) => c.id == conversationId);
    if (_currentConversation?.id == conversationId) {
      _currentConversation = _conversations.isNotEmpty ? _conversations.first : null;
    }
    await _storage.deleteConversation(conversationId);
    notifyListeners();
  }

  /// Send a message
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    _error = null;
    
    // Create conversation if needed
    if (_currentConversation == null) {
      createConversation();
    }

    // Add user message
    final userMessage = ChatMessage.user(content);
    _currentConversation = _currentConversation!.addMessage(userMessage);
    _updateConversationInList();
    notifyListeners();

    // Create placeholder for AI response
    final placeholderMessage = ChatMessage.streaming(modelId: selectedModel);
    _currentConversation = _currentConversation!.addMessage(placeholderMessage);
    _updateConversationInList();
    _isLoading = true;
    notifyListeners();

    try {
      final systemPrompt = _selectedAgent?.systemPrompt;
      final history = _currentConversation!.messages
          .where((m) => m.id != placeholderMessage.id)
          .toList();

      // Use streaming
      final stream = currentService.sendMessageStream(
        content,
        history,
        systemPrompt: systemPrompt,
        temperature: _temperature,
        maxTokens: _maxTokens,
      );

      String fullResponse = '';
      await for (final chunk in stream) {
        fullResponse += chunk;
        final updatedMessage = placeholderMessage.copyWith(
          content: fullResponse,
          isStreaming: true,
        );
        _currentConversation = _currentConversation!.updateMessage(
          placeholderMessage.id,
          updatedMessage,
        );
        _updateConversationInList();
        notifyListeners();
      }

      // Finalize message
      final finalMessage = placeholderMessage.copyWith(
        content: fullResponse,
        isStreaming: false,
      );
      _currentConversation = _currentConversation!.updateMessage(
        placeholderMessage.id,
        finalMessage,
      );

      // Update conversation title if it's the first exchange
      if (_currentConversation!.messages.length <= 3) {
        _currentConversation = _currentConversation!.copyWith(
          title: _generateTitle(content),
        );
      }

    } catch (e) {
      final errorMessage = placeholderMessage.copyWith(
        content: '',
        isStreaming: false,
        error: e.toString(),
      );
      _currentConversation = _currentConversation!.updateMessage(
        placeholderMessage.id,
        errorMessage,
      );
      _error = e.toString();
    }

    _isLoading = false;
    _updateConversationInList();
    _saveConversations();
    notifyListeners();
  }

  /// Generate a title from the first message
  String _generateTitle(String firstMessage) {
    final words = firstMessage.split(' ').take(5).join(' ');
    return words.length > 30 ? '${words.substring(0, 30)}...' : words;
  }

  /// Update conversation in list
  void _updateConversationInList() {
    if (_currentConversation == null) return;
    final index = _conversations.indexWhere((c) => c.id == _currentConversation!.id);
    if (index >= 0) {
      _conversations[index] = _currentConversation!;
    }
  }

  /// Save conversations to storage
  Future<void> _saveConversations() async {
    await _storage.saveConversations(_conversations);
  }

  /// Test connection for a provider
  Future<bool> testConnection(AIProvider provider) async {
    return await _services[provider]?.testConnection() ?? false;
  }

  /// Check if API key is set for a provider
  Future<bool> hasApiKey(AIProvider provider) async {
    return await _storage.hasApiKey(provider);
  }

  /// Clear all conversations
  Future<void> clearAllConversations() async {
    _conversations.clear();
    _currentConversation = null;
    await _storage.clearAllConversations();
    notifyListeners();
  }

  /// Regenerate last response
  Future<void> regenerateLastResponse() async {
    if (_currentConversation == null) return;
    if (_currentConversation!.messages.length < 2) return;

    // Remove last AI message
    final messages = _currentConversation!.messages;
    if (messages.last.role == MessageRole.assistant) {
      _currentConversation = _currentConversation!.removeMessage(messages.last.id);
      
      // Get the last user message and resend
      final lastUserMessage = _currentConversation!.messages.last;
      if (lastUserMessage.role == MessageRole.user) {
        _currentConversation = _currentConversation!.removeMessage(lastUserMessage.id);
        await sendMessage(lastUserMessage.content);
      }
    }
  }

  /// Get pinned conversations
  List<Conversation> get pinnedConversations =>
      _conversations.where((c) => c.isPinned && !c.isArchived).toList();

  /// Get active conversations (not archived)
  List<Conversation> get activeConversations =>
      _conversations.where((c) => !c.isArchived).toList();

  /// Get archived conversations
  List<Conversation> get archivedConversations =>
      _conversations.where((c) => c.isArchived).toList();

  /// Toggle pin status
  Future<void> togglePin(String conversationId) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      _conversations[index] = _conversations[index].copyWith(
        isPinned: !_conversations[index].isPinned,
      );
      await _saveConversations();
      notifyListeners();
    }
  }

  /// Toggle archive status
  Future<void> toggleArchive(String conversationId) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      _conversations[index] = _conversations[index].copyWith(
        isArchived: !_conversations[index].isArchived,
      );
      await _saveConversations();
      notifyListeners();
    }
  }
}
