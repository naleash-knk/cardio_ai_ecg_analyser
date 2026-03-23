import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void setMode(ThemeMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }

  void toggleFromBrightness(Brightness brightness) {
    final nextMode =
        brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    setMode(nextMode);
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    // Read without creating an inherited dependency. Theme updates already
    // rebuild via MaterialApp + Theme.of(context), and this avoids teardown
    // dependency assertions for ThemeScope.
    final element = context.getElementForInheritedWidgetOfExactType<ThemeScope>();
    final scope = element?.widget as ThemeScope?;
    assert(scope != null, 'ThemeScope not found in widget tree.');
    return scope!.notifier!;
  }
}
