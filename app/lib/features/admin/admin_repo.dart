/// Admin data access: typed CRUD over the rule tables (docs/API.md "Admin only").
/// Every write here is audited into `rule_history` by database triggers.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/models.dart';
import '../../core/supabase.dart';

double? _num(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int? _int(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));
DateTime? _ts(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
List<Map<String, dynamic>> _rows(dynamic r) => ((r as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

/// `animals` row including the admin-only `is_active` flag.
class AdminAnimal {
  const AdminAnimal({required this.animal, required this.isActive, required this.raw});
  final Animal animal;
  final bool isActive;
  final Map<String, dynamic> raw;
  factory AdminAnimal.fromJson(Map<String, dynamic> j) =>
      AdminAnimal(animal: Animal.fromJson(j), isActive: (j['is_active'] ?? true) as bool, raw: j);
}

/// `animal_rules` row.
class AnimalRule {
  const AnimalRule({
    required this.id,
    required this.animalId,
    required this.scope,
    required this.tier,
    required this.predicates,
    required this.weight,
    required this.firstTimeGuaranteed,
    required this.repeatProbability,
    required this.isActive,
    this.note,
    this.updatedAt,
  });
  final String id, animalId;
  final CardScope scope;
  final int tier;
  final Map<String, dynamic> predicates;
  final double weight, repeatProbability;
  final bool firstTimeGuaranteed, isActive;
  final String? note;
  final DateTime? updatedAt;

  factory AnimalRule.fromJson(Map<String, dynamic> j) => AnimalRule(
        id: j['id'] as String,
        animalId: j['animal_id'] as String,
        scope: CardScope.values.firstWhere((s) => s.name == j['scope'], orElse: () => CardScope.run),
        tier: _int(j['tier']) ?? 0,
        predicates: _map(j['predicates']),
        weight: _num(j['weight']) ?? 1,
        firstTimeGuaranteed: (j['first_time_guaranteed'] ?? true) as bool,
        repeatProbability: _num(j['repeat_probability']) ?? 1,
        isActive: (j['is_active'] ?? true) as bool,
        note: j['note'] as String?,
        updatedAt: _ts(j['updated_at']),
      );
}

class ConfigEntry {
  const ConfigEntry({required this.key, required this.value, this.description, this.updatedAt, this.updatedBy});
  final String key;
  final dynamic value;
  final String? description, updatedBy;
  final DateTime? updatedAt;
  factory ConfigEntry.fromJson(Map<String, dynamic> j) => ConfigEntry(
        key: j['key'] as String,
        value: j['value'],
        description: j['description'] as String?,
        updatedAt: _ts(j['updated_at']),
        updatedBy: j['updated_by'] as String?,
      );
}

class Season {
  const Season({required this.id, required this.name, required this.slug, required this.startsOn, required this.endsOn, required this.palette, required this.isActive});
  final String id, name, slug;
  final DateTime startsOn, endsOn;
  final Map<String, dynamic> palette;
  final bool isActive;
  factory Season.fromJson(Map<String, dynamic> j) => Season(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        startsOn: DateTime.tryParse((j['starts_on'] ?? '') as String) ?? DateTime.now(),
        endsOn: DateTime.tryParse((j['ends_on'] ?? '') as String) ?? DateTime.now(),
        palette: _map(j['palette']),
        isActive: (j['is_active'] ?? true) as bool,
      );
}

class RegionRow {
  const RegionRow({required this.code, required this.name, required this.kind, this.minLat, this.maxLat, this.minLon, this.maxLon, this.centroidLat, this.centroidLon});
  final String code, name, kind;
  final double? minLat, maxLat, minLon, maxLon, centroidLat, centroidLon;
  factory RegionRow.fromJson(Map<String, dynamic> j) => RegionRow(
        code: j['code'] as String,
        name: (j['name'] ?? '') as String,
        kind: (j['kind'] ?? 'state') as String,
        minLat: _num(j['min_lat']),
        maxLat: _num(j['max_lat']),
        minLon: _num(j['min_lon']),
        maxLon: _num(j['max_lon']),
        centroidLat: _num(j['centroid_lat']),
        centroidLon: _num(j['centroid_lon']),
      );
}

class AgeFactor {
  const AgeFactor({required this.sex, required this.age, required this.factor});
  final String sex;
  final int age;
  final double factor;
  factory AgeFactor.fromJson(Map<String, dynamic> j) =>
      AgeFactor(sex: j['sex'] as String, age: _int(j['age']) ?? 0, factor: _num(j['factor']) ?? 1);
}

class RuleHistoryRow {
  const RuleHistoryRow({required this.id, required this.tableName, required this.rowId, required this.action, this.oldRow, this.newRow, this.changedBy, required this.changedAt});
  final int id;
  final String tableName, rowId, action;
  final Map<String, dynamic>? oldRow, newRow;
  final String? changedBy;
  final DateTime changedAt;
  factory RuleHistoryRow.fromJson(Map<String, dynamic> j) => RuleHistoryRow(
        id: _int(j['id']) ?? 0,
        tableName: (j['table_name'] ?? '') as String,
        rowId: (j['row_id'] ?? '') as String,
        action: (j['action'] ?? '') as String,
        oldRow: j['old_row'] == null ? null : _map(j['old_row']),
        newRow: j['new_row'] == null ? null : _map(j['new_row']),
        changedBy: j['changed_by'] as String?,
        changedAt: _ts(j['changed_at']) ?? DateTime.now(),
      );
}

/// One row of `admin_illustration_library()`: an (animal × stage × variant × style version) ledger entry.
class IllustrationRow {
  const IllustrationRow({
    required this.id,
    required this.animalId,
    required this.slug,
    required this.name,
    required this.family,
    required this.stage,
    required this.variant,
    required this.styleVersion,
    required this.status,
    required this.attempts,
    required this.costCents,
    this.png,
    this.svg,
    this.provider,
    this.model,
    this.lastError,
    this.qaNotes,
    this.updatedAt,
  });

  final String id, animalId, slug, name, family, stage, variant, status;
  final int styleVersion, attempts;
  final double costCents;
  final String? png, svg, provider, model, lastError, qaNotes;
  final DateTime? updatedAt;

  static const statuses = ['queued', 'generating', 'pending_review', 'approved', 'rejected', 'failed'];

  Stage get stageEnum => Stage.values.firstWhere((s) => s.name == stage, orElse: () => Stage.adult);
  bool get hasArt => (svg != null && svg!.isNotEmpty) || (png != null && png!.isNotEmpty);

  /// svg first (crisp), then png.
  String? get bestPath => (svg != null && svg!.isNotEmpty) ? svg : ((png != null && png!.isNotEmpty) ? png : null);

  factory IllustrationRow.fromJson(Map<String, dynamic> j) => IllustrationRow(
        id: j['id'] as String,
        animalId: (j['animal_id'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        family: (j['family'] ?? 'calm') as String,
        stage: (j['stage'] ?? 'adult') as String,
        variant: (j['variant'] ?? 'base') as String,
        styleVersion: _int(j['style_version']) ?? 1,
        status: (j['status'] ?? 'queued') as String,
        attempts: _int(j['attempts']) ?? 0,
        costCents: _num(j['cost_cents']) ?? 0,
        png: j['png'] as String?,
        svg: j['svg'] as String?,
        provider: j['provider'] as String?,
        model: j['model'] as String?,
        lastError: j['last_error'] as String?,
        qaNotes: j['qa_notes'] as String?,
        updatedAt: _ts(j['updated_at']),
      );
}

/// `profiles` row as seen by support (adds created_at; never shows age/sex).
class AdminUser {
  const AdminUser({required this.profile, required this.createdAt});
  final Profile profile;
  final DateTime createdAt;
  factory AdminUser.fromJson(Map<String, dynamic> j) =>
      AdminUser(profile: Profile.fromJson(j), createdAt: _ts(j['created_at']) ?? DateTime.now());
}

class AdminRepo {
  AdminRepo(this._db);
  final SupabaseClient _db;

  static const artBucket = 'card-art';

  // ---------- animals ----------
  Future<List<AdminAnimal>> animals() async {
    final r = await _db.from('animals').select().order('sort_order').order('name');
    return _rows(r).map(AdminAnimal.fromJson).toList();
  }

  Future<AdminAnimal> insertAnimal(Map<String, dynamic> row) async {
    final r = await _db.from('animals').insert(row).select().single();
    return AdminAnimal.fromJson(r);
  }

  Future<void> updateAnimal(String id, Map<String, dynamic> patch) => _db.from('animals').update(patch).eq('id', id);

  Future<void> setAnimalActive(String id, bool active) => updateAnimal(id, {'is_active': active});

  Future<Map<String, int>> issuedCounts() async {
    final r = await _db.from('animal_counters').select('animal_id,next_serial');
    return {for (final e in _rows(r)) e['animal_id'] as String: _int(e['next_serial']) ?? 0};
  }

  // ---------- rules ----------
  Future<List<AnimalRule>> rulesFor(String animalId) async {
    final r = await _db.from('animal_rules').select().eq('animal_id', animalId).order('scope').order('tier');
    return _rows(r).map(AnimalRule.fromJson).toList();
  }

  Future<AnimalRule> insertRule(Map<String, dynamic> row) async {
    final r = await _db.from('animal_rules').insert(row).select().single();
    return AnimalRule.fromJson(r);
  }

  Future<void> updateRule(String id, Map<String, dynamic> patch) => _db.from('animal_rules').update(patch).eq('id', id);
  Future<void> deleteRule(String id) => _db.from('animal_rules').delete().eq('id', id);

  // ---------- config ----------
  Future<List<ConfigEntry>> config() async {
    final r = await _db.from('config').select().order('key');
    return _rows(r).map(ConfigEntry.fromJson).toList();
  }

  Future<void> updateConfig(String key, dynamic value) =>
      _db.from('config').update({'value': value, 'updated_by': _db.auth.currentUser?.id}).eq('key', key);

  // ---------- seasons ----------
  Future<List<Season>> seasons() async {
    final r = await _db.from('seasons').select().order('starts_on');
    return _rows(r).map(Season.fromJson).toList();
  }

  Future<void> insertSeason(Map<String, dynamic> row) => _db.from('seasons').insert(row);
  Future<void> updateSeason(String id, Map<String, dynamic> patch) => _db.from('seasons').update(patch).eq('id', id);
  Future<void> deleteSeason(String id) => _db.from('seasons').delete().eq('id', id);

  // ---------- regions ----------
  Future<List<RegionRow>> regions() async {
    final r = await _db.from('regions').select().order('name');
    return _rows(r).map(RegionRow.fromJson).toList();
  }

  Future<void> upsertRegion(Map<String, dynamic> row) => _db.from('regions').upsert(row, onConflict: 'code');
  Future<void> deleteRegion(String code) => _db.from('regions').delete().eq('code', code);

  // ---------- age factors ----------
  Future<List<AgeFactor>> ageFactors() async {
    final r = await _db.from('age_factors').select().order('sex').order('age');
    return _rows(r).map(AgeFactor.fromJson).toList();
  }

  Future<void> upsertAgeFactor(String sex, int age, double factor) =>
      _db.from('age_factors').upsert({'sex': sex, 'age': age, 'factor': factor}, onConflict: 'sex,age');

  Future<void> deleteAgeFactor(String sex, int age) => _db.from('age_factors').delete().eq('sex', sex).eq('age', age);

  // ---------- history ----------
  Future<List<RuleHistoryRow>> history({int limit = 200}) async {
    final r = await _db.from('rule_history').select().order('changed_at', ascending: false).limit(limit);
    return _rows(r).map(RuleHistoryRow.fromJson).toList();
  }

  // ---------- users (support) ----------
  Future<List<AdminUser>> users({int limit = 500}) async {
    final r = await _db.from('profiles').select().order('created_at', ascending: false).limit(limit);
    return _rows(r).map(AdminUser.fromJson).toList();
  }

  /// Note: `profiles_self_update` RLS only lets a user update their own row, so this
  /// may be refused for other users until an admin policy/RPC exists (see report).
  /// Uses the security-definer RPC (RLS forbids editing is_admin directly; an admin cannot demote themselves).
  Future<void> setUserAdmin(String id, bool isAdmin) => _db.rpc('admin_set_user_admin', params: {'p_user': id, 'p_is_admin': isAdmin});

  // ---------- storage ----------
  /// Uploads card art to `card-art/<slug>/<stage>.png` and returns the path stored in `animals.art`.
  Future<String> uploadArt(String slug, Stage stage, Uint8List bytes) async {
    final objectPath = '$slug/${stage.name}.png';
    await _db.storage.from(artBucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
        );
    return '$artBucket/$objectPath';
  }

  /// Public URL for an `animals.art` path. Legacy uploads are `card-art/<slug>/<stage>.png`;
  /// pipeline paths (`<slug>/<stage>/<variant>/vN.png|svg`) live in `animal-art`.
  String artUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('$artBucket/')) return _db.storage.from(artBucket).getPublicUrl(path.substring(artBucket.length + 1));
    final p = path.startsWith('$illustrationBucket/') ? path.substring(illustrationBucket.length + 1) : path;
    return _db.storage.from(illustrationBucket).getPublicUrl(p);
  }

  // ---------- illustration pipeline (migration 0010) ----------
  static const illustrationBucket = 'animal-art';
  static const illustrateFunction = 'illustrate';

  Future<List<IllustrationRow>> illustrationLibrary() async {
    final r = await _db.rpc('admin_illustration_library');
    return _rows(r).map(IllustrationRow.fromJson).toList();
  }

  /// Enqueues a queued row per missing (animal, stage) for the active style. Returns how many NEW rows were created.
  Future<int> enqueueMissing({String variant = 'base'}) async {
    final r = await _db.rpc('illustrations_enqueue_missing', params: {'p_variant': variant});
    return _int(r) ?? 0;
  }

  /// decision: 'approve' | 'reject' | 'regenerate'.
  Future<void> review(String id, String decision) => _db.rpc('illustrations_review', params: {'p_id': id, 'p_decision': decision});

  /// Asks the `illustrate` Edge Function to run up to [passes] claim→generate→QA passes.
  /// Never throws: on failure returns `{'ok': false, 'error': message}`.
  Future<Map<String, dynamic>> runWorker({int passes = 5}) => _invokeIllustrate({'action': 'run', 'passes': passes});

  /// Renders one preview with an unsaved template. Body: {slug, stage, name, template, stage_cues, negative}.
  Future<Map<String, dynamic>> previewIllustration(Map<String, dynamic> body) => _invokeIllustrate({...body, 'action': 'preview'});

  Future<Map<String, dynamic>> _invokeIllustrate(Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke(illustrateFunction, body: body);
      final d = res.data;
      if (d is Map) return {'ok': true, ...d.cast<String, dynamic>()};
      return {'ok': true, 'status': res.status, 'data': d};
    } on FunctionException catch (e) {
      final detail = e.details == null ? (e.reasonPhrase ?? '') : e.details.toString();
      return {'ok': false, 'error': 'Edge Function "$illustrateFunction" returned ${e.status}${detail.isEmpty ? '' : ': $detail'}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> styleTemplates() async {
    final r = await _db.from('style_templates').select().order('version', ascending: false);
    return _rows(r);
  }

  /// Inserts [draft] as version max+1 and makes it the only active template.
  /// Existing illustrations keep their own style_version, so nothing already approved changes.
  Future<int> saveStyleTemplate(Map<String, dynamic> draft) async {
    final latest = await _db.from('style_templates').select('version').order('version', ascending: false).limit(1).maybeSingle();
    final next = (_int(latest?['version']) ?? 0) + 1;
    await _db.from('style_templates').update({'is_active': false}).eq('is_active', true);
    await _db.from('style_templates').insert({
      ...draft,
      'version': next,
      'is_active': true,
      'created_by': _db.auth.currentUser?.id,
    });
    return next;
  }
}

final adminRepoProvider = Provider<AdminRepo>((ref) => AdminRepo(supabase));

final adminAnimalsProvider = FutureProvider<List<AdminAnimal>>((ref) => ref.watch(adminRepoProvider).animals());
final adminIssuedCountsProvider = FutureProvider<Map<String, int>>((ref) => ref.watch(adminRepoProvider).issuedCounts());
final adminRulesProvider = FutureProvider.family<List<AnimalRule>, String>((ref, animalId) => ref.watch(adminRepoProvider).rulesFor(animalId));
final adminConfigProvider = FutureProvider<List<ConfigEntry>>((ref) => ref.watch(adminRepoProvider).config());
final adminSeasonsProvider = FutureProvider<List<Season>>((ref) => ref.watch(adminRepoProvider).seasons());
final adminRegionsProvider = FutureProvider<List<RegionRow>>((ref) => ref.watch(adminRepoProvider).regions());
final adminAgeFactorsProvider = FutureProvider<List<AgeFactor>>((ref) => ref.watch(adminRepoProvider).ageFactors());
final adminHistoryProvider = FutureProvider<List<RuleHistoryRow>>((ref) => ref.watch(adminRepoProvider).history());
final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) => ref.watch(adminRepoProvider).users());
final adminIllustrationsProvider = FutureProvider<List<IllustrationRow>>((ref) => ref.watch(adminRepoProvider).illustrationLibrary());
final adminStyleTemplatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ref.watch(adminRepoProvider).styleTemplates());
