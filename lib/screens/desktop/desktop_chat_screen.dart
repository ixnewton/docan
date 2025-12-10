import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'desktop_settings_screen.dart';

/// Desktop chat screen with macOS Tahoe Liquid Glass design
class DesktopChatScreen extends StatefulWidget {
  const DesktopChatScreen({super.key});

  @override
  State<DesktopChatScreen> createState() => _DesktopChatScreenState();
}

class _DesktopChatScreenState extends State<DesktopChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
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
    _inputFocusNode.dispose();
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
        return CallbackShortcuts(
          bindings: {
            // Cmd+N: New conversation
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
              chatService.createConversation();
            },
            // Cmd+K: Quick model switcher (TODO)
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
              // TODO: Show quick model switcher
            },
            // Cmd+,: Settings
            const SingleActivator(LogicalKeyboardKey.comma, meta: true): () {
              _openSettings(context);
            },
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: Row(
                children: [
                  // Sidebar
                  _buildSidebar(context, chatService),
                  
                  // Main content
                  Expanded(
                    child: Column(
                      children: [
                        // Toolbar
                        _buildToolbar(context, chatService),
                        
                        // Chat area
                        Expanded(
                          child: _buildChatArea(context, chatService),
                        ),
                        
                        // Input
                        Builder(
                          builder: (context) {
                            final hasApiKey = _configuredProviders[chatService.selectedProvider] ?? false;
                            return ChatInput(
                              controller: _inputController,
                              focusNode: _inputFocusNode,
                              isLoading: chatService.isLoading,
                              enabled: hasApiKey,
                              hintText: hasApiKey ? 'Message...' : 'Add API key in settings to start chatting',
                              onSend: () async {
                                final message = _inputController.text.trim();
                                if (message.isNotEmpty) {
                                  _inputController.clear();
                                  await chatService.sendMessage(message);
                                  _scrollToBottom();
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, ChatService chatService) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: AppConstants.sidebarWidth,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.5),
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search bar (placeholder)
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: LiquidGlassTextField(
              hintText: 'Search conversations...',
              prefixIcon: Icon(
                Icons.search,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
          
          // Conversations
          Expanded(
            child: ConversationList(
              conversations: chatService.activeConversations,
              selectedConversation: chatService.currentConversation,
              onSelect: chatService.selectConversation,
              onDelete: (id) => chatService.deleteConversation(id),
              onPin: (id) => chatService.togglePin(id),
              onNewChat: () => chatService.createConversation(),
            ),
          ),
          
          // Settings button
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              onTap: () => _openSettings(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, ChatService chatService) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Title
          Text(
            chatService.currentConversation?.title ?? AppConstants.appName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const Spacer(),
          
          // Model selector
          ModelSelector(
            selectedProvider: chatService.selectedProvider,
            selectedModel: chatService.selectedModel,
            onProviderChanged: chatService.setProvider,
            onModelChanged: chatService.setModel,
            configuredProviders: _configuredProviders,
          ),
          
          const SizedBox(width: AppConstants.spacingM),
          
          // Agent selector
          AgentSelector(
            selectedAgent: chatService.selectedAgent,
            onAgentChanged: chatService.selectAgent,
          ),
          
          const SizedBox(width: AppConstants.spacingM),
          
          // Settings
          LiquidGlassIconButton(
            icon: Icons.settings,
            tooltip: 'Settings (⌘,)',
            onPressed: () => _openSettings(context),
          ),
          
          // More options
          LiquidGlassIconButton(
            icon: Icons.more_horiz,
            onPressed: () {
              // TODO: Show more options menu
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(BuildContext context, ChatService chatService) {
    final conversation = chatService.currentConversation;
    final maxBubbleWidth = ScreenSizeHelper.getMaxBubbleWidth(context);

    if (conversation == null || conversation.messages.isEmpty) {
      return _buildEmptyState(context, chatService);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingL),
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

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 80,
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
                'Start a conversation with AI or select one from the sidebar',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingXL),
              
              // Quick prompts
              SizedBox(
                width: 600,
                child: Wrap(
                  spacing: AppConstants.spacingS,
                  runSpacing: AppConstants.spacingS,
                  alignment: WrapAlignment.center,
                  children: [
                    _QuickPromptCard(
                      icon: Icons.lightbulb_outline,
                      title: 'Explain a concept',
                      subtitle: 'Break down complex ideas simply',
                      onTap: () => _sendQuickPrompt(
                        'Can you explain a complex concept in simple terms?',
                      ),
                    ),
                    _QuickPromptCard(
                      icon: Icons.code,
                      title: 'Write code',
                      subtitle: 'Generate code snippets',
                      onTap: () => _sendQuickPrompt(
                        'Help me write some code',
                      ),
                    ),
                    _QuickPromptCard(
                      icon: Icons.edit_note,
                      title: 'Help me write',
                      subtitle: 'Draft emails, essays, and more',
                      onTap: () => _sendQuickPrompt(
                        'Help me write something',
                      ),
                    ),
                    _QuickPromptCard(
                      icon: Icons.search,
                      title: 'Research a topic',
                      subtitle: 'Deep dive into any subject',
                      onTap: () => _sendQuickPrompt(
                        'Help me research a topic',
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppConstants.spacingXL),
              
              // Keyboard shortcuts hint
              Text(
                'Pro tip: Press ⌘N for new chat, ⌘, for settings',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
    );
  }

  void _sendQuickPrompt(String prompt) {
    _inputController.text = prompt;
    _inputFocusNode.requestFocus();
  }

  void _openSettings(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const DesktopSettingsScreen(),
    );
    // Refresh configured providers when settings dialog closes
    _loadConfiguredProviders();
  }
}

class _QuickPromptCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickPromptCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_QuickPromptCard> createState() => _QuickPromptCardState();
}

class _QuickPromptCardState extends State<_QuickPromptCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.hoverDuration,
          width: 180,
          padding: const EdgeInsets.all(AppConstants.spacingM),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.primaryColor.withValues(alpha: 0.1)
                : theme.cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            border: Border.all(
              color: _isHovered
                  ? theme.primaryColor.withValues(alpha: 0.3)
                  : theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.icon,
                color: _isHovered ? theme.primaryColor : theme.iconTheme.color,
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                widget.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
