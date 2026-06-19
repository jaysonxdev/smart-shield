import 'package:flutter/material.dart';

extension AppThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Main surface — card / container backgrounds.
  Color get surface => isDark ? const Color(0xFF0F1116) : Colors.white;

  /// Slightly elevated surface — chat bubbles, input fill.
  Color get surfaceVariant =>
      isDark ? const Color(0xFF1A1D23) : const Color(0xFFF0F2F5);

  /// Dividers and border lines.
  Color get cardBorder =>
      isDark ? const Color(0xFF22242A) : const Color(0xFFE0E3E8);

  /// High-contrast body text.
  Color get primaryText =>
      isDark ? Colors.white : const Color(0xFF1A1D23);

  /// Secondary / subdued text.
  Color get secondaryText =>
      isDark ? Colors.white70 : const Color(0xFF444852);

  /// Hint / caption text.
  Color get subtleText =>
      isDark ? Colors.grey : const Color(0xFF6B7280);

  /// Centre circle background in the scan animation.
  Color get scanCircleBg =>
      isDark ? const Color(0xFF0B0F14) : const Color(0xFFE8EDF2);

  /// Shield icon and orbit dot inside the scan animation.
  Color get scanAccentColor =>
      isDark ? Colors.white : const Color(0xFF1A7FD4);
}
