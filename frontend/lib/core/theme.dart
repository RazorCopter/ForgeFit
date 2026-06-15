import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colori base per il design Cyber-Glassmorphism
  static const Color bgTop = Color(0xFF090909);
  static const Color bgBottom = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF0F0F1A);
  static const Color surfaceVariant = Color(0xFF1A1A24);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);

  // Nuova Tavolozza Accenti (Cyber-Vibrant)
  static const Color vividPurple = Color(0xFFBB86FC);
  static const Color cyan = Color(0xFF00E5FF);
  
  // Vecchi nomi mantenuti per compatibilità ma mappati ai nuovi colori
  static const Color pushAccent = cyan;
  static const Color pullAccent = vividPurple;
  static const Color legsAccent = Color(0xFF00B8D4); // Cyan un po' più profondo o mix
  static const Color homeAccent = Color(0xFFE0B0FF); // Viola chiaro

  /// Palette ciclica per giorni con ID dinamici (generati dal backend con AI).
  /// 8 colori vibranti ben distanziati sulla ruota cromatica.
  static const List<Color> _dayPalette = [
    Color(0xFF00E5FF), // Cyan
    Color(0xFFBB86FC), // Purple
    Color(0xFF00B8D4), // Teal
    Color(0xFFFF6D00), // Orange
    Color(0xFF00E676), // Green
    Color(0xFFFF4081), // Pink
    Color(0xFFFFD740), // Amber
    Color(0xFF7C4DFF), // Deep Purple
  ];

  static Color getMuscleGroupColor(String group) {
    switch (group.toLowerCase()) {
      case 'petto': return pushAccent;
      case 'schiena': return pullAccent;
      case 'gambe':
      case 'glutei': return legsAccent;
      case 'spalle': return Color(0xFFFF6D00);
      case 'braccia': return Color(0xFFFF4081);
      case 'addome':
      case 'core': return Color(0xFF00E676);
      default: return vividPurple;
    }
  }

  static Color getAccentForDay(String dayId) {
    // Compatibilità legacy: mappatura esplicita per gli ID fissi d1–d4
    switch (dayId) {
      case 'd1': return pushAccent;
      case 'd2': return pullAccent;
      case 'd3': return legsAccent;
      case 'd4': return homeAccent;
    }
    // ID dinamici: colore deterministico basato su hash dell'ID
    // (stesso ID → stesso colore, sempre)
    int hash = 0;
    for (final ch in dayId.codeUnits) {
      hash = (hash * 31 + ch) & 0x7FFFFFFF;
    }
    return _dayPalette[hash % _dayPalette.length];
  }

  static ThemeData get darkTheme {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: Colors.transparent, // Lo sfondo è gestito dal buildBackground
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        primary: vividPurple,
        secondary: cyan,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface.withOpacity(0.8),
        selectedItemColor: cyan,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.outfit(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vividPurple,
          foregroundColor: bgTop,
          elevation: 8,
          shadowColor: vividPurple.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // Sfondo Globale
  static Widget buildBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bgTop, bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }

  // Nuova GlassCard (Cyber-Glassmorphism)
  static Widget glassContainer({
    required Widget child,
    double blur = 10.0,
    double opacity = 0.05,
    Color? borderColor,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    final defaultRadius = BorderRadius.circular(24);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? defaultRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? defaultRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: borderRadius ?? defaultRadius,
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
