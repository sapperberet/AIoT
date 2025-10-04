import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF00D4FF);
  static const Color accentColor = Color(0xFFFF6584);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6584), Color(0xFFFF8DA1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E2E), Color(0xFF2A2A3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F0F1E);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF0F4F8);

  // Text Colors
  static const Color darkText = Color(0xFF1A1A2E);
  static const Color lightText = Color(0xFFE8E8F0);
  static const Color mutedText = Color(0xFF9E9E9E);

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> glowShadow = [
    BoxShadow(
      color: primaryColor.withOpacity(0.3),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  // Border Radius
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(24));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(32));

  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: darkSurface,
        background: darkBackground,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightText,
        onBackground: lightText,
        onError: Colors.white,
      ),
      
      // Text Theme
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: lightText,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: lightText,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: lightText,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightText,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightText,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: lightText,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          color: lightText,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: lightText,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          color: mutedText,
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: mediumRadius,
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: lightText),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightText,
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: mediumRadius,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: mediumRadius,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: darkSurface.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.poppins(color: mutedText),
        labelStyle: GoogleFonts.poppins(color: lightText),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 8,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: mutedText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
        ),
      ),

      // Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: darkBackground,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: lightSurface,
        background: lightBackground,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkText,
        onBackground: darkText,
        onError: Colors.white,
      ),
      
      // Text Theme
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkText,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          color: darkText,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: darkText,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          color: mutedText,
        ),
      ),

      // Similar configurations for light theme...
      cardTheme: CardTheme(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: mediumRadius,
        ),
      ),
      // ... rest of the theme configurations
    );
  }
}
