import 'package:flutter/material.dart';

ThemeData buildVibeCoderTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C3AED),
    brightness: brightness,
  );

  final isDark = brightness == Brightness.dark;
  final cyber = scheme.copyWith(
    primary: const Color(0xFF22D3EE),
    secondary: const Color(0xFFA78BFA),
    tertiary: const Color(0xFF34D399),
    surface: isDark ? const Color(0xFF050814) : scheme.surface,
    surfaceContainerHighest: isDark
        ? const Color(0xFF0B1022)
        : scheme.surfaceContainerHighest,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cyber,
    appBarTheme: AppBarTheme(
      backgroundColor: cyber.surface,
      foregroundColor: cyber.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cyber.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? Colors.white10 : cyber.surfaceContainerHighest,
      side: BorderSide(color: isDark ? Colors.white12 : cyber.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );
}
