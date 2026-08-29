import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF6F47F5);
  static const pageBackground = Color(0xFFF8F8F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceTint = Color(0xFFFBF0FF);
  static const surfaceTintStrong = Color(0xFFF1EEFA);
  static const textPrimary = Color(0xFF333333);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFF999999);
  static const outline = Color(0xFFE7E7E7);
  static const outlineVariant = Color(0xFFEDEDED);
  static const success = Color(0xFF3E975B);
}

abstract final class AppRadii {
  static const double small = 8;
  static const double medium = 12;
  static const double card = 20;
  static const double control = 24;
  static const double pill = 100;
}

class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    );
    final colorScheme = brightness == Brightness.light
        ? generatedScheme.copyWith(
            primary: AppColors.brand,
            onPrimary: AppColors.surface,
            primaryContainer: AppColors.surfaceTint,
            onPrimaryContainer: AppColors.textPrimary,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            surfaceContainerHighest: AppColors.surfaceTintStrong,
            onSurfaceVariant: AppColors.textSecondary,
            outline: AppColors.outline,
            outlineVariant: AppColors.outlineVariant,
          )
        : generatedScheme;
    final pageBackground = brightness == Brightness.light
        ? AppColors.pageBackground
        : colorScheme.surface;
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    final pillShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: pageBackground,
      canvasColor: pageBackground,
      dividerColor: colorScheme.outline,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: pageBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.card),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: pillShape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: pillShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pillShape,
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(controlShape)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.primaryContainer,
        side: BorderSide.none,
        shape: controlShape,
      ),
    );
  }
}
