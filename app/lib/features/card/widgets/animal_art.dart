import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/models/models.dart';
import '../../../core/supabase.dart';
import '../../../core/theme/tokens.dart';

/// The animal illustration for one stage.
///
/// Source order: an approved [illustration] (svg, then png) → [path] from
/// `animals.art` → the deterministic [ProceduralArt] placeholder (DESIGN.md §5).
/// Storage paths live in the public bucket `animal-art` (legacy `card-art/…`
/// paths still resolve). `.svg` renders via flutter_svg, `.png` via
/// cached_network_image; any load error falls back to the placeholder.
///
/// NOTE: rarity border, foil and glow are NOT painted here. They stay in
/// `CollectibleCardView` as overlays around/over this widget, so the art file
/// itself never carries rarity.
class AnimalArt extends StatelessWidget {
  const AnimalArt({
    super.key,
    required this.slug,
    required this.name,
    required this.family,
    required this.stage,
    this.path,
    this.illustration,
    required this.palette,
  });

  final String slug, name, family;
  final Stage stage;

  /// Storage path (svg or png) inside bucket `animal-art`, a legacy
  /// `card-art/<slug>/<stage>.png` path, or a full http(s) URL.
  final String? path;

  /// Pipeline pointer from `card_json.illustration`; used only when approved.
  final Illustration? illustration;

  final FamilyPalette palette;

  static const bucket = 'animal-art';
  static const legacyBucket = 'card-art';

  /// Public URL for a storage path. Strips a leading `animal-art/`; a leading
  /// `card-art/` routes to the legacy bucket. Full URLs pass through.
  /// Returns null when the path is unusable.
  static String? resolveUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    var b = bucket;
    var rel = p;
    if (p.startsWith('$bucket/')) {
      rel = p.substring(bucket.length + 1);
    } else if (p.startsWith('$legacyBucket/')) {
      b = legacyBucket;
      rel = p.substring(legacyBucket.length + 1);
    }
    try {
      return supabase.storage.from(b).getPublicUrl(rel);
    } catch (_) {
      return null;
    }
  }

  /// True when the path (or URL, ignoring any query string) ends in `.svg`.
  static bool isSvgPath(String? path) {
    if (path == null) return false;
    final q = path.indexOf('?');
    final clean = (q >= 0 ? path.substring(0, q) : path).toLowerCase();
    return clean.endsWith('.svg');
  }

  /// The path we will actually load: approved illustration first, then [path].
  String? get effectivePath {
    final i = illustration;
    if (i != null && i.isApproved) {
      final best = i.bestPath;
      if (best != null) return best;
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = ProceduralArt(slug: slug, name: name, stage: stage, palette: palette);
    final chosen = effectivePath;
    final url = resolveUrl(chosen);
    if (url == null) return placeholder;

    if (isSvgPath(chosen)) {
      return SvgPicture.network(
        url,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => placeholder,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

/// Family-coloured silhouette with the animal's initial, deterministic per slug.
class ProceduralArt extends StatelessWidget {
  const ProceduralArt({super.key, required this.slug, required this.name, required this.stage, required this.palette});

  final String slug, name;
  final Stage stage;
  final FamilyPalette palette;

  @override
  Widget build(BuildContext context) {
    final hash = fnv1a(slug.isEmpty ? name : slug);
    final initial = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 200.0;
        final side = math.min(w, h);
        final base = Theme.of(context).textTheme.displayLarge ?? const TextStyle(fontSize: 40, fontWeight: FontWeight.w600);
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _BlobPainter(hash: hash, stage: stage, palette: palette)),
              Center(
                child: Text(
                  initial,
                  style: base.copyWith(fontSize: side * 0.42, height: 1, color: palette.fg),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 32-bit FNV-1a hash, stable across platforms.
  static int fnv1a(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({required this.hash, required this.stage, required this.palette});
  final int hash;
  final Stage stage;
  final FamilyPalette palette;

  double _unit(int shift) => ((hash >> shift) & 0xFF) / 255.0;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final frac = switch (stage) { Stage.baby => 0.70, Stage.young => 0.80, Stage.adult => 0.92 };
    final d = side * frac;
    final cx = size.width / 2 + (_unit(0) - 0.5) * side * 0.08;
    final cy = size.height / 2 + (_unit(8) - 0.5) * side * 0.06;
    final center = Offset(cx, cy);
    final squash = 0.88 + _unit(16) * 0.12;

    // Soft halo, then the blob itself.
    canvas.drawOval(
      Rect.fromCenter(center: center, width: d * 1.10, height: d * 1.10 * squash),
      Paint()..color = palette.accent.withValues(alpha: 0.30),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: d, height: d * squash),
      Paint()..color = palette.accent,
    );

    // 2–4 small deterministic dots.
    final n = 2 + (hash % 3);
    final dot = Paint()..color = palette.fg.withValues(alpha: 0.28);
    for (var i = 0; i < n; i++) {
      final a = _unit(24 - i * 3) * math.pi * 2 + i * 1.7;
      final r = d * (0.56 + _unit(i * 5) * 0.14);
      final p = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r * squash);
      final clamped = Offset(p.dx.clamp(side * 0.04, size.width - side * 0.04), p.dy.clamp(side * 0.04, size.height - side * 0.04));
      canvas.drawCircle(clamped, side * (0.018 + _unit(i * 7 + 2) * 0.016), dot);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.hash != hash || old.stage != stage || old.palette != palette;
}
