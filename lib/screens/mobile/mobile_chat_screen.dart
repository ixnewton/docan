import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/ai_provider.dart';
import '../../services/chat_service.dart';
import '../../components/chat_message_bubble.dart';
import '../../components/chat_input.dart';
import '../../components/conversation_list.dart';
import '../../components/model_selector.dart';
import '../../components/agent_selector.dart';
import '../../utils/liquid_glass_effects.dart';
import '../../utils/screen_size_helper.dart';
import 'mobile_settings_screen.dart';

/// Mobile chat screen with iOS 26 Liquid Glass design
class MobileChatScreen extends StatefulWidget {
  const MobileChatScreen({super.key});

  @override
  State<MobileChatScreen> createState() => _MobileChatScreenState();
}

class _MobileChatScreenState extends State<MobileChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<AIProvider, bool> _configuredProviders = {};

  @override
  void initState() {
    super.initState();
    _loadConfiguredProviders();
  }

  Future<void> _loadConfiguredProviders() async {
    final chatService = context.read<ChatService>();
    final configured = await chatService.getConfiguredProviders();
    if (mounted) {
      setState(() {
        _configuredProviders = configured;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: LiquidGlassCurves.liquid,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ChatService>(
      builder: (context, chatService, child) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: theme.scaffoldBackgroundColor,
          drawer: _buildDrawer(context, chatService),
          body: SafeArea(
            child: Column(
              children: [
                // Floating Nav Bar
                _buildNavBar(context, chatService),
                
                // Chat Messages
                Expanded(
                  child: _buildMessageList(context, chatService),
                ),
                
                // Input Field
                ChatInput(
                  controller: _inputController,
                  isLoading: chatService.isLoading,
                  onSend: () async {
                    final message = _inputController.text.trim();
                    if (message.isNotEmpty) {
                      _inputController.clear();
                      await chatService.sendMessage(message);
                      _scrollToBottom();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavBar(BuildContext context, ChatService chatService) {
    final theme = Theme.of(context);

    return LiquidGlassNavBar(
      child: Row(
        children: [
          // Menu button
          LiquidGlassIconButton(
            icon: Icons.menu,
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          
          const SizedBox(width: AppConstants.spacingS),
          
          // Title
          Text(
            AppConstants.appName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // Model selector (compact)
          ModelSelector(
            selectedProvider: chatService.selectedProvider,
            selectedModel: chatService.selectedModel,
            onProviderChanged: chatService.setProvider,
            onModelChanged: chatService.setModel,
            compact: true,
            configuredProviders: _configuredProviders,
          ),
          
          const SizedBox(width: AppConstants.spacingS),
          
          // Agent selector (compact)
          AgentSelector(
            selectedAgent: chatService.selectedAgent,
            onAgentChanged: chatService.selectAgent,
            compact: true,
          ),
          
          const SizedBox(width: AppConstants.spacingS),
          
          // Settings
          LiquidGlassIconButton(
            icon: Icons.settings,
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, ChatService chatService) {
    final conversation = chatService.currentConversation;
    final maxBubbleWidth = ScreenSizeHelper.getMaxBubbleWidth(context);

    if (conversation == null || conversation.messages.isEmpty) {
      return _buildEmptyState(context, chatService);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
      itemCount: conversation.messages.length,
      itemBuilder: (context, index) {
        final message = conversation.messages[index];
        return ChatMessageBubble(
          message: message,
          maxWidth: maxBubbleWidth,
          onRegenerate: message.isAssistant && !message.isStreaming
              ? () => chatService.regenerateLastResponse()
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ChatService chatService) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: theme.primaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              'Welcome to ${AppConstants.appName}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Start a conversation with AI',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXL),
            
            // Quick prompts
            Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingS,
              alignment: WrapAlignment.center,
              children: [
                _QuickPromptChip(
                  label: '💡 Explain a concept',
                  onTap: () => _sendQuickPrompt(
                    chatService,
                    'Can you explain a complex concept in simple terms?',
                  ),
                ),
                _QuickPromptChip(
                  label: '💻 Write code',
                  onTap: () => _sendQuickPrompt(
                    chatService,
                    'Help me write some code',
                  ),
                ),
                _QuickPromptChip(
                  label: '✍️ Help me write',
                  onTap: () => _sendQuickPrompt(
                    chatService,
                    'Help me write something',
                  ),
                ),
                _QuickPromptChip(
                  label: '🔍 Research a topic',
                  onTap: () => _sendQuickPrompt(
                    chatService,
                    'Help me research a topic',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendQuickPrompt(ChatService chatService, String prompt) {
    _inputController.text = prompt;
  }

  Widget _buildDrawer(BuildContext context, ChatService chatService) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: Colors.transparent,
      child: LiquidGlassContainer(
        borderRadius: 0,
        margin: EdgeInsets.zero,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Row(
                  children: [
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    LiquidGlassIconButton(
                      icon: Icons.close,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Conversation list
              Expanded(
                child: ConversationList(
                  conversations: chatService.activeConversations,
                  selectedConversation: chatService.currentConversation,
                  onSelect: (conv) {
                    chatService.selectConversation(conv);
                    Navigator.pop(context);
                  },
                  onDelete: (id) => chatService.deleteConversation(id),
                  onPin: (id) => chatService.togglePin(id),
                  onNewChat: () {
                    chatService.createConversation();
                    Navigator.pop(context);
                  },
                ),
              ),
              
              const Divider(height: 1),
              
              // Bottom actions
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _openSettings(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MobileSettingsScreen(),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickPromptChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingM,
          vertical: AppConstants.spacingS,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppConstants.radiusNavBar),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium,
        ),
      ),
    );
  }
}
