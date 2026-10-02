import 'package:flutter/material.dart';

/// Semantic colour tokens from docs/DESIGN.md §3.1. Family palettes come from the
/// database (`animals.palette`); these are the app chrome only.
class PugColors extends ThemeExtension<PugColors> {
  const PugColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.success,
    required this.warn,
    required this.danger,
  });

  final Color bg, surface, surfaceAlt, ink, inkMuted, line, accent, accentInk, success, warn, danger;

  static const light = PugColors(
    bg: Color(0xFFF7F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFE9DE),
    ink: Color(0xFF1B1B18),
    inkMuted: Color(0xFF6B6A63),
    line: Color(0xFFE2DCD0),
    accent: Color(0xFFC8551B),
    accentInk: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D5B),
    warn: Color(0xFFB3791C),
    danger: Color(0xFFA33A2B),
  );

  static const dark = PugColors(
    bg: Color(0xFF121311),
    surface: Color(0xFF1C1E1B),
    surfaceAlt: Color(0xFF262925),
    ink: Color(0xFFF2EFE8),
    inkMuted: Color(0xFFA5A49C),
    line: Color(0xFF33362F),
    accent: Color(0xFFF08A4B),
    accentInk: Color(0xFF1B1B18),
    success: Color(0xFF59B98F),
    warn: Color(0xFFE0A94C),
    danger: Color(0xFFE0695A),
  );

  @override
  PugColors copyWith({Color? bg, Color? surface, Color? surfaceAlt, Color? ink, Color? inkMuted, Color? line, Color? accent, Color? accentInk, Color? success, Color? warn, Color? danger}) {
    return PugColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      success: success ?? this.success,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
    );
  }

  @override
  PugColors lerp(PugColors? other, double t) {
    if (other == null) return this;
    return PugColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      success: Color.lerp(success, other.success, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Spacing scale (4-pt grid).
class Space {
  Space._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48;
}

class Radii {
  Radii._();
  static const double card = 16, sheet = 24, chip = 999, control = 12;
}

/// Family palette as stored in the database (`animals.palette`): bg / fg / accent.
class FamilyPalette {
  const FamilyPalette({required this.bg, required this.fg, required this.accent});
  final Color bg, fg, accent;

  factory FamilyPalette.fromJson(Map<String, dynamic>? json, {String family = 'calm'}) {
    final fallback = fallbackFor(family);
    Color parse(String? hex, Color fb) {
      if (hex == null) return fb;
      final h = hex.replaceFirst('#', '');
      final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
      return v == null ? fb : Color(v);
    }
    return FamilyPalette(
      bg: parse(json?['bg'] as String?, fallback.bg),
      fg: parse(json?['fg'] as String?, fallback.fg),
      accent: parse(json?['accent'] as String?, fallback.accent),
    );
  }

  /// DESIGN.md §3.2 defaults, used when the database has no palette yet.
  static FamilyPalette fallbackFor(String family) => switch (family) {
        'swift' => const FamilyPalette(bg: Color(0xFFF5E2C8), fg: Color(0xFF5A2E0C), accent: Color(0xFFE0902F)),
        'steady' => const FamilyPalette(bg: Color(0xFFD9E7D6), fg: Color(0xFF1F3D2B), accent: Color(0xFF4F8A5B)),
        'calm' => const FamilyPalette(bg: Color(0xFFE6DFF0), fg: Color(0xFF3A2E57), accent: Color(0xFF8B74C9)),
        'gentle' => const FamilyPalette(bg: Color(0xFFF1DCD1), fg: Color(0xFF5B2F22), accent: Color(0xFFC76A4E)),
        'time' => const FamilyPalette(bg: Color(0xFF1F2340), fg: Color(0xFFE7E4FF), accent: Color(0xFF8FA3FF)),
        'explorer' => const FamilyPalette(bg: Color(0xFFF3E3B8), fg: Color(0xFF4E3B10), accent: Color(0xFFD1A233)),
        'regional' => const FamilyPalette(bg: Color(0xFFD3ECEA), fg: Color(0xFF134845), accent: Color(0xFF2E9C96)),
        'weekly' => const FamilyPalette(bg: Color(0xFFF0D4D8), fg: Color(0xFF5A1322), accent: Color(0xFFB82A47)),
        'migratory' => const FamilyPalette(bg: Color(0xFFD7E8F7), fg: Color(0xFF143A5C), accent: Color(0xFF3E86C8)),
        'secret' => const FamilyPalette(bg: Color(0xFFE7DAF5), fg: Color(0xFF3C1F5E), accent: Color(0xFF9D6AE3)),
        'national' => const FamilyPalette(bg: Color(0xFFFBE4C6), fg: Color(0xFF6B3A0E), accent: Color(0xFFF2A33A)),
        _ => const FamilyPalette(bg: Color(0xFFE6DFF0), fg: Color(0xFF3A2E57), accent: Color(0xFF8B74C9)),
      };
}

extension PugTheme on BuildContext {
  PugColors get pug => Theme.of(this).extension<PugColors>() ?? PugColors.light;
}
