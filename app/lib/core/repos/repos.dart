/// Data access layer: thin wrappers over Supabase tables and RPCs (docs/API.md), exposed as Riverpod providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../supabase.dart';

const _cardSelect = '*, animals(*), seasons(name)';

class AppApi {
  AppApi(this._db);
  final SupabaseClient _db;

  String? get uid => _db.auth.currentUser?.id;

  // ---------- RPC ----------
  Future<RunResult> submitRun(Map<String, dynamic> payload) async {
    final r = await _db.rpc('submit_run', params: {'p': payload});
    return RunResult.fromJson((r as Map).cast<String, dynamic>());
  }

  Future<List<PendingCard>> claimPendingCards() async {
    final r = await _db.rpc('claim_pending_cards');
    return ((r as List?) ?? const []).map((e) => PendingCard.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<int> markEventsSeen(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final r = await _db.rpc('mark_events_seen', params: {'p_ids': ids});
    return (r as num?)?.toInt() ?? 0;
  }

  Future<SerialLookup> lookupSerial(String query) async {
    final r = await _db.rpc('lookup_serial', params: {'q': query});
    return SerialLookup.fromJson((r as Map).cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> adminSimulatePool(Map<String, dynamic> ctx, {String? asUser}) async {
    final r = await _db.rpc('admin_simulate_pool', params: {'ctx': ctx, 'p_as_user': asUser});
    return (r as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> adminPerfPreview({required double vKmh, required double dKm, String? sex, int? age}) async {
    final r = await _db.rpc('admin_perf_preview', params: {'p_v_kmh': vKmh, 'p_d_km': dKm, 'p_sex': sex, 'p_age': age});
    return (r as Map).cast<String, dynamic>();
  }

  // ---------- profile ----------
  Future<Profile?> myProfile() async {
    final id = uid;
    if (id == null) return null;
    final r = await _db.from('profiles').select().eq('id', id).maybeSingle();
    return r == null ? null : Profile.fromJson(r);
  }

  Future<void> updateProfile(Map<String, dynamic> patch) async {
    final id = uid;
    if (id == null) return;
    await _db.from('profiles').update(patch).eq('id', id);
  }

  // ---------- cards ----------
  Future<List<CollectibleCard>> myCards({int limit = 500}) async {
    final r = await _db.from('cards').select(_cardSelect).order('issued_at', ascending: false).limit(limit);
    return (r as List).map((e) => CollectibleCard.fromRow((e as Map).cast<String, dynamic>())).toList();
  }

  Future<CollectibleCard?> card(String id) async {
    final r = await _db.from('cards').select(_cardSelect).eq('id', id).maybeSingle();
    return r == null ? null : CollectibleCard.fromRow(r);
  }

  Future<void> setCardPublic(String id, bool isPublic) => _db.from('cards').update({'is_public': isPublic}).eq('id', id);

  // ---------- runs ----------
  Future<List<RunSummary>> myRuns({int limit = 400}) async {
    final r = await _db.from('runs').select().order('started_at', ascending: false).limit(limit);
    return (r as List).map((e) => RunSummary.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  // ---------- animals / encyclopedia ----------
  Future<List<Animal>> animals() async {
    final r = await _db.from('animals').select().eq('is_active', true).order('sort_order').order('name');
    return (r as List).map((e) => Animal.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Map<String, int>> issuedCounts() async {
    final r = await _db.from('animal_counters').select('animal_id,next_serial');
    return {for (final e in (r as List)) e['animal_id'] as String: (e['next_serial'] as num).toInt()};
  }

  Future<List<Bond>> myBonds() async {
    final r = await _db.from('bonds').select();
    return (r as List).map((e) => Bond.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<List<AppEvent>> unseenEvents() async {
    final r = await _db.from('events').select().isFilter('seen_at', null).order('created_at');
    return (r as List).map((e) => AppEvent.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Map<String, dynamic>> config(String key) async {
    final r = await _db.from('config').select('value').eq('key', key).maybeSingle();
    return (r?['value'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  Future<List<Map<String, dynamic>>> regions() async {
    final r = await _db.from('regions').select().neq('kind', 'country').order('name');
    return (r as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}

final apiProvider = Provider<AppApi>((ref) => AppApi(supabase));

final profileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).myProfile();
});

final myCardsProvider = FutureProvider<List<CollectibleCard>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).myCards();
});

final myRunsProvider = FutureProvider<List<RunSummary>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).myRuns();
});

final animalsProvider = FutureProvider<List<Animal>>((ref) => ref.watch(apiProvider).animals());
final issuedCountsProvider = FutureProvider<Map<String, int>>((ref) => ref.watch(apiProvider).issuedCounts());
final myBondsProvider = FutureProvider<List<Bond>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).myBonds();
});
final unseenEventsProvider = FutureProvider<List<AppEvent>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).unseenEvents();
});
final weeklyConfigProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.watch(apiProvider).config('weekly'));
final regionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ref.watch(apiProvider).regions());

/// Invalidate everything that changes after a run or a claim.
void refreshAfterCard(WidgetRef ref) {
  ref.invalidate(myCardsProvider);
  ref.invalidate(myRunsProvider);
  ref.invalidate(myBondsProvider);
  ref.invalidate(unseenEventsProvider);
  ref.invalidate(issuedCountsProvider);
  ref.invalidate(profileProvider);
}
