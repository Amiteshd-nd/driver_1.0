/// Style template editor (expander on the Illustrations section): edit the shared prompt template,
/// preview it on one animal via the `illustrate` Edge Function, and save it as a new style version.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';
import 'art_preview.dart';

class StyleTemplatePanel extends ConsumerStatefulWidget {
  const StyleTemplatePanel({super.key, this.onSaved});
  final VoidCallback? onSaved;

  @override
  ConsumerState<StyleTemplatePanel> createState() => _StyleTemplatePanelState();
}

class _StyleTemplatePanelState extends ConsumerState<StyleTemplatePanel> {
  final _name = TextEditingController();
  final _template = TextEditingController();
  final _baby = TextEditingController();
  final _young = TextEditingController();
  final _adult = TextEditingController();
  final _negative = TextEditingController();

  int? _loadedVersion;
  String? _slug;
  Stage _stage = Stage.adult;
  bool _previewing = false, _saving = false;
  Map<String, dynamic>? _preview;
  String? _composed;
  AdminAnimal? _previewAnimal;

  @override
  void dispose() {
    for (final c in [_name, _template, _baby, _young, _adult, _negative]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the fields from the active template exactly once (fields are not mounted while loading).
  void _prefill(List<Map<String, dynamic>> templates) {
    if (templates.isEmpty || _loadedVersion != null) return;
    final active = templates.firstWhere((t) => t['is_active'] == true, orElse: () => templates.first);
    _loadedVersion = (active['version'] as num?)?.toInt() ?? 0;
    _name.text = (active['name'] ?? '').toString();
    _template.text = (active['template'] ?? '').toString();
    final cues = (active['stage_cues'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    _baby.text = (cues['baby'] ?? '').toString();
    _young.text = (cues['young'] ?? '').toString();
    _adult.text = (cues['adult'] ?? '').toString();
    _negative.text = (active['negative'] ?? '').toString();
  }

  Map<String, dynamic> _draft() => {
        'name': _name.text.trim(),
        'template': _template.text.trim(),
        'stage_cues': {'baby': _baby.text.trim(), 'young': _young.text.trim(), 'adult': _adult.text.trim()},
        'negative': _negative.text.trim(),
      };

  String _cueFor(Stage s) => (switch (s) { Stage.baby => _baby.text, Stage.young => _young.text, Stage.adult => _adult.text }).trim();

  /// Client-side composition of the prompt, used when the Edge Function is unavailable.
  String _compose(String animalName) => _template.text
      .replaceAll('{animal_name}', animalName)
      .replaceAll('{stage_cues}', _cueFor(_stage))
      .replaceAll('{features}', '(distinctive features from the encyclopedia entry)');

  AdminAnimal? _pick(List<AdminAnimal> animals) {
    if (animals.isEmpty) return null;
    for (final a in animals) {
      if (a.animal.slug == _slug) return a;
    }
    return animals.first;
  }

  Future<void> _previewOne(List<AdminAnimal> animals) async {
    final a = _pick(animals);
    if (a == null) {
      showErr(context, 'Add an animal first — there is nothing to preview on.');
      return;
    }
    setState(() {
      _previewing = true;
      _preview = null;
      _composed = null;
      _previewAnimal = a;
    });
    final res = await ref.read(adminRepoProvider).previewIllustration({
      ..._draft(),
      'slug': a.animal.slug,
      'stage': _stage.name,
      'animal_name': a.animal.name,
    });
    if (!mounted) return;
    setState(() {
      _previewing = false;
      _preview = res;
      if (res['ok'] != true) _composed = _compose(a.animal.name);
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _template.text.trim().isEmpty) {
      showErr(context, 'Give the template a name and a body before saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      final v = await ref.read(adminRepoProvider).saveStyleTemplate(_draft());
      _loadedVersion = v;
      ref.invalidate(adminStyleTemplatesProvider);
      if (mounted) showOk(context, 'Style version bumped to v$v; existing art untouched');
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(adminStyleTemplatesProvider);
    final animals = ref.watch(adminAnimalsProvider).valueOrNull ?? const <AdminAnimal>[];
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.palette_outlined),
        title: const Text('Style template'),
        subtitle: Text(
          _loadedVersion == null
              ? 'The prompt template shared by every illustration'
              : 'Editing from v$_loadedVersion · saving creates v${_loadedVersion! + 1} and leaves existing art untouched',
          style: t.bodySmall?.copyWith(color: c.inkMuted),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        children: [
          templates.when(
            loading: () => const Padding(padding: EdgeInsets.all(Space.lg), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text(friendlyError(e), style: t.bodySmall?.copyWith(color: c.danger)),
            data: (list) {
              _prefill(list);
              return _form(context, animals);
            },
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context, List<AdminAnimal> animals) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final selected = _pick(animals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Field(label: 'Name', child: TextField(controller: _name, decoration: denseInput('Flying Cobra illustration style v2'))),
        const SizedBox(height: Space.md),
        Field(
          label: 'Template',
          hint: 'Placeholders: {animal_name}, {stage_cues}, {features}',
          child: TextField(controller: _template, minLines: 4, maxLines: 10, decoration: denseInput(), style: monoStyle(context, size: 12)),
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            for (final (label, ctl) in [('Baby cues', _baby), ('Young cues', _young), ('Adult cues', _adult)])
              SizedBox(
                width: 260,
                child: Field(label: label, child: TextField(controller: ctl, minLines: 2, maxLines: 4, decoration: denseInput())),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        Field(label: 'Negative', child: TextField(controller: _negative, minLines: 2, maxLines: 4, decoration: denseInput())),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: selected?.animal.slug,
              hint: const Text('Animal'),
              items: [for (final a in animals) DropdownMenuItem<String>(value: a.animal.slug, child: Text(a.animal.name))],
              onChanged: (v) => setState(() => _slug = v),
            ),
            DropdownButton<Stage>(
              value: _stage,
              items: [for (final s in Stage.values) DropdownMenuItem<Stage>(value: s, child: Text(s.label))],
              onChanged: (v) => setState(() => _stage = v ?? Stage.adult),
            ),
            OutlinedButton.icon(
              onPressed: _previewing || _saving ? null : () => _previewOne(animals),
              icon: _previewing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.visibility_outlined),
              label: const Text('Preview on one animal'),
            ),
            FilledButton.icon(
              onPressed: _previewing || _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save as new version'),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          'A preview is never stored. Saving bumps the style version for future generations only; approved art keeps its version '
          'and only approved art is shown on cards.',
          style: t.labelSmall?.copyWith(color: c.inkMuted),
        ),
        _previewArea(context),
      ],
    );
  }

  Widget _previewArea(BuildContext context) {
    final p = _preview;
    if (p == null) return const SizedBox.shrink();
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final a = _previewAnimal?.animal;
    final svg = p['svg']?.toString();
    final png = p['png']?.toString();
    final inline = svg != null && svg.trim().startsWith('<');
    final hasImage = (svg != null && svg.isNotEmpty) || (png != null && png.isNotEmpty);
    final prompt = (p['prompt'] ?? p['composed_prompt'] ?? p['prompt_used'])?.toString() ?? _composed;
    final qa = p['qa_notes']?.toString();

    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.control),
              child: SizedBox(
                width: 180,
                height: 180,
                child: ArtPreview(
                  slug: a?.slug ?? '',
                  name: a?.name ?? '',
                  family: a?.family ?? 'calm',
                  stage: _stage,
                  path: inline ? png : (svg != null && svg.isNotEmpty ? svg : png),
                  inlineSvg: inline ? svg : null,
                  palette: a?.palette,
                ),
              ),
            ),
            const SizedBox(width: Space.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p['ok'] != true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Text(
                      'Edge Function unavailable — showing the composed prompt instead. ${p['error'] ?? ''}'.trim(),
                      style: t.bodySmall?.copyWith(color: c.warn),
                    ),
                  ),
                if (prompt != null && prompt.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Space.md),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.control),
                      border: Border.all(color: c.line),
                    ),
                    child: SelectableText(prompt, style: monoStyle(context, size: 12)),
                  ),
                if (qa != null && qa.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text('QA: $qa', style: t.bodySmall?.copyWith(color: c.inkMuted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
