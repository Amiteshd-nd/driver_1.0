/// Pure track math for the recorder (ALGORITHMS.md §9.1 track hygiene):
/// accuracy filter, GPS-jump filter, haversine distance, smoothed elevation gain,
/// rolling 1-minute speed, per-km splits and ≤ 2000-point downsampling.
library;

import 'dart:math' as math;

/// One kept GPS fix. `t` is seconds since the run started.
class TrackPoint {
  const TrackPoint({required this.lat, required this.lon, required this.alt, required this.t, required this.acc});
  final double lat, lon;
  final double? alt;
  final double t;
  final double? acc;

  /// API.md shape: `[lat, lon, alt|null, t_offset_s, accuracy_m|null]`.
  List<dynamic> toJson() => [
        double.parse(lat.toStringAsFixed(6)),
        double.parse(lon.toStringAsFixed(6)),
        alt == null ? null : double.parse(alt!.toStringAsFixed(1)),
        t.round(),
        acc == null ? null : acc!.round(),
      ];
}

/// Great-circle distance in metres.
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371008.8;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180, dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Thresholds (ALGORITHMS.md §9.1 and §10).
class GpsRules {
  GpsRules._();
  static const double maxAccuracyM = 50;
  static const double jumpKmh = 30;
  static const double autoPauseKmh = 1.0;
  static const Duration autoPauseAfter = Duration(seconds: 10);
  static const Duration dropoutAfter = Duration(seconds: 30);
  static const int maxUploadPoints = 2000;
  static const double resampleEveryS = 5;
}

/// Why a fix was dropped (for diagnostics / UI pill).
enum FixVerdict { kept, inaccurate, jump, duplicate }

/// Stateful hygiene filter: feed every raw fix, read back the kept track and distance.
class TrackFilter {
  final List<TrackPoint> points = [];
  double distanceM = 0;
  double elevationGainM = 0;
  double _emaAlt = double.nan;
  double _lastGainAlt = double.nan;

  /// (t, cumulative distance) samples for the rolling 1-minute speed.
  final List<_DistSample> _samples = [];
  double maxOneMinuteKmh = 0;

  /// Most recent implied speed between kept fixes, km/h (null until two fixes).
  double? lastSpeedKmh;

  /// Returns the verdict for this fix. `countDistance` is false during a GPS dropout (> 30 s since last fix):
  /// the point is still kept for the track, but no distance is credited for the gap.
  FixVerdict add({
    required double lat,
    required double lon,
    required double? alt,
    required double? altAccuracy,
    required double t,
    required double? accuracy,
    required bool countDistance,
  }) {
    if (accuracy != null && accuracy > GpsRules.maxAccuracyM) return FixVerdict.inaccurate;
    if (points.isNotEmpty) {
      final prev = points.last;
      final dt = t - prev.t;
      if (dt <= 0) return FixVerdict.duplicate;
      final d = haversineM(prev.lat, prev.lon, lat, lon);
      final kmh = d / dt * 3.6;
      if (kmh > GpsRules.jumpKmh) return FixVerdict.jump;
      lastSpeedKmh = kmh;
      if (countDistance) {
        distanceM += d;
        _addElevation(alt, altAccuracy);
      } else {
        // Re-seed elevation after a gap so a long dropout never produces a cliff.
        _emaAlt = alt ?? _emaAlt;
        _lastGainAlt = _emaAlt;
      }
    } else {
      _emaAlt = alt ?? double.nan;
      _lastGainAlt = _emaAlt;
    }
    points.add(TrackPoint(lat: lat, lon: lon, alt: alt, t: t, acc: accuracy));
    _samples.add(_DistSample(t, distanceM));
    _updateRolling();
    return FixVerdict.kept;
  }

  void _addElevation(double? alt, double? altAccuracy) {
    if (alt == null || alt == 0 || (altAccuracy != null && altAccuracy > 20)) return;
    if (_emaAlt.isNaN) {
      _emaAlt = alt;
      _lastGainAlt = alt;
      return;
    }
    _emaAlt = _emaAlt + 0.2 * (alt - _emaAlt);
    final delta = _emaAlt - _lastGainAlt;
    // Hysteresis: credit gain in 3 m steps to shrug off barometric/GPS wobble.
    if (delta >= 3) {
      elevationGainM += delta;
      _lastGainAlt = _emaAlt;
    } else if (delta <= -3) {
      _lastGainAlt = _emaAlt;
    }
  }

  void _updateRolling() {
    final now = _samples.last;
    while (_samples.length > 2 && now.t - _samples[1].t >= 60) {
      _samples.removeAt(0);
    }
    final first = _samples.first;
    final dt = now.t - first.t;
    if (dt >= 60) {
      final kmh = (now.d - first.d) / dt * 3.6;
      if (kmh > maxOneMinuteKmh) maxOneMinuteKmh = kmh;
    }
  }

  /// Centroid of kept points (for reverse geocoding), or null.
  ({double lat, double lon})? centroid() {
    if (points.isEmpty) return null;
    var la = 0.0, lo = 0.0;
    for (final p in points) {
      la += p.lat;
      lo += p.lon;
    }
    return (lat: la / points.length, lon: lo / points.length);
  }

  /// ≤ 2000 points, ~1 per 5 s, first and last always kept.
  List<List<dynamic>> downsampled() {
    if (points.isEmpty) return const [];
    final out = <TrackPoint>[];
    double nextT = points.first.t;
    for (final p in points) {
      if (p.t >= nextT) {
        out.add(p);
        nextT = p.t + GpsRules.resampleEveryS;
      }
    }
    if (out.last != points.last) out.add(points.last);
    if (out.length > GpsRules.maxUploadPoints) {
      final step = out.length / GpsRules.maxUploadPoints;
      final thinned = <TrackPoint>[];
      for (var i = 0; i < GpsRules.maxUploadPoints; i++) {
        thinned.add(out[(i * step).floor()]);
      }
      if (thinned.last != out.last) thinned[thinned.length - 1] = out.last;
      return thinned.map((p) => p.toJson()).toList();
    }
    return out.map((p) => p.toJson()).toList();
  }
}

class _DistSample {
  const _DistSample(this.t, this.d);
  final double t, d;
}

/// Per-km split tracker driven by (moving seconds, cumulative distance).
class SplitTracker {
  final List<double> splitsKmh = [];
  double _nextKmM = 1000;
  double _lastSplitMovingS = 0;
  double _lastDistance = 0;
  double _lastMovingS = 0;

  void update({required double distanceM, required double movingS}) {
    while (distanceM >= _nextKmM) {
      // Linear interpolation of the moment the km boundary was crossed.
      final segD = distanceM - _lastDistance;
      final frac = segD <= 0 ? 1.0 : ((_nextKmM - _lastDistance) / segD).clamp(0.0, 1.0);
      final crossS = _lastMovingS + (movingS - _lastMovingS) * frac;
      final dur = crossS - _lastSplitMovingS;
      if (dur > 0) splitsKmh.add(double.parse((3600 / dur).toStringAsFixed(2)));
      _lastSplitMovingS = crossS;
      _nextKmM += 1000;
    }
    _lastDistance = distanceM;
    _lastMovingS = movingS;
  }
}

/// Format a local DateTime as ISO 8601 with its UTC offset (Dart omits the offset by default).
String isoWithOffset(DateTime d) {
  final local = d.toLocal();
  final off = local.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final h = off.inHours.abs().toString().padLeft(2, '0');
  final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final base = local.toIso8601String().split('.').first;
  return '$base$sign$h:$m';
}
