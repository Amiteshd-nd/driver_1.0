// GENERATED from design_system/tokens.json v0.1.0 — do not edit by hand.
// Run: node design_system/build-tokens.mjs   then copy into app/lib/core/theme/generated_tokens.dart
// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';

/// Chrome colours per mode (DESIGN.md §3.1).
class TokenColors {
  TokenColors._();
  static const lightBg = Color(0xFFF7F3EC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFEFE9DE);
  static const lightInk = Color(0xFF1B1B18);
  static const lightInkMuted = Color(0xFF6B6A63);
  static const lightLine = Color(0xFFE2DCD0);
  static const lightAccent = Color(0xFFC8551B);
  static const lightAccentInk = Color(0xFFFFFFFF);
  static const lightSuccess = Color(0xFF2E7D5B);
  static const lightWarn = Color(0xFFB3791C);
  static const lightDanger = Color(0xFFA33A2B);
  static const darkBg = Color(0xFF121311);
  static const darkSurface = Color(0xFF1C1E1B);
  static const darkSurfaceAlt = Color(0xFF262925);
  static const darkInk = Color(0xFFF2EFE8);
  static const darkInkMuted = Color(0xFFA5A49C);
  static const darkLine = Color(0xFF33362F);
  static const darkAccent = Color(0xFFF08A4B);
  static const darkAccentInk = Color(0xFF1B1B18);
  static const darkSuccess = Color(0xFF59B98F);
  static const darkWarn = Color(0xFFE0A94C);
  static const darkDanger = Color(0xFFE0695A);
}

/// Family palettes (DESIGN.md §3.2). Keyed by family slug.
class TokenFamily {
  const TokenFamily(this.bg, this.fg, this.accent, this.label);
  final Color bg, fg, accent; final String label;
  static const Map<String, TokenFamily> all = {
    'swift': TokenFamily(Color(0xFFF5E2C8), Color(0xFF5A2E0C), Color(0xFFE0902F), 'Swift'),
    'steady': TokenFamily(Color(0xFFD9E7D6), Color(0xFF1F3D2B), Color(0xFF4F8A5B), 'Steady'),
    'calm': TokenFamily(Color(0xFFE6DFF0), Color(0xFF3A2E57), Color(0xFF8B74C9), 'Calm'),
    'gentle': TokenFamily(Color(0xFFF1DCD1), Color(0xFF5B2F22), Color(0xFFC76A4E), 'Gentle'),
    'time': TokenFamily(Color(0xFF1F2340), Color(0xFFE7E4FF), Color(0xFF8FA3FF), 'Time of day'),
    'explorer': TokenFamily(Color(0xFFF3E3B8), Color(0xFF4E3B10), Color(0xFFD1A233), 'Explorer'),
    'regional': TokenFamily(Color(0xFFD3ECEA), Color(0xFF134845), Color(0xFF2E9C96), 'Regional'),
    'weekly': TokenFamily(Color(0xFFF0D4D8), Color(0xFF5A1322), Color(0xFFB82A47), 'Weekly'),
    'migratory': TokenFamily(Color(0xFFD7E8F7), Color(0xFF143A5C), Color(0xFF3E86C8), 'Migratory'),
    'secret': TokenFamily(Color(0xFFE7DAF5), Color(0xFF3C1F5E), Color(0xFF9D6AE3), 'Secret'),
    'national': TokenFamily(Color(0xFFFBE4C6), Color(0xFF6B3A0E), Color(0xFFF2A33A), 'National'),
  };
}

/// Rarity expression (DESIGN.md §3.3). New rarity = new entry here, no new widget.
class TokenRarity {
  const TokenRarity(this.borderWidth, this.foil, this.particles, this.revealMs, this.drawWeight);
  final double borderWidth; final bool foil; final int particles, revealMs, drawWeight;
  static const Map<String, TokenRarity> all = {
    'common': TokenRarity(1.0, false, 0, 600, 60),
    'uncommon': TokenRarity(1.5, false, 0, 600, 25),
    'rare': TokenRarity(2.0, false, 0, 700, 10),
    'epic': TokenRarity(2.5, true, 0, 800, 4),
    'legendary': TokenRarity(3.0, true, 24, 900, 1),
  };
}

class TokenTier {
  const TokenTier(this.artScale, this.minKm);
  final double artScale, minKm;
  static const Map<String, TokenTier> all = {
    'baby': TokenTier(0.7, 0),
    'young': TokenTier(0.8, 3),
    'adult': TokenTier(0.92, 7),
  };
}

class TokenFinish {
  const TokenFinish(this.glowBlur, this.glowAlpha, this.breathe, this.minRunDays);
  final double glowBlur, glowAlpha; final bool breathe; final int minRunDays;
  static const Map<String, TokenFinish> all = {
    'plain': TokenFinish(0, 0, false, 0),
    'glow': TokenFinish(12, 0.35, false, 4),
    'radiant': TokenFinish(24, 0.55, true, 7),
  };
}

class TokenSpace {
  TokenSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class TokenRadius {
  TokenRadius._();
  static const double card = 16;
  static const double sheet = 24;
  static const double control = 12;
  static const double chip = 999;
  static const double art = 10;
}

/// Durations in milliseconds; wrap with Duration(milliseconds: x).
class TokenMotion {
  TokenMotion._();
  static const int instant = 100;
  static const int quick = 200;
  static const int standard = 300;
  static const int emphasised = 420;
  static const int reveal = 600;
  static const int celebrate = 900;
  static const int breathe = 4000;
  static const int foil = 5500;
  static const int legendarySpin = 6000;
  static const Curve standard = Cubic(0.4, 0, 0.2, 1);
  static const Curve decelerate = Cubic(0, 0, 0.2, 1);
  static const Curve accelerate = Cubic(0.4, 0, 1, 1);
  static const Curve emphasised = Cubic(0.22, 0.9, 0.3, 1);
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);
}

