import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ===== COLORS =====
  // Background Colors (static - don't change)
  static const Color background = Colors.white;
  static const Color surface = Color(0xFFF5F5F5);
  static const Color card = Colors.white;

  // Text Colors (static - don't change)
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textLight = Colors.white;

  // Accent Colors (will be provided by ThemeService)
  static Color accent = Colors.deepPurple; // This will be updated dynamically
  static Color accentLight = Color(0xFFB39DDB);
  static Color accentDark = Color(0xFF512DA8);

  // Status Colors (static)
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Border & Divider (static)
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFEEEEEE);

  // Shadow (static)
  static const Color shadow = Color(0x1A000000);

  // Icon Colors (depends on accent)
  static Color get iconActive => accent;
  static const Color iconInactive = Color(0xFFBDBDBD);

  // Gradient (depends on accent)
  static List<Color> get nowPlayingGradient => [
    accent,
    Colors.black,
  ];

  // ===== THEME DATA =====
  static ThemeData getLightTheme(Color accentColor) {
    accent = accentColor; // Update the accent color

    return ThemeData.light().copyWith(
      // Colors
      primaryColor: accent,
      scaffoldBackgroundColor: background,
      cardColor: card,

      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: accent,
        surface: surface,
        background: background,
        error: error,
        onPrimary: textLight,
        onSecondary: textLight,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textLight,
      ),

      // Text Theme
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        headlineLarge: const TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
        headlineMedium: const TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
        headlineSmall: const TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: const TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w500),
        titleSmall: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: const TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: const TextStyle(color: textSecondary, fontSize: 14),
        bodySmall: const TextStyle(color: textHint, fontSize: 12),
        labelLarge: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w600),
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: accent,
        foregroundColor: textLight,
        elevation: 0,
        titleTextStyle: const TextStyle(color: textLight, fontSize: 20, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: textLight),
      ),

      // Icons
      iconTheme: IconThemeData(color: accent, size: 24),

      // Cards
      cardTheme: CardThemeData(
        color: card,
        elevation: 2,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(color: divider, thickness: 1, space: 1),

      // Tab Bar
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: iconInactive,
        indicatorColor: accent,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: divider,
        thumbColor: accent,
        overlayColor: accent.withOpacity(0.2),
        valueIndicatorColor: accent,
      ),

      // Progress Indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: divider,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: background,
        modalBackgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: accent,
        contentTextStyle: const TextStyle(color: textLight),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Dialog
      dialogTheme: const DialogThemeData(
        backgroundColor: background,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: textSecondary, fontSize: 16),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: textLight,
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        fillColor: surface,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        iconColor: accent,
        textColor: textPrimary,
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accent;
          }
          return null;
        }),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accent;
          }
          return null;
        }),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accent;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accent.withOpacity(0.5);
          }
          return null;
        }),
      ),
    );
  }
}