import 'dart:io';
import 'package:flutter/services.dart';

class ClipboardService {
  static bool? _isWayland;
  
  /// Detect if running on Wayland
  static bool _isRunningOnWayland() {
    if (_isWayland != null) return _isWayland!;
    
    // Check WAYLAND_DISPLAY environment variable (most reliable)
    final waylandDisplay = Platform.environment['WAYLAND_DISPLAY'];
    if (waylandDisplay != null && waylandDisplay.isNotEmpty) {
      _isWayland = true;
      return true;
    }
    
    // Check XDG_SESSION_TYPE
    final sessionType = Platform.environment['XDG_SESSION_TYPE'];
    if (sessionType == 'wayland') {
      _isWayland = true;
      return true;
    }
    
    // Check if XDG_SESSION_TYPE is explicitly x11 (definitely not Wayland)
    if (sessionType == 'x11') {
      _isWayland = false;
      return false;
    }
    
    // Fallback: check DISPLAY (X11 indicator)
    final display = Platform.environment['DISPLAY'];
    if (display != null && display.isNotEmpty) {
      _isWayland = false;
      return false;
    }
    
    // Default to false if unsure (X11/xclip is more commonly available)
    _isWayland = false;
    return false;
  }
  
  /// Sets text to both CLIPBOARD and PRIMARY selections on Linux
  /// Uses appropriate tool for display server (xclip for X11, wl-copy for Wayland)
  static Future<void> setText(String text) async {
    // Always set standard clipboard (Ctrl+C / Ctrl+V)
    await Clipboard.setData(ClipboardData(text: text));
    
    // On Linux, also set PRIMARY selection for middle-click paste
    if (Platform.isLinux) {
      try {
        if (_isRunningOnWayland()) {
          // Use wl-copy for Wayland
          // wl-copy automatically sets both CLIPBOARD and PRIMARY on Wayland
          final process = await Process.start('wl-copy', [],
              runInShell: true);
          process.stdin.write(text);
          await process.stdin.close();
          await process.exitCode.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              process.kill();
              return -1;
            },
          );
        } else {
          // Use xclip for X11
          final process = await Process.start('xclip', ['-selection', 'primary'],
              runInShell: true);
          process.stdin.write(text);
          await process.stdin.close();
          await process.exitCode.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              process.kill();
              return -1;
            },
          );
        }
      } catch (e) {
        // Clipboard tools may not be available, silently fail
        // Standard clipboard is already set above
      }
    }
  }
}
