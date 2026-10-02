/// Data models mirroring docs/API.md. Plain Dart, no codegen, tolerant of missing keys.
library;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../theme/tokens.dart';

enum Rarity { common, uncommon, rare, epic, legendary }

enum Stage { baby, young, adult }

enum Finish { plain, glow, radiant }

enum CardScope { run, weekly, monthly }

enum Verdict { verified, unverified, rejected }

T _enumFrom<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

double? _num(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int? _int(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

extension RarityX on Rarity {
  bool get isRarePlus => index >= Rarity.rare.index;
  String get label => switch (this) {
        Rarity.common => 'Common',
        Rarity.uncommon => 'Uncommon',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Epic',
        Rarity.legendary => 'Legendary',
      };
}

extension StageX on Stage {
  String get label => switch (this) { Stage.baby => 'Baby', Stage.young => 'Young', Stage.adult => 'Adult' };
}

/// An animal species from the `animals` table (encyclopedia + card identity).
class Animal {
  const Animal({
    required this.id,
    required this.slug,
    required this.code,
    required this.name,
    required this.family,
    required this.rarity,
    required this.flavourLine,
    required this.encyclopedia,
    required this.art,
    required this.palette,
    required this.isSecret,
    this.sortOrder = 100,
  });

  final String id, slug, code, name, family, flavourLine;
  final Rarity rarity;
  final Map<String, dynamic> encyclopedia;
  final Map<String, dynamic> art;
  final FamilyPalette palette;
  final bool isSecret;
  final int sortOrder;

  List<String> get facts => ((encyclopedia['facts'] as List?) ?? const []).map((e) => e.toString()).toList();
  String? get habitat => encyclopedia['habitat'] as String?;
  String? get superpower => encyclopedia['superpower'] as String?;
  String? get indiaNote => encyclopedia['india_note'] as String?;
  String? get size => encyclopedia['size'] as String?;
  String? artPath(Stage stage) => art[stage.name] as String?;

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        id: j['id'] as String,
        slug: j['slug'] as String,
        code: (j['code'] ?? '') as String,
        name: j['name'] as String,
        family: (j['family'] ?? 'calm') as String,
        rarity: _enumFrom(Rarity.values, j['rarity'] as String?, Rarity.common),
        flavourLine: (j['flavour_line'] ?? '') as String,
        encyclopedia: (j['encyclopedia'] as Map?)?.cast<String, dynamic>() ?? const {},
        art: (j['art'] as Map?)?.cast<String, dynamic>() ?? const {},
        palette: FamilyPalette.fromJson((j['palette'] as Map?)?.cast<String, dynamic>(), family: (j['family'] ?? 'calm') as String),
        isSecret: (j['is_secret'] ?? false) as bool,
        sortOrder: _int(j['sort_order']) ?? 100,
      );
}

/// A card as returned by `card_json` (RPC results) or joined from the `cards` table.
class CollectibleCard {
  const CollectibleCard({
    required this.id,
    required this.animalId,
    required this.slug,
    required this.name,
    required this.code,
    required this.family,
    required this.rarity,
    required this.flavourLine,
    required this.palette,
    required this.art,
    required this.serialNo,
    required this.scope,
    required this.periodKey,
    required this.tier,
    required this.stage,
    required this.finish,
    required this.season,
    required this.stats,
    required this.verdict,
    required this.issuedAt,
    required this.verifyUrl,
    this.isPublic = true,
  });

  final String id, animalId, slug, name, code, family, flavourLine, periodKey;
  final Rarity rarity;
  final FamilyPalette palette;
  final Map<String, dynamic> art;
  final int serialNo, tier;
  final CardScope scope;
  final Stage stage;
  final Finish finish;
  final String? season;
  final Map<String, dynamic> stats;
  final Verdict verdict;
  final DateTime issuedAt;
  final String verifyUrl;
  final bool isPublic;

  /// "Cheetah #0042" — the serial as printed on the card.
  String get serial => '$name #${serialNo.toString().padLeft(Brand.serialPad, '0')}';
  String get serialShort => '#${serialNo.toString().padLeft(Brand.serialPad, '0')}';
  String? artPath(Stage s) => art[s.name] as String?;

  double? get distanceKm => _num(stats['distance_km']);
  int? get durationS => _int(stats['duration_s']);
  int? get paceSPerKm => _int(stats['pace_s_per_km']);
  int? get runDays => _int(stats['run_days']);
  double? get volumeKm => _num(stats['volume_km']);
  String? get region => stats['region'] as String?;
  bool get variety => stats['variety'] == true;

  /// Stats line per DESIGN.md §5: run → "5.0 km · 19:35 · 3:55/km", weekly → "7 days · 35 km", monthly → "October · Kerala".
  String get statsLine {
    switch (scope) {
      case CardScope.run:
        final parts = <String>[];
        if (distanceKm != null) parts.add('${distanceKm!.toStringAsFixed(1)} km');
        if (durationS != null) parts.add(fmtDuration(durationS!));
        if (paceSPerKm != null) parts.add('${fmtPace(paceSPerKm!)}/km');
        return parts.join(' · ');
      case CardScope.weekly:
        return '${runDays ?? 0} days · ${(volumeKm ?? 0).toStringAsFixed(0)} km${variety ? ' · wanderer' : ''}';
      case CardScope.monthly:
        final m = stats['month'] as String?;
        final monthName = m == null ? '' : _monthName(int.tryParse(m.split('-').last) ?? 1);
        return [monthName, region].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    }
  }

  factory CollectibleCard.fromJson(Map<String, dynamic> j) {
    final family = (j['family'] ?? 'calm') as String;
    return CollectibleCard(
      id: j['id'] as String,
      animalId: (j['animal_id'] ?? '') as String,
      slug: (j['slug'] ?? '') as String,
      name: (j['name'] ?? 'Animal') as String,
      code: (j['code'] ?? '') as String,
      family: family,
      rarity: _enumFrom(Rarity.values, j['rarity'] as String?, Rarity.common),
      flavourLine: (j['flavour_line'] ?? '') as String,
      palette: FamilyPalette.fromJson((j['palette'] as Map?)?.cast<String, dynamic>(), family: family),
      art: (j['art'] as Map?)?.cast<String, dynamic>() ?? const {},
      serialNo: _int(j['serial_no']) ?? 0,
      scope: _enumFrom(CardScope.values, j['scope'] as String?, CardScope.run),
      periodKey: (j['period_key'] ?? '') as String,
      tier: _int(j['tier']) ?? 0,
      stage: _enumFrom(Stage.values, j['stage'] as String?, Stage.baby),
      finish: _enumFrom(Finish.values, j['finish'] as String?, Finish.plain),
      season: j['season'] as String?,
      stats: (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
      verdict: _enumFrom(Verdict.values, j['verdict'] as String?, Verdict.verified),
      issuedAt: DateTime.tryParse((j['issued_at'] ?? '') as String)?.toLocal() ?? DateTime.now(),
      verifyUrl: (j['verify_url'] ?? '') as String,
      isPublic: (j['is_public'] ?? true) as bool,
    );
  }

  /// Build from a `cards` row joined with `animals(*)` and `seasons(name)` via PostgREST select.
  factory CollectibleCard.fromRow(Map<String, dynamic> row) {
    final a = (row['animals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final s = (row['seasons'] as Map?)?.cast<String, dynamic>();
    return CollectibleCard.fromJson({
      ...a,
      ...row,
      'animal_id': row['animal_id'] ?? a['id'],
      'id': row['id'],
      'season': s?['name'],
      'verify_url': row['verify_url'] ?? '',
    });
  }
}

/// A celebration attached to a card result (growth, mastered, discovery, welcome_back).
class Celebration {
  const Celebration({required this.kind, this.message, this.animal, this.stage, this.tier, this.trigger});
  final String kind;
  final String? message, animal, stage, trigger;
  final int? tier;

  factory Celebration.fromJson(Map<String, dynamic> j) => Celebration(
        kind: (j['kind'] ?? '') as String,
        message: j['message'] as String?,
        animal: j['animal'] as String?,
        stage: j['stage'] as String?,
        tier: _int(j['tier']),
        trigger: j['trigger'] as String?,
      );

  /// DESIGN.md §6 discovery caption: never reveals thresholds.
  String get caption {
    if (message != null) return message!;
    final t = trigger ?? '';
    if (t.startsWith('time:night')) return 'You found this one because you ran at night.';
    if (t.startsWith('time:dawn')) return 'You found this one because you ran at dawn.';
    if (t == 'explorer') return 'You found this one because you went somewhere new.';
    if (t.startsWith('state:')) return 'A souvenir from where you ran.';
    if (t == 'migratory') return 'You found this one by running across India.';
    return '';
  }
}

/// Result of `submit_run`.
class RunResult {
  const RunResult({
    required this.runId,
    required this.verdict,
    required this.trust,
    this.card,
    this.celebrations = const [],
    this.message,
    this.band,
    this.perfIndex,
    this.timeWindow,
    this.flags = const [],
    this.tier = 0,
    this.duplicate = false,
    this.capped = false,
    this.floorMet = true,
  });

  final String runId;
  final Verdict verdict;
  final double trust;
  final CollectibleCard? card;
  final List<Celebration> celebrations;
  final String? message, band, timeWindow;
  final double? perfIndex;
  final List<String> flags;
  final int tier;
  final bool duplicate, capped, floorMet;

  factory RunResult.fromJson(Map<String, dynamic> j) => RunResult(
        runId: (j['run_id'] ?? '') as String,
        verdict: _enumFrom(Verdict.values, j['verdict'] as String?, Verdict.verified),
        trust: _num(j['trust']) ?? 0,
        card: j['card'] is Map ? CollectibleCard.fromJson((j['card'] as Map).cast<String, dynamic>()) : null,
        celebrations: ((j['celebrations'] as List?) ?? const []).map((e) => Celebration.fromJson((e as Map).cast<String, dynamic>())).toList(),
        message: j['message'] as String?,
        band: j['band'] as String?,
        perfIndex: _num(j['perf_index']),
        timeWindow: j['time_window'] as String?,
        flags: ((j['flags'] as List?) ?? const []).map((e) => e.toString()).toList(),
        tier: _int(j['tier']) ?? 0,
        duplicate: j['duplicate'] == true,
        capped: j['capped'] == true,
        floorMet: j['floor'] != false,
      );
}

/// A pending weekly/monthly card from `claim_pending_cards`.
class PendingCard {
  const PendingCard({required this.scope, required this.card, this.celebrations = const [], this.runDays});
  final CardScope scope;
  final CollectibleCard card;
  final List<Celebration> celebrations;
  final int? runDays;

  factory PendingCard.fromJson(Map<String, dynamic> j) => PendingCard(
        scope: _enumFrom(CardScope.values, j['scope'] as String?, CardScope.weekly),
        card: CollectibleCard.fromJson((j['card'] as Map).cast<String, dynamic>()),
        celebrations: ((j['celebrations'] as List?) ?? const []).map((e) => Celebration.fromJson((e as Map).cast<String, dynamic>())).toList(),
        runDays: _int(j['run_days']),
      );
}

/// `profiles` row.
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.birthYear,
    this.sex,
    this.homeRegion,
    this.timezone = Brand.defaultTimezone,
    this.connected = const [],
    this.isAdmin = false,
    this.lastRunAt,
  });

  final String id, displayName, timezone;
  final int? birthYear;
  final String? sex, homeRegion;
  final List<String> connected;
  final bool isAdmin;
  final DateTime? lastRunAt;

  bool has(String purpose) => connected.contains(purpose);

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        displayName: (j['display_name'] ?? 'Runner') as String,
        birthYear: _int(j['birth_year']),
        sex: j['sex'] as String?,
        homeRegion: j['home_region'] as String?,
        timezone: (j['timezone'] ?? Brand.defaultTimezone) as String,
        connected: ((j['connected'] as List?) ?? const []).map((e) => e.toString()).toList(),
        isAdmin: (j['is_admin'] ?? false) as bool,
        lastRunAt: j['last_run_at'] == null ? null : DateTime.tryParse(j['last_run_at'] as String)?.toLocal(),
      );
}

