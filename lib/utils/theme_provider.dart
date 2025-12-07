import 'package:flutter/material.dart';
import '../config/themes.dart';

/// Theme provider for managing Liquid Glass themes
class ThemeProvider extends ChangeNotifier {
  LiquidGlassTheme _theme = LiquidGlassTheme.light;
  Color _accentColor = LiquidGlassColors.lightAccent;
  bool _followSystem = true;

  LiquidGlassTheme get theme => _theme;
  Color get accentColor => _accentColor;
  bool get followSystem => _followSystem;

  /// Get the current ThemeData
  ThemeData get themeData {
    return LiquidGlassThemes.getTheme(_theme, accentColor: _accentColor);
  }

  /// Get theme mode for MaterialApp
  ThemeMode get themeMode {
    if (_followSystem) {
      return ThemeMode.system;
    }
    switch (_theme) {
      case LiquidGlassTheme.light:
      case LiquidGlassTheme.tinted:
        return ThemeMode.light;
      case LiquidGlassTheme.dark:
      case LiquidGlassTheme.clear:
        return ThemeMode.dark;
    }
  }

  /// Get light theme for MaterialApp
  ThemeData get lightTheme {
    if (_theme == LiquidGlassTheme.tinted) {
      return LiquidGlassThemes.lightTheme(accentColor: _accentColor);
    }
    return LiquidGlassThemes.lightTheme(accentColor: _accentColor);
  }

  /// Get dark theme for MaterialApp
  ThemeData get darkTheme {
    if (_theme == LiquidGlassTheme.clear) {
      return LiquidGlassThemes.clearTheme(accentColor: _accentColor);
    }
    return LiquidGlassThemes.darkTheme(accentColor: _accentColor);
  }

  /// Set the Liquid Glass theme
  void setTheme(LiquidGlassTheme theme) {
    _theme = theme;
    _followSystem = false;
    notifyListeners();
  }

  /// Set the accent color
  void setAccentColor(Color color) {
    _accentColor = color;
    notifyListeners();
  }

  /// Toggle follow system setting
  void setFollowSystem(bool follow) {
    _followSystem = follow;
    notifyListeners();
  }

  /// Update theme based on system brightness
  void updateFromSystemBrightness(Brightness brightness) {
    if (_followSystem) {
      if (brightness == Brightness.dark) {
        _theme = LiquidGlassTheme.dark;
      } else {
        _theme = LiquidGlassTheme.light;
      }
      notifyListeners();
    }
  }

  /// Get blur intensity for current theme
  double get blurIntensity => LiquidGlassThemes.getBlurIntensity(_theme);

  /// Get card opacity for current theme
  double get cardOpacity => LiquidGlassThemes.getCardOpacity(_theme);

  /// Check if current theme is dark
  bool get isDark =>
      _theme == LiquidGlassTheme.dark || _theme == LiquidGlassTheme.clear;

  /// Load theme from stored preferences
  void loadFromPreferences({
    LiquidGlassTheme? theme,
    Color? accentColor,
    bool? followSystem,
  }) {
    if (theme != null) _theme = theme;
    if (accentColor != null) _accentColor = accentColor;
    if (followSystem != null) _followSystem = followSystem;
    notifyListeners();
  }
}
