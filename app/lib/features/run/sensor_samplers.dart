/// Small guarded adapters around the pedometer, activity-recognition and health plugins.
/// Each one returns null when the permission is absent or the plugin is unavailable (web),
/// so the payload degrades gracefully (ALGORITHMS.md §10: missing evidence is excluded).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';

/// Step-count delta from the pedometer's cumulative-since-boot stream.
class StepSampler {
  StreamSubscription<StepCount>? _sub;
  int? _first;
  int? _last;
  bool _available = false;

  Future<void> start() async {
    if (kIsWeb) return;
    try {
      _sub = Pedometer.stepCountStream.listen((e) {
        _first ??= e.steps;
        _last = e.steps;
        _available = true;
      }, onError: (_) {
        _available = false;
      });
    } catch (_) {
      _available = false;
    }
  }

  /// Steps taken during the run, or null when the pedometer gave nothing.
  int? get steps {
    if (!_available || _first == null || _last == null) return null;
    final d = _last! - _first!;
    return d < 0 ? null : d;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}

/// Time-weighted activity-class fractions from the platform classifier.
class ActivitySampler {
  StreamSubscription<Activity>? _sub;
  final Map<String, double> _seconds = {'running': 0, 'walking': 0, 'automotive': 0, 'cycling': 0, 'stationary': 0, 'unknown': 0};
  String? _current;
  DateTime? _since;
  bool _any = false;

  Future<void> start() async {
    if (kIsWeb) return;
    try {
      final ar = FlutterActivityRecognition.instance;
      final perm = await ar.checkPermission();
      if (perm != ActivityPermission.GRANTED) return;
      _sub = ar.activityStream.handleError((_) {}).listen((a) {
        final key = _classify(a);
        _rollTo(key);
        _any = true;
      });
    } catch (_) {}
  }

  String _classify(Activity a) {
    final name = a.type.toString().split('.').last.toUpperCase();
    return switch (name) {
      'RUNNING' => 'running',
      'WALKING' => 'walking',
      'IN_VEHICLE' => 'automotive',
      'ON_BICYCLE' => 'cycling',
      'STILL' => 'stationary',
      _ => 'unknown',
    };
  }

  void _rollTo(String? next) {
    final now = DateTime.now();
    if (_current != null && _since != null) {
      _seconds[_current!] = (_seconds[_current!] ?? 0) + now.difference(_since!).inMilliseconds / 1000;
    }
    _current = next;
    _since = now;
  }

  /// Fractions summing to 1, or null when nothing was classified.
  Map<String, double>? finish() {
    _rollTo(null);
    if (!_any) return null;
    final total = _seconds.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;
    return {for (final e in _seconds.entries) e.key: double.parse((e.value / total).toStringAsFixed(3))};
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}

/// Heart-rate summary from HealthKit / Health Connect for a time window.
class HeartRateSampler {
  /// `{mean, max}` in bpm, or null when no permission / no samples.
  static Future<Map<String, int>?> summary(DateTime start, DateTime end) async {
    if (kIsWeb) return null;
    try {
      final h = Health();
      await h.configure();
      final has = await h.hasPermissions(const [HealthDataType.HEART_RATE]);
      if (has == false) return null;
      var points = await h.getHealthDataFromTypes(types: const [HealthDataType.HEART_RATE], startTime: start, endTime: end);
      points = h.removeDuplicates(points);
      final values = <double>[];
      for (final p in points) {
        final v = p.value;
        if (v is NumericHealthValue) {
          final n = v.numericValue.toDouble();
          if (n > 30 && n < 250) values.add(n);
        }
      }
      if (values.isEmpty) return null;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final max = values.reduce((a, b) => a > b ? a : b);
      return {'mean': mean.round(), 'max': max.round()};
    } catch (_) {
      return null;
    }
  }
}