/// `runs` row (stats only; the track is private and loaded separately when needed).
class RunSummary {
  const RunSummary({
    required this.id,
    required this.startedAt,
    required this.localDate,
    required this.distanceM,
    required this.movingS,
    required this.avgSpeedKmh,
    required this.verdict,
    required this.eligible,
    this.speedBand,
    this.timeWindow,
    this.flags = const [],
    this.stateCode,
    this.elevGainM,
  });

  final String id;
  final DateTime startedAt;
  final DateTime localDate;
  final double distanceM, avgSpeedKmh;
  final int movingS;
  final Verdict verdict;
  final bool eligible;
  final String? speedBand, timeWindow, stateCode;
  final List<String> flags;
  final double? elevGainM;

  double get distanceKm => distanceM / 1000;
  int get paceSPerKm => distanceKm <= 0 ? 0 : (movingS / distanceKm).round();

  factory RunSummary.fromJson(Map<String, dynamic> j) => RunSummary(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
        localDate: DateTime.parse(j['local_date'] as String),
        distanceM: _num(j['distance_m']) ?? 0,
        movingS: _int(j['moving_s']) ?? 0,
        avgSpeedKmh: _num(j['avg_speed_kmh']) ?? 0,
        verdict: _enumFrom(Verdict.values, j['verdict'] as String?, Verdict.verified),
        eligible: (j['eligible'] ?? false) as bool,
        speedBand: j['speed_band'] as String?,
        timeWindow: j['time_window'] as String?,
        flags: ((j['flags'] as List?) ?? const []).map((e) => e.toString()).toList(),
        stateCode: j['state_code'] as String?,
        elevGainM: _num(j['elev_gain_m']),
      );
}

