import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SoundSense Professional Dark Theme
/// A modern, clean, and accessible design system
class AppTheme {
  // ============================================================
  // COLOR PALETTE
  // ============================================================
  
  // Primary Colors
  static const Color primary = Color(0xFF6C63FF);        // Vibrant purple
  static const Color primaryLight = Color(0xFF9D97FF);   // Light purple
  static const Color primaryDark = Color(0xFF4A42D9);    // Dark purple
  
  // Accent Colors
  static const Color accent = Color(0xFF00D9FF);         // Cyan
  static const Color accentGreen = Color(0xFF00E676);    // Bright green
  static const Color accentOrange = Color(0xFFFFAB40);   // Warm orange
  
  // Status Colors
  static const Color success = Color(0xFF00E676);        // Green
  static const Color warning = Color(0xFFFFAB40);        // Orange
  static const Color error = Color(0xFFFF5252);          // Red
  static const Color info = Color(0xFF40C4FF);           // Blue
  
  // Background Colors
  static const Color backgroundDark = Color(0xFF0D0D0D);    // Pure dark
  static const Color backgroundPrimary = Color(0xFF121212); // Primary background
  static const Color backgroundSecondary = Color(0xFF1E1E1E); // Cards background
  static const Color backgroundTertiary = Color(0xFF2A2A2A);  // Elevated surfaces
  
  // Surface Colors
  static const Color surfaceLight = Color(0xFF333333);
  static const Color surfaceMedium = Color(0xFF2A2A2A);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);    // White
  static const Color textSecondary = Color(0xFFB3B3B3);  // Light gray
  static const Color textTertiary = Color(0xFF808080);   // Medium gray
  static const Color textDisabled = Color(0xFF4D4D4D);   // Dark gray
  
  // Border Colors
  static const Color borderLight = Color(0xFF3D3D3D);
  static const Color borderMedium = Color(0xFF2D2D2D);
  
  // Special Colors for Sound Categories
  static const Color soundCritical = Color(0xFFFF5252);
  static const Color soundImportant = Color(0xFFFFAB40);
  static const Color soundNormal = Color(0xFF00E676);
  static const Color soundCustom = Color(0xFF6C63FF);
  
  // ============================================================
  // GRADIENTS
  // ============================================================
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF9D4EDD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF7B2CBF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================
  // SHADOWS
  // ============================================================
  
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
  
  static List<BoxShadow> cardShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.2),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ============================================================
  // BORDER RADIUS
  // ============================================================
  
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 32.0;
  
  // ============================================================
  // SPACING
  // ============================================================
  
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ============================================================
  // TEXT STYLES
  // ============================================================
  
  static TextStyle get displayLarge => GoogleFonts.poppins(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -1,
  );
  
  static TextStyle get displayMedium => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static TextStyle get displaySmall => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static TextStyle get headlineLarge => GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get headlineMedium => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get headlineSmall => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textTertiary,
  );
  
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
  );
  
  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );
  
  static TextStyle get buttonText => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
  );

  // ============================================================
  // THEME DATA
  // ============================================================
  
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundPrimary,
    
    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: backgroundSecondary,
      error: error,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
      onSurface: textPrimary,
      onError: textPrimary,
    ),
    
    // App Bar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headlineMedium,
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    
    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: backgroundSecondary,
      selectedItemColor: primary,
      unselectedItemColor: textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      color: backgroundSecondary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLG),
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundTertiary,
      hintStyle: bodyMedium.copyWith(color: textTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: borderMedium),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMD,
        vertical: spacingMD,
      ),
    ),
    
    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLG,
          vertical: spacingMD,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        textStyle: buttonText,
      ),
    ),
    
    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: buttonText,
      ),
    ),
    
    // Icon Theme
    iconTheme: const IconThemeData(
      color: textPrimary,
      size: 24,
    ),
    
    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: borderMedium,
      thickness: 1,
    ),
    
    // Snackbar Theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: backgroundTertiary,
      contentTextStyle: bodyMedium.copyWith(color: textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMD),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    
    // Switch Theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary.withOpacity(0.3);
        return surfaceLight;
      }),
    ),
    
    // Slider Theme
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: surfaceLight,
      thumbColor: primary,
      overlayColor: primary.withOpacity(0.2),
    ),
    
    // Progress Indicator Theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primary,
    ),
    
    // Floating Action Button Theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: textPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLG),
      ),
    ),
    
    // Dialog Theme
    dialogTheme: DialogThemeData(
      backgroundColor: backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXL),
      ),
      titleTextStyle: headlineMedium,
      contentTextStyle: bodyMedium,
    ),
    
    // Bottom Sheet Theme
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
      ),
    ),
  );
}

// ============================================================
// CUSTOM WIDGETS STYLES
// ============================================================

/// Professional gradient card decoration
BoxDecoration gradientCard({
  required List<Color> colors,
  double radius = AppTheme.radiusLG,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: colors.map((c) => c.withOpacity(0.15)).toList(),
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: colors.first.withOpacity(0.3),
    ),
  );
}

/// Glass morphism effect
BoxDecoration glassCard({
  Color color = AppTheme.backgroundSecondary,
  double radius = AppTheme.radiusLG,
  double opacity = 0.8,
}) {
  return BoxDecoration(
    color: color.withOpacity(opacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Colors.white.withOpacity(0.1),
    ),
  );
}

/// Status color helper
Color getStatusColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return AppTheme.soundCritical;
    case 'important':
      return AppTheme.soundImportant;
    case 'custom':
      return AppTheme.soundCustom;
    default:
      return AppTheme.soundNormal;
  }
}
