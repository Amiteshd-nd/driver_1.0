import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Shared device-tilt signal (-1..1 on both axes) used by the foil shader and the
/// 3-D card tilt. Starts the accelerometer only while something listens, and
/// quietly stays at zero on web or when no sensor is available.
class TiltSource extends ChangeNotifier {
  TiltSource._();
  static final TiltSource instance = TiltSource._();

  double _x = 0, _y = 0;
  bool _available = false;
  int _listeners = 0;
  StreamSubscription<AccelerometerEvent>? _sub;
  double? _fastX, _fastY, _slowY;

  /// Roll, -1..1 (positive = right edge down).
  double get x => _x;

  /// Pitch relative to the resting pose, -1..1.
  double get y => _y;

  /// True once at least one sensor sample has arrived.
  bool get available => _available;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners = math.max(0, _listeners - 1);
    if (_listeners == 0) _stop();
  }

  void _start() {
    if (_sub != null) return;
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
        _onEvent,
        onError: (Object _) => _stop(),
        cancelOnError: true,
      );
    } catch (_) {
      _sub = null;
      _available = false;
    }
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _fastX = _fastY = _slowY = null;
    if (_x != 0 || _y != 0) {
      _x = 0;
      _y = 0;
      notifyListeners();
    }
  }

  void _onEvent(AccelerometerEvent e) {
    const fast = 0.25, slow = 0.015;
    _fastX = _fastX == null ? e.x : _fastX! + (e.x - _fastX!) * fast;
    _fastY = _fastY == null ? e.y : _fastY! + (e.y - _fastY!) * fast;
    _slowY = _slowY == null ? e.y : _slowY! + (e.y - _slowY!) * slow;
    final nx = (_fastX! / 4.0).clamp(-1.0, 1.0);
    final ny = ((_fastY! - _slowY!) / 3.0).clamp(-1.0, 1.0);
    _available = true;
    if ((nx - _x).abs() > 0.004 || (ny - _y).abs() > 0.004) {
      _x = nx;
      _y = ny;
      notifyListeners();
    }
  }
}
