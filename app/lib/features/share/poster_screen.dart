import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../card/widgets/collectible_card_view.dart';

/// 1080 × 1920 story poster (DESIGN.md §7): family gradient, card at 70 % width,
/// serial large beneath, QR to the verify URL bottom-right, wordmark. Zero location.
class PosterScreen extends ConsumerStatefulWidget {
  const PosterScreen({super.key, required this.cardId, this.initial});
  final String cardId;
  final CollectibleCard? initial;

  @override
  ConsumerState<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends ConsumerState<PosterScreen> {
  final GlobalKey _posterKey = GlobalKey();
  CollectibleCard? _card;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _card = widget.initial;
    if (_card == null) _load();
  }

  Future<void> _load() async {
    try {
      final fresh = await ref.read(apiProvider).card(widget.cardId);
      if (mounted && fresh != null) setState(() => _card = fresh);
    } catch (_) {}
  }

  Future<Uint8List?> _render() async {
    // Let the foil/fonts settle for a frame before capturing.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final boundary = _posterKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<void> _share() async {
    final card = _card;
    if (card == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _render();
      if (bytes == null) throw StateError('no image');
      final fileName = 'flyingcobra-${card.slug.isEmpty ? 'card' : card.slug}-${card.serialNo.toString().padLeft(4, '0')}.png';
      final text = '${card.serial} · ${card.verifyUrl}'.trim();
      if (kIsWeb) {
        await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'image/png', name: fileName)], text: text);
      } else {
        // Some share targets ignore in-memory files, so write a temp PNG first.
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/$fileName';
        await XFile.fromData(bytes, mimeType: 'image/png', name: fileName).saveTo(path);
        await Share.shareXFiles([XFile(path, mimeType: 'image/png', name: fileName)], text: text);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't make the poster this time. Try again in a moment.")));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Share poster')),
      body: card == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.card),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: RepaintBoundary(
                            key: _posterKey,
                            child: SizedBox(width: 1080, height: 1920, child: _Poster(card: card)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Your card and its serial. No route, no location.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkMuted)),
                      const SizedBox(height: Space.md),
                      FilledButton.icon(
                        onPressed: _sharing ? null : _share,
                        icon: _sharing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share),
                        label: Text(_sharing ? 'Making your poster…' : 'Share'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.card});
  final CollectibleCard card;

  @override
  Widget build(BuildContext context) {
    final pal = card.palette;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pal.bg, Color.lerp(pal.bg, pal.accent, 0.55) ?? pal.accent],
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const Spacer(flex: 3),
              Center(child: CollectibleCardView(card: card, width: 1080 * 0.70, interactive: false)),
              const SizedBox(height: 72),
              Text(
                card.serial.toUpperCase().replaceFirst(' #', '  #'),
                textAlign: TextAlign.center,
                style: AppText.serial(context, size: 64, color: pal.fg),
              ),
              const SizedBox(height: 16),
              Text(
                '${card.rarity.label} · ${card.stage.label}',
                style: (tt.labelMedium ?? const TextStyle()).copyWith(fontSize: 28, color: pal.fg.withValues(alpha: 0.8), letterSpacing: 1.5),
              ),
              const Spacer(flex: 4),
            ],
          ),
          Positioned(
            left: 72,
            bottom: 88,
            child: Row(
              children: [
                SizedBox(width: 44, height: 44, child: CustomPaint(painter: _WordmarkPawPainter(color: pal.fg))),
                const SizedBox(width: 16),
                Text('flyingcobra.run', style: (tt.headlineMedium ?? const TextStyle()).copyWith(fontSize: 40, color: pal.fg)),
              ],
            ),
          ),
          if (card.verifyUrl.isNotEmpty)
            Positioned(
              right: 72,
              bottom: 72,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(20)),
                child: QrImageView(
                  data: card.verifyUrl,
                  size: 200,
                  backgroundColor: const Color(0xFFFFFFFF),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tiny paw for the wordmark (same geometry as the card back, smaller).
class _WordmarkPawPainter extends CustomPainter {
  const _WordmarkPawPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    final p = Paint()..color = color;
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + u * 0.2), width: u * 0.5, height: u * 0.38), Radius.circular(u * 0.12)), p);
    for (final o in [Offset(-0.3, -0.16), Offset(-0.11, -0.3), Offset(0.11, -0.3), Offset(0.3, -0.16)]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + o.dx * u, cy + o.dy * u), width: u * 0.17, height: u * 0.21), p);
    }
  }

  @override
  bool shouldRepaint(_WordmarkPawPainter old) => old.color != color;
}
