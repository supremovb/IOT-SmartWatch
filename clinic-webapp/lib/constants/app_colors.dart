import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFFDC2626); // Red
  static const Color accent = Color(0xFF00C853); // Normal green
  static const Color warning = Color(0xFFFFB300); // Amber
  static const Color danger = Color(0xFFB91C1C); // Dark Red

  // Neutral colors (LIGHT mode defaults — prefer themed() for dark mode support)
  static const Color background = Color(0xFFFAFAFA);
  static const Color lightOffWhite = Color(0xFFFFF9F5);
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color borderColor = Color(0xFFE0E0E0);

  // Status colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color inactive = Color(0xFFFF9800);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  static const Color warning2 = Color(0xFFFFC107);
  
  // Decorative Colors
  static const Color softOrange = Color(0xFFFFAB91);
  static const Color vibrantOrange = Color(0xFFFF5722);
  static const Color signinGreen = Color(0xFF00C853);

  /// Theme-aware colors — use these in widgets for proper dark mode support.
  static Themed themed(BuildContext context) => Themed(context);
}

class Themed {
  final BuildContext _ctx;
  Themed(this._ctx);

  ColorScheme get _cs => Theme.of(_ctx).colorScheme;
  bool get _isDark => Theme.of(_ctx).brightness == Brightness.dark;

  // Dark-mode-aware reds — ~60% darker to reduce glare
  Color get primary => _isDark ? const Color(0xFF991B1B) : AppColors.primary;
  Color get danger  => _isDark ? const Color(0xFF7F1D1D) : AppColors.danger;
  Color get error   => _isDark ? const Color(0xFF991B1B) : AppColors.error;
  Color get warning => _isDark ? const Color(0xFF92400E) : AppColors.warning;
  Color get accent  => _isDark ? const Color(0xFF047857) : AppColors.accent;
  Color get info    => _isDark ? const Color(0xFF1E40AF) : AppColors.info;

  Color get background => _cs.surface;
  Color get surface => _cs.surfaceContainerLowest;
  Color get surfaceContainer => _cs.surfaceContainer;
  Color get textPrimary => _cs.onSurface;
  Color get textSecondary => _cs.onSurfaceVariant;
  Color get textHint => _isDark ? Colors.grey.shade600 : const Color(0xFFBDBDBD);
  Color get divider => _cs.outlineVariant;
  Color get border => _cs.outline;
  Color get card => _cs.surfaceContainerLow;
  Color get inputFill => _isDark ? _cs.surfaceContainerHigh : Colors.white;
  Color get chatBg => _isDark ? _cs.surfaceContainerLowest : const Color(0xFFFAFAFA);
}
