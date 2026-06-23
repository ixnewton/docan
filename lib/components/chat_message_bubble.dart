import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/themes.dart';
import '../models/chat_message.dart';
import '../services/clipboard_service.dart';

/// Standard Material Design message bubble
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
  Timer? _selectionDebounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.entryExitDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _selectionDebounce?.cancel();
    super.dispose();
  }

  void _onTextSelectionChanged(TextSelection selection, String fullText) {
    // Cancel previous debounce timer
    _selectionDebounce?.cancel();
    
    // Set PRIMARY selection when text is selected for middle-click paste
    if (selection.isValid && !selection.isCollapsed) {
      // Debounce to avoid rapid clipboard updates during selection
      _selectionDebounce = Timer(const Duration(milliseconds: 300), () {
        final selectedText = fullText.substring(
          selection.start,
          selection.end,
        );
        if (selectedText.isNotEmpty) {
          ClipboardService.setText(selectedText);
        }
      });
    }
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
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
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
        ? theme.primaryColor
        : (isDark ? theme.colorScheme.surface : Colors.grey[100]);

    final textColor = isUser
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    // Check for image attachments
    final imageAttachments = widget.message.attachments
        .where((a) => a.type == AttachmentType.image)
        .toList();

    return Container(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? AppConstants.radiusM : 4),
          topRight: Radius.circular(isUser ? 4 : AppConstants.radiusM),
          bottomLeft: const Radius.circular(AppConstants.radiusM),
          bottomRight: const Radius.circular(AppConstants.radiusM),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isUser ? AppConstants.radiusM : 4),
              topRight: Radius.circular(isUser ? 4 : AppConstants.radiusM),
              bottomLeft: const Radius.circular(AppConstants.radiusM),
              bottomRight: const Radius.circular(AppConstants.radiusM),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show image attachments
              if (imageAttachments.isNotEmpty)
                _buildImageAttachments(imageAttachments),
              // Show text content
              if (widget.message.content.isNotEmpty ||
                  widget.message.isStreaming)
                Padding(
                  padding: const EdgeInsets.all(AppConstants.bubblePadding),
                  child:
                      widget.message.isStreaming &&
                          widget.message.content.isEmpty
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : isUser
                      ? SelectionArea(
                          child: SelectableText(
                            widget.message.content,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: textColor,
                            ),
                            onSelectionChanged: (selection, cause) {
                              _onTextSelectionChanged(selection, widget.message.content);
                            },
                          ),
                        )
                      : SelectionArea(
                          child: MarkdownBody(
                          data: widget.message.content,
                          selectable: true,
                          builders: {
                            'latex': LatexElementBuilder(
                              textStyle: theme.textTheme.bodyLarge?.copyWith(
                                color: textColor,
                              ),
                              textScaleFactor: 1.2,
                            ),
                          },
                          extensionSet: md.ExtensionSet(
                            [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                            [
                              md.EmojiSyntax(),
                              ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                              LatexSyntax(),
                            ],
                          ),
                          onTapLink: (text, href, title) async {
                            if (href != null) {
                              final uri = Uri.tryParse(href);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            }
                          },
                          imageBuilder: (uri, title, alt) {
                            // Handle base64 data URLs for generated images
                            if (uri.toString().startsWith('data:image/')) {
                              try {
                                final dataUri = uri.toString();
                                final commaIndex = dataUri.indexOf(',');
                                if (commaIndex != -1) {
                                  final base64Data = dataUri.substring(
                                    commaIndex + 1,
                                  );
                                  final bytes = base64Decode(base64Data);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusS,
                                    ),
                                    child: Image.memory(
                                      bytes,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              padding: const EdgeInsets.all(
                                                AppConstants.spacingM,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppConstants.radiusS,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Failed to load generated image',
                                              ),
                                            );
                                          },
                                    ),
                                  );
                                }
                              } catch (e) {
                                return Container(
                                  padding: const EdgeInsets.all(
                                    AppConstants.spacingM,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusS,
                                    ),
                                  ),
                                  child: Text('Image error: $e'),
                                );
                              }
                            }
                            // For other images, show a placeholder
                            return const SizedBox.shrink();
                          },
                          styleSheet: MarkdownStyleSheet(
                            p: theme.textTheme.bodyLarge?.copyWith(
                              color: textColor,
                            ),
                            h1: theme.textTheme.headlineLarge?.copyWith(
                              color: textColor,
                            ),
                            h2: theme.textTheme.headlineMedium?.copyWith(
                              color: textColor,
                            ),
                            h3: theme.textTheme.headlineSmall?.copyWith(
                              color: textColor,
                            ),
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
                            listBullet: theme.textTheme.bodyLarge?.copyWith(
                              color: textColor,
                            ),
                            a: TextStyle(
                              color: isDark
                                  ? Colors.lightBlueAccent
                                  : Colors.blue,
                              decoration: TextDecoration.underline,
                              decorationColor: isDark
                                  ? Colors.lightBlueAccent
                                  : Colors.blue,
                            ),
                          ),
                        ),
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageAttachments(List<Attachment> images) {
    if (images.length == 1) {
      return _buildSingleImage(images.first);
    }

    // Grid for multiple images
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: images
            .map((img) => _buildGridImage(img, images.length))
            .toList(),
      ),
    );
  }

  Widget _buildSingleImage(Attachment image) {
    return GestureDetector(
      onTap: () => _showFullImage(context, image),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppConstants.radiusM),
          topRight: Radius.circular(AppConstants.radiusM),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
            maxHeight: 300,
          ),
          child: Image.memory(
            image.bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, size: 24),
                    SizedBox(width: 8),
                    Text('Failed to load image'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGridImage(Attachment image, int totalCount) {
    final size = totalCount == 2 ? 150.0 : 100.0;
    return GestureDetector(
      onTap: () => _showFullImage(context, image),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.memory(
            image.bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.withValues(alpha: 0.3),
                child: const Icon(Icons.broken_image),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, Attachment image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                child: Image.memory(image.bytes, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
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
            onPressed: () async {
              await ClipboardService.setText(widget.message.content);
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
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusL),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () async {
                await ClipboardService.setText(widget.message.content);
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
          child: Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color),
        ),
      ),
    );
  }
}

class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[^$]*\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final input = match.input;
    final matchStart = match.start;
    final matchEnd = match.end;
    final text = input.substring(matchStart, matchEnd);
    final isBlock = text.startsWith('\$\$') && text.endsWith('\$\$');

    final content = isBlock
        ? text.substring(2, text.length - 2)
        : text.substring(1, text.length - 1);

    md.Element el = md.Element.text('latex', content);
    el.attributes['displayMode'] = isBlock.toString();
    parser.addNode(el);
    return true;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;
  final double textScaleFactor;

  LatexElementBuilder({this.textStyle, this.textScaleFactor = 1.0});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final content = element.textContent;
    final isBlock = element.attributes['displayMode'] == 'true';

    return Math.tex(
      content,
      mathStyle: isBlock ? MathStyle.display : MathStyle.text,
      textStyle: textStyle?.copyWith(
        fontSize:
            (textStyle?.fontSize ?? 14) * (isBlock ? textScaleFactor : 1.0),
      ),
      onErrorFallback: (err) {
        return Text(
          '\$$content\$',
          style: textStyle?.copyWith(color: Colors.red),
        );
      },
    );
  }
}
