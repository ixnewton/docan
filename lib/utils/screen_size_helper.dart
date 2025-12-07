import 'package:flutter/widgets.dart';
import '../config/constants.dart';

/// Screen size categories
enum ScreenSize {
  mobile,
  tablet,
  desktop,
}

/// Helper class for responsive layouts
class ScreenSizeHelper {
  ScreenSizeHelper._();

  /// Get the current screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < AppConstants.mobileBreakpoint) {
      return ScreenSize.mobile;
    } else if (width < AppConstants.tabletBreakpoint) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.desktop;
    }
  }

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return getScreenSize(context) == ScreenSize.mobile;
  }

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    return getScreenSize(context) == ScreenSize.tablet;
  }

  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return getScreenSize(context) == ScreenSize.desktop;
  }

  /// Check if should show mobile layout (mobile or tablet)
  static bool shouldShowMobileLayout(BuildContext context) {
    final size = getScreenSize(context);
    return size == ScreenSize.mobile || size == ScreenSize.tablet;
  }

  /// Check if should show desktop layout
  static bool shouldShowDesktopLayout(BuildContext context) {
    return getScreenSize(context) == ScreenSize.desktop;
  }

  /// Get screen width
  static double getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double getHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Get safe area insets
  static EdgeInsets getSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get appropriate sidebar width
  static double getSidebarWidth(BuildContext context) {
    if (isDesktop(context)) {
      return AppConstants.sidebarWidth;
    }
    return getWidth(context) * 0.85; // 85% for mobile drawer
  }

  /// Get maximum message bubble width
  static double getMaxBubbleWidth(BuildContext context) {
    final width = getWidth(context);
    if (isDesktop(context)) {
      return width * 0.5; // 50% on desktop
    }
    return width * AppConstants.bubbleMaxWidthRatio; // 75% on mobile
  }

  /// Get appropriate padding based on screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return const EdgeInsets.all(AppConstants.spacingM);
      case ScreenSize.tablet:
        return const EdgeInsets.all(AppConstants.spacingL);
      case ScreenSize.desktop:
        return const EdgeInsets.all(AppConstants.spacingXL);
    }
  }
}

/// Responsive widget builder
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize size) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, ScreenSizeHelper.getScreenSize(context));
  }
}

/// Layout switcher between mobile and desktop
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final size = ScreenSizeHelper.getScreenSize(context);
    
    switch (size) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop;
    }
  }
}
