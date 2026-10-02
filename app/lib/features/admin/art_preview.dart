/// Admin-side illustration thumbnail: svg via flutter_svg, png via cached_network_image,
/// inline `<svg>` markup via SvgPicture.string, else the family placeholder silhouette.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../card/widgets/animal_art.dart';

class ArtPreview extends StatelessWidget {
  const ArtPreview({
    super.key,
    required this.slug,
    required this.name,
    required this.family,
    required this.stage,
    this.path,
    this.inlineSvg,
    this.palette,
  });

  final String slug, name, family;
  final Stage stage;

  /// Storage path (bucket `animal-art`) or full URL; `.svg` / `.png` decides the decoder.
  final String? path;

  /// Raw `<svg …>` markup (Edge Function previews can return it inline).
  final String? inlineSvg;

  /// Family palette; falls back to DESIGN.md §3.2 defaults for [family].
  final FamilyPalette? palette;

  @override
  Widget build(BuildContext context) {
    final pal = palette ?? FamilyPalette.fallbackFor(family);
    final Widget placeholder = ColoredBox(
      color: pal.bg,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: ProceduralArt(slug: slug, name: name, stage: stage, palette: pal),
      ),
    );

    final markup = inlineSvg?.trim();
    if (markup != null && markup.startsWith('<')) {
      return ColoredBox(
        color: pal.bg,
        child: SvgPicture.string(
          markup,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => placeholder,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

    final url = AnimalArt.resolveUrl(path);
    if (url == null) return placeholder;

    final Widget image = AnimalArt.isSvgPath(path)
        ? SvgPicture.network(
            url,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => placeholder,
            errorBuilder: (_, __, ___) => placeholder,
          )
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          );
    return ColoredBox(color: pal.bg, child: image);
  }
}
