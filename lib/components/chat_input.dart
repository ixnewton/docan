import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../utils/liquid_glass_effects.dart';

/// Liquid Glass styled chat input field
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onSend;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool isLoading;
  final String hintText;

  const ChatInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.onSend,
    this.onChanged,
    this.enabled = true,
    this.isLoading = false,
    this.hintText = 'Message...',
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleTextChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _handleTextChange() {
    if (!mounted) return;
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onChanged?.call(widget.controller.text);
  }

  void _handleSend() {
    if (widget.controller.text.trim().isEmpty) return;
    if (widget.isLoading) return;
    widget.onSend?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = !widget.enabled;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: LiquidGlassContainer(
          borderRadius: AppConstants.radiusNavBar,
          padding: EdgeInsets.zero,
          blurIntensity: 25,
          animateOnHover: false,
          child: AnimatedContainer(
            duration: AppConstants.hoverDuration,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusNavBar),
              border: Border.all(
                color: _isFocused && !isDisabled
                    ? theme.primaryColor.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Attachment button (future feature)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppConstants.spacingXS,
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.add,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: isDisabled ? 0.3 : 0.6),
                        size: 20,
                      ),
                      onPressed: isDisabled
                          ? null
                          : () {
                              // Future: file attachment
                            },
                    ),
                  ),
                ),
                // Text field
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      // Desktop: Enter to send, Shift+Enter for newline
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _handleSend();
                      }
                    },
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingS,
                          vertical: AppConstants.spacingM,
                        ),
                      ),
                    ),
                  ),
                ),
                // Send button
                Padding(
                  padding: const EdgeInsets.only(
                    right: AppConstants.spacingXS,
                  ),
                  child: AnimatedContainer(
                    duration: AppConstants.hoverDuration,
                    child: widget.isLoading
                        ? SizedBox(
                            width: 36,
                            height: 36,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.primaryColor,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _hasText
                                  ? theme.primaryColor
                                  : theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed:
                                  _hasText && widget.enabled ? _handleSend : null,
                              icon: Icon(
                                Icons.arrow_upward_rounded,
                                color: _hasText
                                    ? Colors.white
                                    : theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.4),
                                size: 20,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
