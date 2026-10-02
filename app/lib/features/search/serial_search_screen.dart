import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../card/widgets/pug_card_view.dart';

/// The only search in the product: look up a card by its serial. Never people.
class SerialSearchScreen extends ConsumerStatefulWidget {
  const SerialSearchScreen({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  ConsumerState<SerialSearchScreen> createState() => _SerialSearchScreenState();
}

class _SerialSearchScreenState extends ConsumerState<SerialSearchScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery ?? '');
  SerialLookup? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(apiProvider).lookupSerial(q);
      if (mounted) setState(() => _result = r);
    } catch (_) {
      if (mounted) {
        setState(() {
          _result = null;
          _error = "Couldn't reach the ledger right now. Try again in a moment.";
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify a card')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xxxl),
        children: [
          Text('Type the serial printed on the card.', style: tt.bodyMedium?.copyWith(color: c.inkMuted)),
          const SizedBox(height: Space.md),
          TextField(
            controller: _controller,
            autofocus: (widget.initialQuery ?? '').isEmpty,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _search(),
            style: PugText.serial(context, size: 20),
            decoration: InputDecoration(
              hintText: 'Tiger #0427',
              hintStyle: PugText.serial(context, size: 20, color: c.inkMuted),
              suffixIcon: IconButton(
                tooltip: 'Look up',
                onPressed: _loading ? null : _search,
                icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          if (_error != null) Text(_error!, style: tt.bodyMedium?.copyWith(color: c.danger)),
          if (_result != null) _ResultView(result: _result!),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final SerialLookup result;

  @override
  Widget build(BuildContext context) {
    final c = context.pug;
    final tt = Theme.of(context).textTheme;
    final card = result.card;

    if (!result.found || card == null) {
      return Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("No such card. If someone showed you this, they're bluffing.", style: tt.titleMedium),
            if (result.hint != null && result.hint!.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Text(result.hint!, style: tt.bodySmall?.copyWith(color: c.inkMuted)),
            ] else if (result.reason == 'format') ...[
              const SizedBox(height: Space.sm),
              Text('Try the animal name and the number, like "Tiger #0427".', style: tt.bodySmall?.copyWith(color: c.inkMuted)),
            ],
          ],
        ),
      );
    }

    final width = math.min(MediaQuery.sizeOf(context).width - 48, 320.0);
    final who = result.earnedBy;
    final earned = who == null || who.isEmpty ? 'Earned on ${fmtDate(card.issuedAt)}' : 'Earned by $who on ${fmtDate(card.issuedAt)}';
    final issued = result.issuedSoFar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: PugCardView(card: card, width: width)),
        const SizedBox(height: Space.xl),
        Text(earned, textAlign: TextAlign.center, style: tt.bodyLarge),
        const SizedBox(height: Space.xs),
        Text(
          issued == null ? card.serialShort : '${card.serialShort} of $issued issued',
          textAlign: TextAlign.center,
          style: PugText.serial(context, size: 16, color: c.inkMuted),
        ),
        const SizedBox(height: Space.lg),
        Semantics(
          label: 'Real. Lives in the Pugmark ledger.',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: c.success.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: c.success),
                const SizedBox(width: Space.sm),
                Flexible(child: Text('Real ✓ · lives in the Pugmark ledger', style: tt.titleMedium?.copyWith(color: c.success))),
              ],
            ),
          ),
        ),
        if (card.verdict == Verdict.unverified) ...[
          const SizedBox(height: Space.sm),
          Text("We couldn't fully verify this run, so it drew from the everyday bag.", textAlign: TextAlign.center, style: tt.bodySmall?.copyWith(color: c.inkMuted)),
        ],
      ],
    );
  }
}
