import 'package:flutter/material.dart';
import 'package:go_proj/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Material(
      color: scheme.surface.withOpacity(0.9),
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: scheme.primary.withOpacity(0.25),
      child: IconButton(
        icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        onPressed: () => controller.toggleFromBrightness(brightness),
        tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      ),
    );
  }
}
