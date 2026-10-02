/// One place that knows how each data *purpose* maps to an OS permission.
/// Used by onboarding (request) and the trust centre (status + toggle).
/// Every call is wrapped so a missing plugin (web) degrades to "not available".
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// A purpose as the player sees it. `connectedKeys` are the `profiles.connected` values it grants.
enum Purpose {
  location(
    title: 'Location while running',
    why: 'to measure distance and notice when you explore somewhere new',
    store: 'your route, visible to you alone',
    lose: 'Without it, runs are timed but not measured, and explorer animals stay hidden.',
    connectedKeys: ['location', 'elevation'],
  ),
  motion(
    title: 'Motion & fitness',
    why: 'to count steps and feel the rhythm of your footfall',
    store: 'step counts and two rhythm numbers per run — never raw sensor data',
    lose: 'Without it, we have less evidence that a run was a run, so more cards draw from the everyday bag.',
    connectedKeys: ['motion', 'steps'],
  ),
  activity(
    title: 'Activity recognition',
    why: 'to tell running from walking, cycling or a bus ride',
    store: 'time fractions per activity type for each run',
    lose: 'Without it, we rely on GPS and steps alone to confirm a run.',
    connectedKeys: ['activity'],
  ),
  heartRate(
    title: 'Health · heart rate',
    why: 'to read effort from your watch and confirm a run with confidence',
    store: 'average and peak heart rate per run',
    lose: 'Without it, heart-rate evidence is skipped. Everything else still works.',
    connectedKeys: ['heart_rate'],
  ),
  notifications(
    title: 'Notifications',
    why: 'to tell you when a weekly or monthly card is waiting',
    store: 'nothing extra — a device token on your phone',
    lose: 'Without it, new cards wait quietly on Today until you open the app.',
    connectedKeys: [],
  );

  const Purpose({required this.title, required this.why, required this.store, required this.lose, required this.connectedKeys});
  final String title, why, store, lose;
  final List<String> connectedKeys;
}

/// Live OS state for a purpose.
enum PurposeStatus { granted, limited, denied, permanentlyDenied, unavailable, unknown }

class PermissionCenter {
  PermissionCenter._();

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Request the OS permission behind a purpose. Returns true when the purpose is usable.
  static Future<bool> request(Purpose p) async {
    try {
      switch (p) {
        case Purpose.location:
          if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) return false;
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
          return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
        case Purpose.motion:
          if (kIsWeb) return false;
          final perm = _isAndroid ? Permission.activityRecognition : Permission.sensors;
          final s = await perm.request();
          return s.isGranted || s.isLimited;
        case Purpose.activity:
          if (kIsWeb) return false;
          final ar = FlutterActivityRecognition.instance;
          var s = await ar.checkPermission();
          if (s == ActivityPermission.DENIED) s = await ar.requestPermission();
          return s == ActivityPermission.GRANTED;
        case Purpose.heartRate:
          if (kIsWeb) return false;
          final h = Health();
          await h.configure();
          return await h.requestAuthorization(
            const [HealthDataType.HEART_RATE, HealthDataType.WORKOUT, HealthDataType.STEPS],
            permissions: const [HealthDataAccess.READ, HealthDataAccess.READ, HealthDataAccess.READ],
          );
        case Purpose.notifications:
          if (kIsWeb) return false;
          final s = await Permission.notification.request();
          return s.isGranted || s.isLimited || s.isProvisional;
      }
    } catch (_) {
      return false;
    }
  }

  /// Ask for background ("always") location so a run keeps recording with the screen off.
  static Future<bool> requestBackgroundLocation() async {
    if (kIsWeb) return false;
    try {
      final s = await Permission.locationAlways.request();
      return s.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Current OS status without prompting.
  static Future<PurposeStatus> status(Purpose p) async {
    try {
      switch (p) {
        case Purpose.location:
          final perm = await Geolocator.checkPermission();
          return switch (perm) {
            LocationPermission.always => PurposeStatus.granted,
            LocationPermission.whileInUse => PurposeStatus.limited,
            LocationPermission.denied => PurposeStatus.denied,
            LocationPermission.deniedForever => PurposeStatus.permanentlyDenied,
            LocationPermission.unableToDetermine => PurposeStatus.unknown,
          };
        case Purpose.motion:
          if (kIsWeb) return PurposeStatus.unavailable;
          final perm = _isAndroid ? Permission.activityRecognition : Permission.sensors;
          return _fromHandler(await perm.status);
        case Purpose.activity:
          if (kIsWeb) return PurposeStatus.unavailable;
          final s = await FlutterActivityRecognition.instance.checkPermission();
          if (s == ActivityPermission.GRANTED) return PurposeStatus.granted;
          if (s == ActivityPermission.PERMANENTLY_DENIED) return PurposeStatus.permanentlyDenied;
          return PurposeStatus.denied;
        case Purpose.heartRate:
          if (kIsWeb) return PurposeStatus.unavailable;
          // iOS hides read-permission state by design; `null` means "we cannot tell".
          final has = await Health().hasPermissions(const [HealthDataType.HEART_RATE]);
          if (has == null) return _isIOS ? PurposeStatus.unknown : PurposeStatus.denied;
          return has ? PurposeStatus.granted : PurposeStatus.denied;
        case Purpose.notifications:
          if (kIsWeb) return PurposeStatus.unavailable;
          return _fromHandler(await Permission.notification.status);
      }
    } catch (_) {
      return PurposeStatus.unavailable;
    }
  }

  static PurposeStatus _fromHandler(PermissionStatus s) {
    if (s.isGranted || s.isProvisional) return PurposeStatus.granted;
    if (s.isLimited) return PurposeStatus.limited;
    if (s.isPermanentlyDenied) return PurposeStatus.permanentlyDenied;
    if (s.isRestricted) return PurposeStatus.unavailable;
    return PurposeStatus.denied;
  }

  /// Opens the system settings page for this app (for permanently denied permissions).
  static Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await openAppSettings();
    } catch (_) {}
  }

  /// Human label for a status, in DESIGN §9 voice.
  static String describe(PurposeStatus s) => switch (s) {
        PurposeStatus.granted => 'On',
        PurposeStatus.limited => 'On while the app is open',
        PurposeStatus.denied => 'Off',
        PurposeStatus.permanentlyDenied => 'Off · turn on in phone settings',
        PurposeStatus.unavailable => 'Not available on this device',
        PurposeStatus.unknown => 'Set on your phone',
      };

  static bool usable(PurposeStatus s) => s == PurposeStatus.granted || s == PurposeStatus.limited;
}
