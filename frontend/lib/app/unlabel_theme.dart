import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class UnlabelTheme {
  static ThemeData forBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xff155b4b),
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xff70ebba) : const Color(0xff155b4b),
          onPrimary: dark ? const Color(0xff10251e) : Colors.white,
          primaryContainer: dark
              ? const Color(0xff1d332b)
              : const Color(0xffd8f4e8),
          onPrimaryContainer: dark
              ? const Color(0xffc6f4df)
              : const Color(0xff0d483b),
          surface: dark ? const Color(0xff101214) : const Color(0xfff4f8f6),
          surfaceContainerLowest: dark ? const Color(0xff141618) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xff1b1e21)
              : const Color(0xffedf5f1),
          surfaceContainer: dark
              ? const Color(0xff222529)
              : const Color(0xfff1f6f3),
          surfaceContainerHigh: dark
              ? const Color(0xff292d31)
              : const Color(0xffeaf2ed),
          surfaceContainerHighest: dark
              ? const Color(0xff32373c)
              : const Color(0xffe4ede7),
          onSurface: dark ? const Color(0xffedf5f2) : const Color(0xff162f32),
          onSurfaceVariant: dark
              ? const Color(0xffbdc5c8)
              : const Color(0xff51666a),
          outlineVariant: dark
              ? const Color(0xff41464c)
              : const Color(0xffd5e4de),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: scheme.outlineVariant),
    );
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: scheme.surface,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        displayMedium: base.textTheme.displayMedium?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontFamily: 'Manrope',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontFamily: 'Manrope',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          height: 1.5,
          letterSpacing: -.15,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
          letterSpacing: -.1,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: scheme.surface,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        ),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xff1d2023) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xff1b1e21) : Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 32),
    );
  }
}
