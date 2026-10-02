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

  /// Public URL for an `animals.art` path (`card-art/<slug>/<stage>.png`).
  String artUrl(String path) {
    final p = path.startsWith('$artBucket/') ? path.substring(artBucket.length + 1) : path;
    return _db.storage.from(artBucket).getPublicUrl(p);
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
