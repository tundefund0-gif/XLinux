import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/terminal_screen.dart';

class AppColors {
  AppColors._();
  static const Color accent = Color(0xFF22C55E);
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color statusGreen = Color(0xFF22C55E);
  static const Color statusRed = Color(0xFFEF4444);
  static const Color mutedText = Color(0xFF6B7280);
}

class XLinuxApp extends StatelessWidget {
  const XLinuxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XLinux',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      home: const TerminalScreen(),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        surface: AppColors.darkSurface,
        onSurface: Colors.white,
        error: AppColors.statusRed,
      ),
      textTheme: textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
