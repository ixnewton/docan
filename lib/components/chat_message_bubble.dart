import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/constants.dart';
import '../config/themes.dart';
import '../models/chat_message.dart';
import '../utils/liquid_glass_effects.dart';

/// Liquid Glass styled message bubble
class ChatMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final double maxWidth;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDelete;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.maxWidth,
    this.onCopy,
    this.onRegenerate,
    this.onDelete,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.entryExitDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: LiquidGlassCurves.smoothEntry),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: LiquidGlassCurves.liquid),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUser = widget.message.isUser;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) _buildAvatar(context, isUser),
              const SizedBox(width: AppConstants.spacingS),
              Flexible(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: GestureDetector(
                    onLongPress: () => _showContextMenu(context),
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        _buildBubble(context, isDark, isUser),
                        if (_isHovered && !widget.message.isStreaming)
                          _buildActions(context),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              if (isUser) _buildAvatar(context, isUser),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isUser) {
    final theme = Theme.of(context);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser
            ? theme.primaryColor.withValues(alpha: 0.2)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isUser
              ? theme.primaryColor.withValues(alpha: 0.3)
              : theme.dividerColor,
          width: 1,
        ),
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy_outlined,
        size: 18,
        color: isUser ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
      ),
    );
  }

  Widget _buildBubble(BuildContext context, bool isDark, bool isUser) {
    final theme = Theme.of(context);

    if (widget.message.hasError) {
      return _buildErrorBubble(context);
    }

    final bubbleColor = isUser
        ? (isDark
            ? LiquidGlassColors.userBubbleDark
            : LiquidGlassColors.userBubbleLight)
        : (isDark
            ? LiquidGlassColors.aiBubbleDark
            : LiquidGlassColors.aiBubbleLight);

    final textColor = isUser
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Container(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppConstants.radiusM),
          topRight: const Radius.circular(AppConstants.radiusM),
          bottomLeft: Radius.circular(isUser ? AppConstants.radiusM : 4),
          bottomRight: Radius.circular(isUser ? 4 : AppConstants.radiusM),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bubbleColor.withValues(alpha: isUser ? 1.0 : 0.8),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppConstants.radiusM),
              topRight: const Radius.circular(AppConstants.radiusM),
              bottomLeft: Radius.circular(isUser ? AppConstants.radiusM : 4),
              bottomRight: Radius.circular(isUser ? 4 : AppConstants.radiusM),
            ),
          ),
          padding: const EdgeInsets.all(AppConstants.bubblePadding),
          child: widget.message.isStreaming && widget.message.content.isEmpty
              ? LiquidGlassTypingIndicator(
                  color: isUser ? Colors.white : theme.primaryColor,
                )
              : isUser
                  ? SelectableText(
                      widget.message.content,
                      style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
                    )
                  : MarkdownBody(
                      data: widget.message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyLarge?.copyWith(color: textColor),
                        h1: theme.textTheme.headlineLarge?.copyWith(color: textColor),
                        h2: theme.textTheme.headlineMedium?.copyWith(color: textColor),
                        h3: theme.textTheme.headlineSmall?.copyWith(color: textColor),
                        code: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          backgroundColor: isDark
                              ? Colors.black26
                              : Colors.black.withValues(alpha: 0.05),
                          color: textColor,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: isDark
                              ? Colors.black38
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: theme.primaryColor,
                              width: 3,
                            ),
                          ),
                        ),
                        listBullet: theme.textTheme.bodyLarge?.copyWith(color: textColor),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildErrorBubble(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      padding: const EdgeInsets.all(AppConstants.bubblePadding),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: AppConstants.spacingS),
          Flexible(
            child: Text(
              widget.message.error ?? 'An error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.copy,
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.message.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
              widget.onCopy?.call();
            },
          ),
          if (!widget.message.isUser) ...[
            const SizedBox(width: 4),
            _ActionButton(
              icon: Icons.refresh,
              tooltip: 'Regenerate',
              onPressed: widget.onRegenerate,
            ),
          ],
        ],
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
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.message.content));
                Navigator.pop(context);
              },
            ),
            if (!widget.message.isUser)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Regenerate'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onRegenerate?.call();
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
  final String tooltip;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
