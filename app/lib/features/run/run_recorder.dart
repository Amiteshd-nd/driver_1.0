/// The run recorder: GPS + steps + footfall + activity + heart rate → one `submit_run` payload.
/// Pure math lives in gps_filter.dart / footfall.dart; plugin adapters in sensor_samplers.dart.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';

import 'footfall.dart';
import 'gps_filter.dart';
import 'india_states.dart';
import 'sensor_samplers.dart';

enum RunPhase { idle, running, paused, autoPaused, finishing, done }

enum GpsStatus {
  /// Permission granted, fixes arriving within the last 30 s.
  good,

  /// No fix yet or none for > 30 s ("Looking for GPS…").
  searching,

  /// Permission is "while in use" only — fine while the screen is on.
  foregroundOnly,

  /// Permission denied or location services off → timer-only run.
  denied,

  /// Not applicable (not started).
  off,
}

class RunRecorder extends ChangeNotifier {
  RunRecorder({required this.timezone});

  final String timezone;
  final String clientRunId = const Uuid().v4();

  RunPhase phase = RunPhase.idle;
  GpsStatus gps = GpsStatus.off;
  DateTime? startedAt;
  Duration elapsed = Duration.zero;
  Duration moving = Duration.zero;
  double get distanceM => _track.distanceM;
  double? get currentSpeedKmh => _speedKmh;
  double get elevationGainM => _track.elevationGainM;
  double get maxOneMinuteKmh => _track.maxOneMinuteKmh;
  List<double> get splitsKmh => List.unmodifiable(_splits.splitsKmh);
  int get keptPoints => _track.points.length;
  bool get hasTrack => _track.points.length >= 2;
  String? lastError;

  final TrackFilter _track = TrackFilter();
  final SplitTracker _splits = SplitTracker();
  final FootfallAnalyzer _footfall = FootfallAnalyzer();
  final StepSampler _steps = StepSampler();
  final ActivitySampler _activity = ActivitySampler();

  Timer? _tick;
  final Stopwatch _clock = Stopwatch();
  StreamSubscription<Position>? _posSub;
  StreamSubscription<UserAccelerometerEvent>? _accSub;
  DateTime? _lastFixAt;
  double? _speedKmh;
  double? _stillSince; // seconds on the run clock when speed first dropped below the auto-pause threshold
  bool _locationAllowed = false;

  /// Current pace in seconds per km from the smoothed speed, or null when still/unknown.
  int? get currentPaceSPerKm {
    final v = _speedKmh;
    if (v == null || v < 1.5) return null;
    return (3600 / v).round();
  }

  bool get isActive => phase == RunPhase.running || phase == RunPhase.paused || phase == RunPhase.autoPaused;

  // ---------- lifecycle ----------

  Future<void> start() async {
    if (phase != RunPhase.idle) return;
    startedAt = DateTime.now();
    phase = RunPhase.running;
    _clock.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    notifyListeners();
    await _startLocation();
    await _steps.start();
    await _activity.start();
    _startAccelerometer();
    notifyListeners();
  }

  void pause() {
    if (phase != RunPhase.running && phase != RunPhase.autoPaused) return;
    phase = RunPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (phase != RunPhase.paused) return;
    phase = RunPhase.running;
    _stillSince = null;
    notifyListeners();
  }

  /// Stops sensors and builds the `submit_run` payload (API.md). Call once.
  Future<Map<String, dynamic>> finish() async {
    phase = RunPhase.finishing;
    notifyListeners();
    _tick?.cancel();
    _clock.stop();
    await _posSub?.cancel();
    await _accSub?.cancel();
    await _steps.stop();
    final activity = _activity.finish();
    await _activity.stop();
    final footfall = _footfall.finish();
    final started = startedAt ?? DateTime.now();
    final ended = DateTime.now();
    final hr = await HeartRateSampler.summary(started, ended);
    final stateCode = await _reverseGeocodeState();
    final steps = _steps.steps;

    final payload = <String, dynamic>{
      'client_run_id': clientRunId,
      'source': 'phone',
      'started_at': isoWithOffset(started),
      'elapsed_s': elapsed.inSeconds,
      'moving_s': moving.inSeconds,
      'timezone': timezone,
      'state_code': stateCode,
      'track': hasTrack ? _track.downsampled() : <List<dynamic>>[],
      'distance_m': distanceM.round(),
      'steps': steps,
      'splits_kmh': _splits.splitsKmh,
      'accel': footfall?.toJson(),
      'activity': activity,
      'hr': hr,
    };
    phase = RunPhase.done;
    notifyListeners();
    return payload;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _posSub?.cancel();
    _accSub?.cancel();
    _steps.stop();
    _activity.stop();
    super.dispose();
  }