/// `bonds` row: the growth relationship with one animal.
class Bond {
  const Bond({required this.animalId, required this.earnCount, required this.earnWeeks, required this.stage, required this.mastered});
  final String animalId;
  final int earnCount, earnWeeks;
  final Stage stage;
  final bool mastered;
  factory Bond.fromJson(Map<String, dynamic> j) => Bond(
        animalId: j['animal_id'] as String,
        earnCount: _int(j['earn_count']) ?? 0,
        earnWeeks: _int(j['earn_weeks']) ?? 0,
        stage: _enumFrom(Stage.values, j['stage'] as String?, Stage.baby),
        mastered: (j['mastered'] ?? false) as bool,
      );
}

/// `events` row (unseen celebrations shown on Today).
class AppEvent {
  const AppEvent({required this.id, required this.kind, required this.payload, required this.createdAt});
  final int id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  factory AppEvent.fromJson(Map<String, dynamic> j) => AppEvent(
        id: _int(j['id']) ?? 0,
        kind: (j['kind'] ?? '') as String,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String)?.toLocal() ?? DateTime.now(),
      );
}

/// Result of `lookup_serial`.
class SerialLookup {
  const SerialLookup({required this.found, this.card, this.earnedBy, this.issuedSoFar, this.reason, this.hint, this.animalName});
  final bool found;
  final CollectibleCard? card;
  final String? earnedBy, reason, hint, animalName;
  final int? issuedSoFar;
  factory SerialLookup.fromJson(Map<String, dynamic> j) => SerialLookup(
        found: j['found'] == true,
        card: j['card'] is Map ? CollectibleCard.fromJson((j['card'] as Map).cast<String, dynamic>()) : null,
        earnedBy: j['earned_by'] as String?,
        issuedSoFar: _int(j['issued_so_far']),
        reason: j['reason'] as String?,
        hint: j['hint'] as String?,
        animalName: j['animal'] as String?,
      );
}

