import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the Material theme from the Pugmark tokens (docs/DESIGN.md §3–4).
ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? PugColors.dark : PugColors.light;
  final text = _textTheme(c);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.accentInk,
    secondary: c.success,
    onSecondary: c.accentInk,
    error: c.danger,
    onError: c.accentInk,
    surface: c.surface,
    onSurface: c.ink,
    surfaceContainerHighest: c.surfaceAlt,
    outline: c.line,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    textTheme: text,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.headlineSmall,
    ),
    cardTheme: CardTheme(
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card), side: BorderSide(color: c.line)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.accentInk,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.line),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.accent, minimumSize: const Size(48, 48), textStyle: text.labelLarge),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.control), borderSide: BorderSide(color: c.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.control), borderSide: BorderSide(color: c.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.control), borderSide: BorderSide(color: c.accent, width: 2)),
      hintStyle: text.bodyMedium?.copyWith(color: c.inkMuted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceAlt,
      selectedColor: c.accent.withValues(alpha: 0.15),
      side: BorderSide(color: c.line),
      shape: const StadiumBorder(),
      labelStyle: text.labelMedium,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accent.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.ink)),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
    ),
  );
}

TextTheme _textTheme(PugColors c) {
  TextStyle display(double size, double height, FontWeight w) => GoogleFonts.fraunces(fontSize: size, height: height / size, fontWeight: w, color: c.ink);
  TextStyle text(double size, double height, FontWeight w, {double spacing = 0}) =>
      GoogleFonts.manrope(fontSize: size, height: height / size, fontWeight: w, color: c.ink, letterSpacing: spacing);
  return TextTheme(
    displayLarge: display(40, 46, FontWeight.w600),
    displayMedium: display(32, 38, FontWeight.w600),
    displaySmall: display(28, 32, FontWeight.w600), // card animal name
    headlineMedium: display(24, 30, FontWeight.w600), // screen title
    headlineSmall: display(20, 26, FontWeight.w600),
    titleLarge: display(22, 26, FontWeight.w500), // stat numerals (tabular via PugText.tabular)
    titleMedium: text(16, 22, FontWeight.w600),
    titleSmall: text(14, 20, FontWeight.w600),
    bodyLarge: text(18, 26, FontWeight.w400),
    bodyMedium: text(16, 24, FontWeight.w400),
    bodySmall: text(14, 20, FontWeight.w400),
    labelLarge: text(16, 20, FontWeight.w600),
    labelMedium: text(13, 18, FontWeight.w500, spacing: 0.26),
    labelSmall: text(11, 14, FontWeight.w500, spacing: 0.4),
  );
}

/// Typographic helpers for banknote-style serials and stats.
class PugText {
  PugText._();
  static const tabular = [FontFeature.tabularFigures()];

  /// `Fraunces` serial with tabular figures and wide tracking (DESIGN.md §4).
  static TextStyle serial(BuildContext context, {Color? color, double size = 18}) => GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: size * 0.08,
        color: color ?? context.pug.ink,
        fontFeatures: tabular,
      );

  static TextStyle stat(BuildContext context, {Color? color}) =>
      GoogleFonts.fraunces(fontSize: 22, height: 26 / 22, fontWeight: FontWeight.w500, color: color ?? context.pug.ink, fontFeatures: tabular);

  static TextStyle flavour(BuildContext context, {Color? color}) =>
      GoogleFonts.manrope(fontSize: 14, height: 20 / 14, fontStyle: FontStyle.italic, color: color ?? context.pug.inkMuted);
}