  // ---------- timing ----------

  void _onTick() {
    elapsed = _clock.elapsed;
    if (phase == RunPhase.running) moving += const Duration(seconds: 1);
    if (_locationAllowed && gps != GpsStatus.denied) {
      final last = _lastFixAt;
      final stale = last == null || DateTime.now().difference(last) > GpsRules.dropoutAfter;
      final next = stale ? GpsStatus.searching : (_foregroundOnly ? GpsStatus.foregroundOnly : GpsStatus.good);
      if (stale) _speedKmh = null;
      if (next != gps) gps = next;
    }
    notifyListeners();
  }

  bool _foregroundOnly = false;

  // ---------- location ----------

  Future<void> _startLocation() async {
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        gps = GpsStatus.denied;
        lastError = 'Location is switched off on this phone. The run will be timed, not measured.';
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever || perm == LocationPermission.unableToDetermine) {
        gps = GpsStatus.denied;
        lastError = 'Without location this run is timed, not measured. You can allow it under You → Permissions.';
        return;
      }
      _locationAllowed = true;
      _foregroundOnly = perm == LocationPermission.whileInUse;
      gps = GpsStatus.searching;
      _posSub = Geolocator.getPositionStream(locationSettings: _settings()).listen(_onPosition, onError: (Object e) {
        lastError = 'GPS hiccup: ${e.runtimeType}';
        notifyListeners();
      });
    } catch (e) {
      gps = GpsStatus.denied;
      lastError = 'Location is not available here. The run will be timed, not measured.';
    }
  }

  LocationSettings _settings() {
    if (kIsWeb) return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: 'Flying Cobra is recording your run',
            notificationText: 'Distance and route are measured on your phone.',
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.fitness,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: !_foregroundOnly,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);
    }
  }

  void _onPosition(Position p) {
    if (phase == RunPhase.finishing || phase == RunPhase.done) return;
    final now = DateTime.now();
    final gapTooLong = _lastFixAt != null && now.difference(_lastFixAt!) > GpsRules.dropoutAfter;
    _lastFixAt = now;
    final t = _clock.elapsed.inMilliseconds / 1000;
    final acc = p.accuracy.isFinite && p.accuracy > 0 ? p.accuracy : null;
    final alt = p.altitude.isFinite && p.altitude != 0 ? p.altitude : null;
    final altAcc = p.altitudeAccuracy.isFinite && p.altitudeAccuracy > 0 ? p.altitudeAccuracy : null;
    final countDistance = phase == RunPhase.running && !gapTooLong;

    final verdict = _track.add(lat: p.latitude, lon: p.longitude, alt: alt, altAccuracy: altAcc, t: t, accuracy: acc, countDistance: countDistance);
    if (verdict == FixVerdict.kept) {
      final raw = _track.lastSpeedKmh;
      final platform = p.speed.isFinite && p.speed >= 0 ? p.speed * 3.6 : null;
      final sample = raw ?? platform;
      if (sample != null) _speedKmh = _speedKmh == null ? sample : _speedKmh! + 0.35 * (sample - _speedKmh!);
      _splits.update(distanceM: distanceM, movingS: moving.inMilliseconds / 1000);
      _autoPause(t);
    }
    gps = _foregroundOnly ? GpsStatus.foregroundOnly : GpsStatus.good;
    notifyListeners();
  }

  void _autoPause(double t) {
    final v = _speedKmh;
    if (v == null) return;
    if (phase == RunPhase.running) {
      if (v < GpsRules.autoPauseKmh) {
        _stillSince ??= t;
        if (t - _stillSince! >= GpsRules.autoPauseAfter.inSeconds) phase = RunPhase.autoPaused;
      } else {
        _stillSince = null;
      }
    } else if (phase == RunPhase.autoPaused && v >= GpsRules.autoPauseKmh * 2) {
      phase = RunPhase.running;
      _stillSince = null;
    }
  }

  // ---------- accelerometer ----------

  void _startAccelerometer() {
    if (kIsWeb) return;
    try {
      _accSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
        if (phase != RunPhase.running) return;
        _footfall.add(e.x, e.y, e.z, _clock.elapsed.inMilliseconds / 1000);
      }, onError: (_) {});
    } catch (_) {}
  }

  // ---------- geocoding ----------

  Future<String?> _reverseGeocodeState() async {
    final c = _track.centroid();
    if (c == null || kIsWeb) return null;
    try {
      final marks = await placemarkFromCoordinates(c.lat, c.lon).timeout(const Duration(seconds: 8));
      for (final m in marks) {
        final code = indiaStateCode(m.administrativeArea, isoCountryCode: m.isoCountryCode);
        if (code != null) return code;
      }
    } catch (_) {}
    return null;
  }
}