// ---------- formatting helpers ----------
String fmtDuration(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

String fmtPace(int secondsPerKm) => '${secondsPerKm ~/ 60}:${(secondsPerKm % 60).toString().padLeft(2, '0')}';

String _monthName(int m) => const ['January','February','March','April','May','June','July','August','September','October','November','December'][(m - 1).clamp(0, 11)];

String fmtDate(DateTime d) => '${d.day} ${_monthName(d.month).substring(0, 3)} ${d.year}';

/// Rarity border spec (DESIGN.md §3.3).
class RarityStyle {
  const RarityStyle({required this.width, required this.animated, required this.foil, required this.particles});
  final double width;
  final bool animated, foil, particles;
  static RarityStyle of(Rarity r) => switch (r) {
        Rarity.common => const RarityStyle(width: 1, animated: false, foil: false, particles: false),
        Rarity.uncommon => const RarityStyle(width: 1.5, animated: false, foil: false, particles: false),
        Rarity.rare => const RarityStyle(width: 2, animated: false, foil: false, particles: false),
        Rarity.epic => const RarityStyle(width: 2.5, animated: false, foil: true, particles: false),
        Rarity.legendary => const RarityStyle(width: 3, animated: true, foil: true, particles: true),
      };
}

/// Convenience: a Color for a verdict badge.
Color verdictColor(BuildContext context, Verdict v) => switch (v) {
      Verdict.verified => context.colors.success,
      Verdict.unverified => context.colors.warn,
      Verdict.rejected => context.colors.danger,
    };
