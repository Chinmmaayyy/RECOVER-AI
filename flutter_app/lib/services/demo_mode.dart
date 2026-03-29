/// Global Demo Mode state — shared across screens.
/// Activated by tapping patient name 5 times quickly.
class DemoMode {
  static bool _active = false;

  static bool get isActive => _active;

  static void toggle() {
    _active = !_active;
  }

  static void deactivate() {
    _active = false;
  }
}
