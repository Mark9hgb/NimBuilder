import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme Colors
  static const Color primaryColor = Color(0xFF6750A4);
  static const Color secondaryColor = Color(0xFF625B71);
  static const Color tertiaryColor = Color(0xFF7D5260);
  static const Color backgroundColor = Color(0xFFFFFBFE);
  static const Color surfaceColor = Color(0xFFF3EDF7);
  static const Color errorColor = Color(0xFFB3261E);
  
  // Dark Theme Colors  
  static const Color darkPrimaryColor = Color(0xFFD0BCFF);
  static const Color darkSecondaryColor = Color(0xFFCCC2DC);
  static const Color darkTertiaryColor = Color(0xFFEFB8C8);
  static const Color darkBackgroundColor = Color(0xFF1C1B1F);
  static const Color darkSurfaceColor = Color(0xFF2B2930);
  static const Color darkErrorColor = Color(0xFFF2B8B5);
  
  // Glassmorphism
  static const Color glassWhite = Color(0x80FFFFFF);
  static const Color glassBlack = Color(0x80000000);
  static const Color glassBorder = Color(0x40FFFFFF);
  static const Color glassBorderDark = Color(0x40FFFFFF);
  
  // Message Colors
  static const Color userBubble = Color(0xFF6750A4);
  static const Color aiBubble = Color(0xFFE8DEF8);
  static const Color darkUserBubble = Color(0xFFD0BCFF);
  static const Color darkAiBubble = Color(0xFF49454F);
  
  static const Color userText = Color(0xFFFFFFFF);
  static const Color aiText = Color(0xFF1D1B20);
  static const Color darkUserText = Color(0xFF381E72);
  static const Color darkAiText = Color(0xFFE6E1E5);
  
  // Code Colors
  static const Color codeBackground = Color(0xFF1E1E2E);
  static const Color codeText = Color(0xFFCDD6F4);
  static const Color terminalBackground = Color(0xFF0D0D0D);
  static const Color terminalText = Color(0xFF00FF00);
  static const Color terminalPrompt = Color(0xFF00FFFF);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: aiText,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: aiText,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryColor.withAlpha(40),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: darkPrimaryColor,
      brightness: Brightness.dark,
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackgroundColor,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: darkAiText,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkAiText,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: darkSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkPrimaryColor,
        foregroundColor: darkBackgroundColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurfaceColor,
        indicatorColor: darkPrimaryColor.withAlpha(40),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12),
        ),
      ),
    );
  }

  static BoxDecoration get glassmorphismDecoration {
    return BoxDecoration(
      color: glassWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: glassBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: glassBlack,
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration get glassmorphismCard {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          glassWhite,
          glassWhite.withAlpha(200),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: glassBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: glassBlack,
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration getCodeBlockDecoration(String language) {
    final colors = {
      'bash': const Color(0xFF4A154B),
      'python': const Color(0xFF3776AB),
      'javascript': const Color(0xFFF7DF1E),
      'dart': const Color(0xFF0175C2),
      'rust': const Color(0xFFDEA584),
      'go': const Color(0xFF00ADD8),
    };
    
    return BoxDecoration(
      color: codeBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: colors[language] ?? primaryColor,
        width: 2,
      ),
    );
  }

  // Get theme-aware colors
  static Color getUserBubble(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkUserBubble : userBubble;
  }
  
  static Color getAiBubble(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkAiBubble : aiBubble;
  }
  
  static Color getUserText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkUserText : userText;
  }
  
  static Color getAiText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkAiText : aiText;
  }

  static TextStyle get terminalTextStyle {
    return GoogleFonts.firaCode(
      fontSize: 14,
      color: terminalText,
      height: 1.4,
    );
  }

  static TextStyle get codeTextStyle {
    return GoogleFonts.firaCode(
      fontSize: 13,
      color: codeText,
      height: 1.5,
    );
  }
}

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  
  static const Curve defaultCurve = Curves.easeInOutCubic;
}

// Color constants for dark mode
class DarkColors {
  static const Color card = Color(0xFF2B2930);
  static const Color surface = Color(0xFF1C1B1F);
  static const Color border = Color(0xFF49454F);
  static const Color text = Color(0xFFE6E1E5);
  static const Color textSecondary = Color(0xFFCAC4D0);
}