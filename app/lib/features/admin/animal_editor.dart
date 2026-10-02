/// Animal edit dialog: JSON-free form fields, facts list editor, palette swatches, per-stage art upload.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import 'admin_repo.dart';
import 'admin_widgets.dart';
import 'pick_bytes.dart';

/// Opens the editor; resolves true when a row was written.
Future<bool?> showAnimalEditor(BuildContext context, AdminAnimal? existing) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(Space.lg),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820), child: AnimalEditor(existing: existing)),
    ),
  );
}

class AnimalEditor extends ConsumerStatefulWidget {
  const AnimalEditor({super.key, this.existing});
  final AdminAnimal? existing;
  @override
  ConsumerState<AnimalEditor> createState() => _AnimalEditorState();
}

class _AnimalEditorState extends ConsumerState<AnimalEditor> {
  final _form = GlobalKey<FormState>();
  late final Animal? _a = widget.existing?.animal;

  late final _slug = TextEditingController(text: _a?.slug ?? '');
  late final _code = TextEditingController(text: _a?.code ?? '');
  late final _name = TextEditingController(text: _a?.name ?? '');
  late final _flavour = TextEditingController(text: _a?.flavourLine ?? '');
  late final _habitat = TextEditingController(text: _a?.habitat ?? '');
  late final _size = TextEditingController(text: _a?.size ?? '');
  late final _superpower = TextEditingController(text: _a?.superpower ?? '');
  late final _indiaNote = TextEditingController(text: _a?.indiaNote ?? '');
  late final _sort = TextEditingController(text: '${_a?.sortOrder ?? 100}');
  late final _bg = TextEditingController(text: _hex(_a?.palette.bg));
  late final _fg = TextEditingController(text: _hex(_a?.palette.fg));
  late final _accent = TextEditingController(text: _hex(_a?.palette.accent));
  late final List<TextEditingController> _facts = [for (final f in _a?.facts ?? const <String>[]) TextEditingController(text: f)];

  late String _family = kFamilies.contains(_a?.family) ? _a!.family : kFamilies.first;
  late Rarity _rarity = _a?.rarity ?? Rarity.common;
  late bool _isSecret = _a?.isSecret ?? false;
  late bool _isActive = widget.existing?.isActive ?? true;
  late Map<String, dynamic> _art = Map<String, dynamic>.from(_a?.art ?? const {});
  bool _saving = false;
  Stage? _uploading;

