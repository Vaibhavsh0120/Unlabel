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
          surface: dark ? const Color(0xff101214) : const Color(0xfffbfdfc),
          surfaceContainerLowest: dark ? const Color(0xff0d0f10) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xff171b1e)
              : const Color(0xfff5faf7),
          surfaceContainer: dark
              ? const Color(0xff1b1f22)
              : const Color(0xfff1f6f3),
          surfaceContainerHigh: dark
              ? const Color(0xff242a2e)
              : const Color(0xffeaf2ed),
          surfaceContainerHighest: dark
              ? const Color(0xff2c3338)
              : const Color(0xffe4ede7),
          onSurface: dark ? const Color(0xfff4f6f7) : const Color(0xff0b102a),
          onSurfaceVariant: dark
              ? const Color(0xffb6bec5)
              : const Color(0xff687999),
          outlineVariant: dark
              ? const Color(0xff3e474c)
              : const Color(0xffdce8e1),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
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
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
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
        color: dark ? const Color(0xff1b1f22) : Colors.white,
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
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        fillColor: dark ? const Color(0xff1b1f22) : Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
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
