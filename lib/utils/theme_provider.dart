import 'package:flutter/material.dart';

/// Theme provider for managing Material Design themes
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  Color _accentColor = Colors.blue;
  bool _followSystem = true;

  bool get isDarkMode => _isDarkMode;
  Color get accentColor => _accentColor;
  bool get followSystem => _followSystem;

  /// Get theme mode for MaterialApp
  ThemeMode get themeMode {
    if (_followSystem) {
      return ThemeMode.system;
    }
    return _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  /// Get light theme for MaterialApp
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentColor,
        brightness: Brightness.light,
      ),
    );
  }

  /// Get dark theme for MaterialApp
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentColor,
        brightness: Brightness.dark,
      ),
    );
  }

  /// Set dark mode
  void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
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
      _isDarkMode = brightness == Brightness.dark;
      notifyListeners();
    }
  }

  /// Load theme from stored preferences
  void loadFromPreferences({
    bool? isDarkMode,
    Color? accentColor,
    bool? followSystem,
  }) {
    if (isDarkMode != null) _isDarkMode = isDarkMode;
    if (accentColor != null) _accentColor = accentColor;
    if (followSystem != null) _followSystem = followSystem;
    notifyListeners();
  }
}