  static String _hex(Color? c) {
    if (c == null) return '';
    // ignore: deprecated_member_use
    final v = (c.red << 16) | (c.green << 8) | c.blue;
    return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  void dispose() {
    for (final c in [_slug, _code, _name, _flavour, _habitat, _size, _superpower, _indiaNote, _sort, _bg, _fg, _accent, ..._facts]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _row() {
    String? nz(String s) => s.trim().isEmpty ? null : s.trim();
    final enc = <String, dynamic>{
      ...(_a?.encyclopedia ?? const {}),
      'facts': _facts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      if (nz(_habitat.text) != null) 'habitat': nz(_habitat.text),
      if (nz(_size.text) != null) 'size': nz(_size.text),
      if (nz(_superpower.text) != null) 'superpower': nz(_superpower.text),
      if (nz(_indiaNote.text) != null) 'india_note': nz(_indiaNote.text),
    };
    final pal = <String, dynamic>{
      if (HexField.parse(_bg.text) != null) 'bg': _bg.text.trim(),
      if (HexField.parse(_fg.text) != null) 'fg': _fg.text.trim(),
      if (HexField.parse(_accent.text) != null) 'accent': _accent.text.trim(),
    };
    return {
      'slug': _slug.text.trim(),
      'code': _code.text.trim().toUpperCase(),
      'name': _name.text.trim(),
      'family': _family,
      'rarity': _rarity.name,
      'flavour_line': _flavour.text.trim(),
      'encyclopedia': enc,
      'art': _art,
      'palette': pal,
      'is_secret': _isSecret,
      'is_active': _isActive,
      'sort_order': int.tryParse(_sort.text.trim()) ?? 100,
    };
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final repo = ref.read(adminRepoProvider);
    final a = _a;
    try {
      if (a == null) {
        await repo.insertAnimal(_row());
      } else {
        await repo.updateAnimal(a.id, _row());
      }
      if (mounted) {
        showOk(context, '${_name.text.trim()} saved');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _upload(Stage stage) async {
    final slug = _slug.text.trim();
    if (slug.isEmpty) {
      showErr(context, 'Set a slug before uploading art.');
      return;
    }
    if (!pickBytesSupported) {
      showErr(context, 'Upload art from the web admin.');
      return;
    }
    final picked = await pickBytes(accept: 'image/png');
    if (picked == null || !mounted) return;
    setState(() => _uploading = stage);
    final a = _a;
    try {
      final path = await ref.read(adminRepoProvider).uploadArt(slug, stage, picked.bytes);
      final next = <String, dynamic>{..._art, stage.name: path};
      if (a != null) await ref.read(adminRepoProvider).updateAnimal(a.id, {'art': next});
      if (mounted) {
        setState(() => _art = next);
        showOk(context, '${stage.label} art uploaded');
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final repo = ref.read(adminRepoProvider);
    final a = _a;
    final preview = Animal(
      id: a?.id ?? '',
      slug: _slug.text,
      code: _code.text,
      name: _name.text,
      family: _family,
      rarity: _rarity,
      flavourLine: _flavour.text,
      encyclopedia: const {},
      art: _art,
      palette: FamilyPalette.fromJson({'bg': _bg.text, 'fg': _fg.text, 'accent': _accent.text}, family: _family),
      isSecret: _isSecret,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.md, 0),
          child: Row(
            children: [
              ArtThumb(animal: preview, size: 40),
              const SizedBox(width: Space.md),
              Expanded(child: Text(a == null ? 'New animal' : 'Edit ${a.name}', style: t.headlineSmall)),
              IconButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(Space.xl),
              children: [
                _grid([
                  Field(label: 'Slug', hint: 'lowercase-with-dashes; also the art folder', child: TextFormField(controller: _slug, decoration: denseInput('indian-fox'), validator: _req, style: monoStyle(context), onChanged: (_) => setState(() {}))),
                  Field(label: 'Code', hint: 'serial prefix, e.g. IFX', child: TextFormField(controller: _code, decoration: denseInput('IFX'), validator: _req, style: monoStyle(context), textCapitalization: TextCapitalization.characters, onChanged: (_) => setState(() {}))),
                  Field(label: 'Name', child: TextFormField(controller: _name, decoration: denseInput('Indian Fox'), validator: _req, onChanged: (_) => setState(() {}))),
                  Field(label: 'Sort order', child: TextFormField(controller: _sort, decoration: denseInput('100'), keyboardType: TextInputType.number)),
                  Field(
                    label: 'Family',
                    child: DropdownButtonFormField<String>(
                      value: _family,
                      decoration: denseInput(),
                      items: [for (final f in kFamilies) DropdownMenuItem(value: f, child: Text(f))],
                      onChanged: (v) => setState(() => _family = v ?? _family),
                    ),
                  ),
                  Field(
                    label: 'Rarity',
                    child: DropdownButtonFormField<Rarity>(
                      value: _rarity,
                      decoration: denseInput(),
                      items: [for (final r in Rarity.values) DropdownMenuItem(value: r, child: Text(r.label))],
                      onChanged: (v) => setState(() => _rarity = v ?? _rarity),
                    ),
                  ),
                ]),
                const SizedBox(height: Space.lg),
                Field(label: 'Flavour line', hint: 'lowercase, no full stop — "the tireless traveller"', child: TextFormField(controller: _flavour, decoration: denseInput('the tireless traveller'))),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Expanded(child: SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Secret'), subtitle: const Text('Hidden from the encyclopedia until earned'), value: _isSecret, onChanged: (v) => setState(() => _isSecret = v))),
                    const SizedBox(width: Space.lg),
                    Expanded(child: SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Active'), subtitle: const Text('In pools'), value: _isActive, onChanged: (v) => setState(() => _isActive = v))),
                  ],
                ),
                const Divider(height: Space.xxl),
                Text('Encyclopedia', style: t.titleMedium),
                const SizedBox(height: Space.md),
                Field(
                  label: 'Facts',
                  child: Column(
                    children: [
                      for (var i = 0; i < _facts.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: Row(
                            children: [
                              Expanded(child: TextFormField(controller: _facts[i], decoration: denseInput('A short, surprising fact'), maxLines: 2, minLines: 1)),
                              IconButton(tooltip: 'Remove', icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => setState(() => _facts.removeAt(i).dispose())),
                            ],
                          ),
                        ),
                      Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _facts.add(TextEditingController())), icon: const Icon(Icons.add, size: 18), label: const Text('Add fact'))),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                _grid([
                  Field(label: 'Habitat', child: TextFormField(controller: _habitat, decoration: denseInput('arid plains and thorn scrub'))),
                  Field(label: 'Size', child: TextFormField(controller: _size, decoration: denseInput('about 65 cm at the shoulder'))),
                  Field(label: 'Superpower', child: TextFormField(controller: _superpower, decoration: denseInput('lightness that turns sand into a track'))),
                  Field(label: 'India note', child: TextFormField(controller: _indiaNote, decoration: denseInput('where in India it lives'))),
                ]),
                const Divider(height: Space.xxl),
                Text('Palette', style: t.titleMedium),
                const SizedBox(height: Space.md),
                _grid([
                  HexField(label: 'Background', controller: _bg, onChanged: () => setState(() {})),
                  HexField(label: 'Foreground', controller: _fg, onChanged: () => setState(() {})),
                  HexField(label: 'Accent', controller: _accent, onChanged: () => setState(() {})),
                ], minWidth: 200),
                const Divider(height: Space.xxl),
                Text('Art', style: t.titleMedium),
                Text('PNG 1200 × 1200, transparent. Stored at card-art/<slug>/<stage>.png.', style: t.labelSmall?.copyWith(color: c.inkMuted)),
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: Space.lg,
                  runSpacing: Space.md,
                  children: [
                    for (final s in Stage.values)
                      _ArtTile(
                        stage: s,
                        path: _art[s.name] as String?,
                        url: _art[s.name] is String ? repo.artUrl(_art[s.name] as String) : null,
                        busy: _uploading == s,
                        onUpload: _uploading == null ? () => _upload(s) : null,
                        onClear: _art[s.name] == null ? null : () => setState(() => _art = <String, dynamic>{..._art}..remove(s.name)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              const SizedBox(width: Space.sm),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: Text(a == null ? 'Create' : 'Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(List<Widget> children, {double minWidth = 300}) => LayoutBuilder(
        builder: (context, box) {
          final cols = (box.maxWidth / minWidth).floor().clamp(1, 3).toInt();
          final w = (box.maxWidth - Space.lg * (cols - 1)) / cols;
          return Wrap(spacing: Space.lg, runSpacing: Space.md, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
        },
      );
}

class _ArtTile extends StatelessWidget {
  const _ArtTile({required this.stage, required this.path, required this.url, required this.busy, required this.onUpload, required this.onClear});
  final Stage stage;
  final String? path, url;
  final bool busy;
  final VoidCallback? onUpload, onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 180,
            height: 120,
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.control), border: Border.all(color: c.line)),
            clipBehavior: Clip.antiAlias,
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : url == null
                    ? Center(child: Icon(Icons.image_outlined, color: c.inkMuted))
                    : Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image_outlined, color: c.inkMuted))),
          ),
          const SizedBox(height: Space.xs),
          Text(stage.label, style: t.labelMedium),
          Text(path ?? 'placeholder', style: t.labelSmall?.copyWith(color: c.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(
            children: [
              TextButton.icon(onPressed: onUpload, icon: const Icon(Icons.upload_outlined, size: 16), label: const Text('Upload')),
              if (onClear != null) IconButton(tooltip: 'Clear path', onPressed: onClear, icon: const Icon(Icons.clear, size: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
