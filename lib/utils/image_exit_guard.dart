/// Global registry for the image creator's unsaved-image exit guard, so the
/// window-close handler can consult the active image screen before the
/// application closes.
class ImageExitGuard {
  ImageExitGuard._();

  static Future<bool> Function()? _guard;

  /// Registers the active image screen's exit confirmation. The callback
  /// returns true when closing may proceed.
  static void register(Future<bool> Function() guard) => _guard = guard;

  static void unregister() => _guard = null;

  /// Returns true when closing may proceed.
  static Future<bool> confirmExit() async {
    final guard = _guard;
    if (guard == null) return true;
    return guard();
  }
}
