import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../config/themes.dart';
import '../models/conversation.dart';
import '../utils/liquid_glass_effects.dart';

/// Conversation list for sidebar/drawer
class ConversationList extends StatelessWidget {
  final List<Conversation> conversations;
  final Conversation? selectedConversation;
  final ValueChanged<Conversation> onSelect;
  final ValueChanged<String>? onDelete;
  final ValueChanged<String>? onPin;
  final VoidCallback? onNewChat;

  const ConversationList({
    super.key,
    required this.conversations,
    this.selectedConversation,
    required this.onSelect,
    this.onDelete,
    this.onPin,
    this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedConversations = _groupByDate(conversations);

    return Column(
      children: [
        // New Chat Button
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: LiquidGlassButton(
            onPressed: onNewChat,
            backgroundColor: theme.primaryColor,
            borderRadius: AppConstants.radiusS,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingM,
              vertical: AppConstants.spacingS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 20),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'New Chat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Conversation list
        Expanded(
          child: conversations.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                  ),
                  itemCount: groupedConversations.length,
                  itemBuilder: (context, index) {
                    final entry = groupedConversations.entries.elementAt(index);
                    return _buildSection(context, entry.key, entry.value);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No conversations yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Start a new chat to begin',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Conversation> conversations,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingS,
            vertical: AppConstants.spacingS,
          ),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...conversations.map((conv) => _ConversationTile(
              conversation: conv,
              isSelected: conv.id == selectedConversation?.id,
              onTap: () => onSelect(conv),
              onDelete: onDelete != null ? () => onDelete!(conv.id) : null,
              onPin: onPin != null ? () => onPin!(conv.id) : null,
            )),
        const SizedBox(height: AppConstants.spacingS),
      ],
    );
  }

  Map<String, List<Conversation>> _groupByDate(List<Conversation> conversations) {
    final grouped = <String, List<Conversation>>{};
    
    // First add pinned conversations
    final pinned = conversations.where((c) => c.isPinned).toList();
    if (pinned.isNotEmpty) {
      grouped['Pinned'] = pinned;
    }

    // Then add by date
    for (final conv in conversations.where((c) => !c.isPinned)) {
      final category = conv.dateCategory;
      grouped.putIfAbsent(category, () => []).add(conv);
    }

    return grouped;
  }
}

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onPin,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: () => _showContextMenu(context),
        child: AnimatedContainer(
          duration: AppConstants.hoverDuration,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
                : _isHovered
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03))
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            border: widget.isSelected
                ? Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Pin indicator
              if (widget.conversation.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: AppConstants.spacingS),
                  child: Icon(
                    Icons.push_pin,
                    size: 14,
                    color: theme.primaryColor,
                  ),
                ),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.conversation.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.conversation.lastMessagePreview,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Time
              if (!_isHovered)
                Text(
                  widget.conversation.relativeTime,
                  style: theme.textTheme.labelSmall,
                ),

              // Actions on hover
              if (_isHovered) ...[
                _ActionButton(
                  icon: widget.conversation.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  onPressed: widget.onPin,
                ),
                _ActionButton(
                  icon: Icons.delete_outline,
                  onPressed: widget.onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LiquidGlassContainer(
        borderRadius: AppConstants.radiusL,
        margin: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                widget.conversation.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
              ),
              title: Text(widget.conversation.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                widget.onPin?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 18,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
