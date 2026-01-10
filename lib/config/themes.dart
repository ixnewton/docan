import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Liquid Glass Theme Variants
enum LiquidGlassTheme {
  clear, // Maximum transparency (OLED-friendly)
  light, // Light frosted glass
  dark, // Dark frosted glass
  tinted, // High contrast with color tints
}

/// Liquid Glass Design System Colors
class LiquidGlassColors {
  LiquidGlassColors._();

  // Light Theme
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  static const Color lightAccent = Color(0xFF007AFF);
  static const Color lightBorder = Color(0xFFE5E5EA);

  // Dark Theme
  static const Color darkBackground = Color(0xFF1C1C1E);
  static const Color darkCard = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF98989D);
  static const Color darkAccent = Color(0xFF0A84FF);
  static const Color darkBorder = Color(0xFF38383A);

  // Clear (OLED) Theme
  static const Color clearBackground = Color(0xFF000000);
  static const Color clearCard = Color(0xFF0A0A0A);
  static const Color clearTextPrimary = Color(0xFFFFFFFF);
  static const Color clearTextSecondary = Color(0xFF8E8E93);
  static const Color clearAccent = Color(0xFF0A84FF);
  static const Color clearBorder = Color(0xFF1C1C1E);

  // Accent Color Options for Tinted Theme
  static const List<Color> accentColors = [
    Color(0xFF007AFF), // Blue
    Color(0xFF5856D6), // Purple
    Color(0xFFFF2D55), // Pink
    Color(0xFFFF9500), // Orange
    Color(0xFF34C759), // Green
    Color(0xFFFF3B30), // Red
    Color(0xFFAF52DE), // Violet
    Color(0xFF00C7BE), // Teal
  ];

  // Message Bubble Colors
  static const Color userBubbleLight = Color(0xFF007AFF);
  static const Color userBubbleDark = Color(0xFF0A84FF);
  static const Color aiBubbleLight = Color(0xFFCFCFD1);
  static const Color aiBubbleDark = Color(0xFF1C1C1E);
}

/// Liquid Glass Design System
class LiquidGlassThemes {
  LiquidGlassThemes._();

  /// Get the appropriate blur intensity for a theme
  static double getBlurIntensity(LiquidGlassTheme theme) {
    switch (theme) {
      case LiquidGlassTheme.clear:
        return 40.0;
      case LiquidGlassTheme.light:
        return 30.0;
      case LiquidGlassTheme.dark:
        return 30.0;
      case LiquidGlassTheme.tinted:
        return 25.0;
    }
  }

  /// Get card opacity for a theme
  static double getCardOpacity(LiquidGlassTheme theme) {
    switch (theme) {
      case LiquidGlassTheme.clear:
        return 0.85;
      case LiquidGlassTheme.light:
        return 0.60;
      case LiquidGlassTheme.dark:
        return 0.70;
      case LiquidGlassTheme.tinted:
        return 0.80;
    }
  }

  /// Create SF Pro-like text theme
  static TextTheme _createTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: primaryColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: primaryColor,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: primaryColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: primaryColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: primaryColor,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: primaryColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: primaryColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: primaryColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        color: primaryColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.normal,
        letterSpacing: -0.4,
        color: primaryColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        letterSpacing: -0.2,
        color: primaryColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        letterSpacing: -0.1,
        color: secondaryColor,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: primaryColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        color: primaryColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: secondaryColor,
      ),
    );
  }

  /// Light Theme
  static ThemeData lightTheme({Color? accentColor}) {
    final accent = accentColor ?? LiquidGlassColors.lightAccent;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: LiquidGlassColors.lightBackground,
      primaryColor: accent,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: accent.withValues(alpha: 0.8),
        surface: LiquidGlassColors.lightCard,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: LiquidGlassColors.lightTextPrimary,
      ),
      cardColor: LiquidGlassColors.lightCard.withValues(alpha: 0.6),
      dividerColor: LiquidGlassColors.lightBorder,
      textTheme: _createTextTheme(
        LiquidGlassColors.lightTextPrimary,
        LiquidGlassColors.lightTextSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: LiquidGlassColors.lightBackground.withValues(alpha: 0.8),
        foregroundColor: LiquidGlassColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: LiquidGlassColors.lightTextPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LiquidGlassColors.lightCard.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: LiquidGlassColors.lightBorder.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: accent,
        brightness: Brightness.light,
      ),
    );
  }

  /// Dark Theme
  static ThemeData darkTheme({Color? accentColor}) {
    final accent = accentColor ?? LiquidGlassColors.darkAccent;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: LiquidGlassColors.darkBackground,
      primaryColor: accent,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: accent.withValues(alpha: 0.8),
        surface: LiquidGlassColors.darkCard,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: LiquidGlassColors.darkTextPrimary,
      ),
      cardColor: LiquidGlassColors.darkCard.withValues(alpha: 0.7),
      dividerColor: LiquidGlassColors.darkBorder,
      textTheme: _createTextTheme(
        LiquidGlassColors.darkTextPrimary,
        LiquidGlassColors.darkTextSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: LiquidGlassColors.darkBackground.withValues(alpha: 0.8),
        foregroundColor: LiquidGlassColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: LiquidGlassColors.darkTextPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LiquidGlassColors.darkCard.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: LiquidGlassColors.darkBorder.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: accent,
        brightness: Brightness.dark,
      ),
    );
  }

  /// Clear (OLED) Theme
  static ThemeData clearTheme({Color? accentColor}) {
    final accent = accentColor ?? LiquidGlassColors.clearAccent;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: LiquidGlassColors.clearBackground,
      primaryColor: accent,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: accent.withValues(alpha: 0.8),
        surface: LiquidGlassColors.clearCard,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: LiquidGlassColors.clearTextPrimary,
      ),
      cardColor: LiquidGlassColors.clearCard.withValues(alpha: 0.85),
      dividerColor: LiquidGlassColors.clearBorder,
      textTheme: _createTextTheme(
        LiquidGlassColors.clearTextPrimary,
        LiquidGlassColors.clearTextSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: LiquidGlassColors.clearBackground.withValues(alpha: 0.9),
        foregroundColor: LiquidGlassColors.clearTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: LiquidGlassColors.clearTextPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LiquidGlassColors.clearCard.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: LiquidGlassColors.clearBorder.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: accent,
        brightness: Brightness.dark,
      ),
    );
  }

  /// Get theme data based on LiquidGlassTheme
  static ThemeData getTheme(LiquidGlassTheme theme, {Color? accentColor}) {
    switch (theme) {
      case LiquidGlassTheme.clear:
        return clearTheme(accentColor: accentColor);
      case LiquidGlassTheme.light:
        return lightTheme(accentColor: accentColor);
      case LiquidGlassTheme.dark:
        return darkTheme(accentColor: accentColor);
      case LiquidGlassTheme.tinted:
        // Tinted uses light or dark as base with higher opacity
        return lightTheme(accentColor: accentColor);
    }
  }
}
