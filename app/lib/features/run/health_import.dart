/// One-tap import of recent running workouts from HealthKit / Health Connect.
/// Produces `submit_run` payloads with `source: healthkit | health_connect`, no track.
/// `client_run_id` is a UUID v5 of the workout's own id, so re-imports are idempotent server-side.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';
import 'gps_filter.dart';
import 'run_queue.dart';

class HealthImportSummary {
  const HealthImportSummary({required this.found, required this.submitted, required this.cards, required this.queued, this.message});
  final int found, submitted, cards, queued;
  final String? message;
}

class HealthImport {
  HealthImport._();

  static const _seenKey = 'health_import_seen';
  static String get source => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? 'health_connect' : 'healthkit';

  static bool _isRunning(HealthWorkoutActivityType t) {
    final n = t.toString().split('.').last.toUpperCase();
    return n.startsWith('RUNNING') || n == 'TRACK_AND_FIELD';
  }

  /// Imports running workouts from the last [lookback]. Submits each; queues on network trouble.
  static Future<HealthImportSummary> importRecent(
    PugApi api,
    RunQueue queue, {
    Duration lookback = const Duration(days: 14),
    String timezone = 'Asia/Kolkata',
  }) async {
    if (kIsWeb) {
      return const HealthImportSummary(found: 0, submitted: 0, cards: 0, queued: 0, message: 'Health import is available in the phone app.');
    }
    final h = Health();
    try {
      await h.configure();
      final ok = await h.requestAuthorization(
        const [HealthDataType.WORKOUT, HealthDataType.HEART_RATE, HealthDataType.STEPS],
        permissions: const [HealthDataAccess.READ, HealthDataAccess.READ, HealthDataAccess.READ],
      );
      if (!ok) {
        return const HealthImportSummary(found: 0, submitted: 0, cards: 0, queued: 0, message: 'Health access was not granted. You can allow it in phone settings.');
      }
    } catch (_) {
      return const HealthImportSummary(found: 0, submitted: 0, cards: 0, queued: 0, message: 'Health data is not available on this device.');
    }

    final end = DateTime.now();
    final start = end.subtract(lookback);
    List<HealthDataPoint> workouts;
    try {
      workouts = h.removeDuplicates(await h.getHealthDataFromTypes(types: const [HealthDataType.WORKOUT], startTime: start, endTime: end));
    } catch (_) {
      return const HealthImportSummary(found: 0, submitted: 0, cards: 0, queued: 0, message: 'We couldn\'t read workouts right now. Try again in a moment.');
    }

    SharedPreferences? prefs;
    Set<String> seen = {};
    try {
      prefs = await SharedPreferences.getInstance();
      seen = (prefs.getStringList(_seenKey) ?? const []).toSet();
    } catch (_) {}

    var found = 0, submitted = 0, cards = 0, queued = 0;
    for (final p in workouts) {
      final v = p.value;
      if (v is! WorkoutHealthValue) continue;
      if (!_isRunning(v.workoutActivityType)) continue;
      final durationS = p.dateTo.difference(p.dateFrom).inSeconds;
      if (durationS < 60) continue;
      found++;
      if (seen.contains(p.uuid)) continue;

      final hr = await _heartRate(h, p.dateFrom, p.dateTo);
      final payload = <String, dynamic>{
        'client_run_id': const Uuid().v5(Namespace.url.value, 'pugmark:health:${p.uuid}'),
        'source': source,
        'started_at': isoWithOffset(p.dateFrom),
        'elapsed_s': durationS,
        'moving_s': durationS,
        'timezone': timezone,
        'state_code': null,
        'track': <List<dynamic>>[],
        'distance_m': v.totalDistance ?? 0,
        'steps': v.totalSteps,
        'splits_kmh': <double>[],
        'accel': null,
        'activity': {'running': 1.0, 'walking': 0.0, 'automotive': 0.0, 'cycling': 0.0, 'stationary': 0.0, 'unknown': 0.0},
        'hr': hr,
      };
      try {
        final RunResult r = await api.submitRun(payload).timeout(const Duration(seconds: 30));
        submitted++;
        if (r.card != null) cards++;
        seen.add(p.uuid);
      } catch (e) {
        if (isNetworkError(e)) {
          await queue.enqueue(payload);
          queued++;
          seen.add(p.uuid);
        }
      }
    }
    try {
      await prefs?.setStringList(_seenKey, seen.toList());
    } catch (_) {}

    final msg = found == 0
        ? 'No running workouts in the last ${lookback.inDays} days.'
        : queued > 0
            ? 'Saved $queued ${queued == 1 ? 'run' : 'runs'}. We\'ll fetch the cards when you\'re back online.'
            : submitted == 0
                ? 'Everything here was already in your collection.'
                : 'Imported $submitted ${submitted == 1 ? 'run' : 'runs'}${cards > 0 ? ' · $cards new ${cards == 1 ? 'card' : 'cards'}' : ''}.';
    return HealthImportSummary(found: found, submitted: submitted, cards: cards, queued: queued, message: msg);
  }

  static Future<Map<String, int>?> _heartRate(Health h, DateTime from, DateTime to) async {
    try {
      final pts = h.removeDuplicates(await h.getHealthDataFromTypes(types: const [HealthDataType.HEART_RATE], startTime: from, endTime: to));
      final vals = <double>[];
      for (final p in pts) {
        final v = p.value;
        if (v is NumericHealthValue) {
          final n = v.numericValue.toDouble();
          if (n > 30 && n < 250) vals.add(n);
        }
      }
      if (vals.isEmpty) return null;
      return {'mean': (vals.reduce((a, b) => a + b) / vals.length).round(), 'max': vals.reduce((a, b) => a > b ? a : b).round()};
    } catch (_) {
      return null;
    }
  }
}
