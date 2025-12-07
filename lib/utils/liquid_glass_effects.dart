import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Liquid Glass elastic animation curve
class LiquidGlassCurves {
  LiquidGlassCurves._();

  /// Primary liquid curve - elastic, gel-like feel
  static const Curve liquid = Cubic(0.34, 1.56, 0.64, 1);

  /// Smooth entry curve
  static const Curve smoothEntry = Cubic(0.0, 0.0, 0.2, 1.0);

  /// Smooth exit curve
  static const Curve smoothExit = Cubic(0.4, 0.0, 1.0, 1.0);

  /// Bounce curve for playful interactions
  static const Curve bounce = Cubic(0.68, -0.55, 0.265, 1.55);

  /// Gentle deceleration
  static const Curve decelerate = Cubic(0.0, 0.0, 0.2, 1.0);
}

/// Liquid Glass Container Widget
/// Creates a frosted glass effect with blur and translucency
class LiquidGlassContainer extends StatefulWidget {
  final Widget child;
  final double? blurIntensity;
  final Color? tintColor;
  final double? opacity;
  final bool showSpecularHighlight;
  final bool showBorder;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool animateOnHover;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.blurIntensity,
    this.tintColor,
    this.opacity,
    this.showSpecularHighlight = true,
    this.showBorder = true,
    this.borderRadius = AppConstants.radiusM,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.animateOnHover = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.hoverDuration,
      vsync: this,
    );
    _blurAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: LiquidGlassCurves.liquid),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: LiquidGlassCurves.liquid),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHoverEnter(PointerEvent event) {
    if (!widget.animateOnHover) return;
    setState(() => _isHovered = true);
    _controller.forward();
  }

  void _handleHoverExit(PointerEvent event) {
    if (!widget.animateOnHover) return;
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseBlur = widget.blurIntensity ?? AppConstants.blurDefault;
    final baseOpacity = widget.opacity ?? (isDark ? 0.7 : 0.6);
    final tintColor = widget.tintColor ??
        (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.3));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final currentBlur = baseBlur + _blurAnimation.value;
        final currentScale = _isPressed ? 0.97 : _scaleAnimation.value;

        return Transform.scale(
          scale: currentScale,
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: widget.margin,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: currentBlur,
                  sigmaY: currentBlur,
                ),
                child: MouseRegion(
                  onEnter: _handleHoverEnter,
                  onExit: _handleHoverExit,
                  child: GestureDetector(
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    onTapDown: widget.onTap != null ? _handleTapDown : null,
                    onTapUp: widget.onTap != null ? _handleTapUp : null,
                    onTapCancel: widget.onTap != null ? _handleTapCancel : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        color: tintColor.withValues(alpha: baseOpacity),
                        border: widget.showBorder
                            ? Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.1),
                                width: 0.5,
                              )
                            : null,
                        gradient: widget.showSpecularHighlight
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: _isHovered ? 0.15 : 0.1),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.05),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                          if (_isHovered)
                            BoxShadow(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                        ],
                      ),
                      padding: widget.padding ?? const EdgeInsets.all(AppConstants.spacingM),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated Liquid Glass Button
class LiquidGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isLoading;

  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.borderRadius = AppConstants.radiusS,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppConstants.spacingM,
      vertical: AppConstants.spacingS,
    ),
    this.isLoading = false,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.buttonPressDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: LiquidGlassCurves.liquid),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        widget.backgroundColor ?? theme.primaryColor;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.isLoading ? null : widget.onPressed,
            child: AnimatedContainer(
              duration: AppConstants.hoverDuration,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                color: backgroundColor.withValues(alpha: _isPressed ? 0.8 : 1.0),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withValues(alpha: 0.3),
                    blurRadius: _isPressed ? 5 : 10,
                    offset: Offset(0, _isPressed ? 2 : 4),
                  ),
                ],
              ),
              padding: widget.padding,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Liquid Glass Icon Button
class LiquidGlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final String? tooltip;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 24,
    this.color,
    this.backgroundColor,
    this.tooltip,
  });

  @override
  State<LiquidGlassIconButton> createState() => _LiquidGlassIconButtonState();
}

class _LiquidGlassIconButtonState extends State<LiquidGlassIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.hoverDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: LiquidGlassCurves.liquid),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.color ?? theme.iconTheme.color;
    final bgColor = widget.backgroundColor ??
        (theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05));

    Widget button = MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: widget.onPressed,
              child: AnimatedContainer(
                duration: AppConstants.hoverDuration,
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: _isHovered ? bgColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Icon(
                  widget.icon,
                  size: widget.size,
                  color: iconColor,
                ),
              ),
            ),
          );
        },
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}

/// Liquid Glass Text Field
class LiquidGlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool enabled;

  const LiquidGlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
    this.focusNode,
    this.enabled = true,
  });

  @override
  State<LiquidGlassTextField> createState() => _LiquidGlassTextFieldState();
}

class _LiquidGlassTextFieldState extends State<LiquidGlassTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: AppConstants.hoverDuration,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        color: isDark
            ? Colors.white.withValues(alpha: _isFocused ? 0.1 : 0.05)
            : Colors.black.withValues(alpha: _isFocused ? 0.05 : 0.03),
        border: Border.all(
          color: _isFocused
              ? theme.primaryColor
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          width: _isFocused ? 2 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hintText,
          labelText: widget.labelText,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Floating Navigation Bar
class LiquidGlassNavBar extends StatelessWidget {
  final Widget child;
  final double height;
  final EdgeInsetsGeometry margin;

  const LiquidGlassNavBar({
    super.key,
    required this.child,
    this.height = AppConstants.navBarHeightFull,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppConstants.spacingM,
      vertical: AppConstants.spacingS,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: LiquidGlassContainer(
        borderRadius: AppConstants.radiusNavBar,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
        height: height,
        animateOnHover: false,
        child: child,
      ),
    );
  }
}

/// Typing indicator with animated dots
class LiquidGlassTypingIndicator extends StatefulWidget {
  final Color? color;

  const LiquidGlassTypingIndicator({super.key, this.color});

  @override
  State<LiquidGlassTypingIndicator> createState() =>
      _LiquidGlassTypingIndicatorState();
}

class _LiquidGlassTypingIndicatorState extends State<LiquidGlassTypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with staggered delay
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).primaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -4 * _animations[index].value),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.6 + 0.4 * _animations[index].value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
