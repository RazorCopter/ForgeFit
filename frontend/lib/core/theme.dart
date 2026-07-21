import 'dart:ui';

import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 280);
  static const Curve curve = Curves.easeOutCubic;
}

class AppTheme {
  // ForgeFit Obsidian: superfici profonde e accenti riservati alle azioni.
  static const Color bgTop = Color(0xFF06080C);
  static const Color bgBottom = Color(0xFF0B1016);
  static const Color surface = Color(0xFF11171F);
  static const Color surfaceVariant = Color(0xFF18202A);
  static const Color surfaceElevated = Color(0xFF202A36);
  static const Color textPrimary = Color(0xFFF7F9FC);
  static const Color textSecondary = Color(0xFF98A3B3);

  static const Color vividPurple = Color(0xFFA892FF);
  static const Color cyan = Color(0xFF63E6FF);
  static const Color success = Color(0xFF55D99D);
  static const Color warning = Color(0xFFFFC66D);
  static const Color danger = Color(0xFFFF7A86);

  // Nomi legacy mantenuti per non interrompere le schermate esistenti.
  static const Color pushAccent = cyan;
  static const Color pullAccent = vividPurple;
  static const Color legsAccent = Color(0xFF49C6D6);
  static const Color homeAccent = Color(0xFFC9BAFF);

  static const List<Color> _dayPalette = [
    cyan,
    vividPurple,
    Color(0xFF49C6D6),
    Color(0xFFFFA65C),
    success,
    Color(0xFFFF7FAB),
    Color(0xFFFFD166),
    Color(0xFF7F75FF),
  ];

  static Color getMuscleGroupColor(String group) {
    switch (group.toLowerCase()) {
      case 'petto':
        return pushAccent;
      case 'schiena':
        return pullAccent;
      case 'gambe':
      case 'glutei':
        return legsAccent;
      case 'spalle':
        return const Color(0xFFFFA65C);
      case 'braccia':
        return const Color(0xFFFF7FAB);
      case 'addome':
      case 'core':
        return success;
      default:
        return vividPurple;
    }
  }

  static Color getAccentForDay(String dayId) {
    switch (dayId) {
      case 'd1':
        return pushAccent;
      case 'd2':
        return pullAccent;
      case 'd3':
        return legsAccent;
      case 'd4':
        return homeAccent;
    }
    int hash = 0;
    for (final ch in dayId.codeUnits) {
      hash = (hash * 31 + ch) & 0x7FFFFFFF;
    }
    return _dayPalette[hash % _dayPalette.length];
  }

  static ThemeData get darkTheme {
    const scheme = ColorScheme.dark(
      primary: cyan,
      onPrimary: Color(0xFF002F38),
      primaryContainer: Color(0xFF153943),
      onPrimaryContainer: Color(0xFFB5F4FF),
      secondary: vividPurple,
      onSecondary: Color(0xFF24184E),
      secondaryContainer: Color(0xFF32285A),
      onSecondaryContainer: Color(0xFFE5DEFF),
      error: danger,
      onError: Color(0xFF460008),
      surface: surface,
      onSurface: textPrimary,
      outline: Color(0xFF3A4654),
      outlineVariant: Color(0xFF28333F),
    );

    final baseText = ThemeData.dark()
        .textTheme
        .apply(bodyColor: textPrimary, displayColor: textPrimary);

    final controlRadius = BorderRadius.circular(AppRadius.md);
    final shape = RoundedRectangleBorder(borderRadius: controlRadius);

    return ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium:
            baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: cyan.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color:
                  states.contains(WidgetState.selected) ? cyan : textSecondary,
              size: 24,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? textPrimary
                  : textSecondary,
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: Color(0xFF26313D)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyan,
          foregroundColor: const Color(0xFF002F38),
          elevation: 0,
          minimumSize: const Size(48, 54),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cyan,
          foregroundColor: const Color(0xFF002F38),
          minimumSize: const Size(48, 54),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: Color(0xFF3A4654)),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyan,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: Color(0xFF2A3541)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: cyan, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: cyan.withValues(alpha: 0.16),
        side: const BorderSide(color: Color(0xFF2A3541)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        labelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFF28333F), thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: cyan,
        linearTrackColor: Color(0xFF22303B),
        circularTrackColor: Color(0xFF22303B),
      ),
    );
  }

  static Widget buildBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bgTop, Color(0xFF091019), bgBottom],
          stops: [0, 0.48, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }

  static Widget glassContainer({
    required Widget child,
    double blur = 8,
    double opacity = 0.05,
    Color? borderColor,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final overlayAlpha = (opacity * 0.45).clamp(0.0, 0.12);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Colors.white.withValues(alpha: overlayAlpha),
                surface.withValues(alpha: 0.94),
              ),
              borderRadius: radius,
              border: Border.all(
                color: borderColor ?? const Color(0xFF26313D),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
