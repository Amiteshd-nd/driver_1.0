/// Footfall features from the user-accelerometer (gravity removed), computed in
/// 10 s windows. Only two numbers leave the device: `rhythm_ratio` and `vertical_rms`.
/// Raw samples live in a short buffer and are discarded as each window closes.
library;

import 'dart:math' as math;

class FootfallRules {
  FootfallRules._();
  static const Duration window = Duration(seconds: 10);
  static const double bandLowHz = 2.2;
  static const double bandHighHz = 3.4;
  static const double scanLowHz = 1.0;
  static const double scanHighHz = 4.5;
  static const double scanStepHz = 0.1;
  static const int minSamplesPerWindow = 60;
}

class FootfallFeatures {
  const FootfallFeatures({required this.rhythmRatio, required this.verticalRms, required this.windows});
  final double rhythmRatio;
  final double verticalRms;
  final int windows;

  Map<String, dynamic> toJson() => {
        'rhythm_ratio': double.parse(rhythmRatio.toStringAsFixed(3)),
        'vertical_rms': double.parse(verticalRms.toStringAsFixed(3)),
      };
}

class FootfallAnalyzer {
  final List<double> _mag = [];
  final List<double> _t = [];
  double? _windowStart;

  int _windows = 0;
  int _rhythmicWindows = 0;
  double _rmsSum = 0;

  /// Feed one user-acceleration sample (m/s²). `tSeconds` is a monotonic clock in seconds.
  void add(double x, double y, double z, double tSeconds) {
    _windowStart ??= tSeconds;
    _mag.add(math.sqrt(x * x + y * y + z * z));
    _t.add(tSeconds);
    if (tSeconds - _windowStart! >= FootfallRules.window.inSeconds) _closeWindow();
  }

  void _closeWindow() {
    final n = _mag.length;
    if (n >= FootfallRules.minSamplesPerWindow) {
      final duration = _t.last - _t.first;
      if (duration > 1) {
        final fs = (n - 1) / duration;
        var mean = 0.0;
        for (final v in _mag) {
          mean += v;
        }
        mean /= n;
        var sq = 0.0;
        for (final v in _mag) {
          sq += (v - mean) * (v - mean);
        }
        final rms = math.sqrt(sq / n);
        final dom = _dominantHz(mean, fs);
        _windows++;
        _rmsSum += rms;
        if (dom >= FootfallRules.bandLowHz && dom <= FootfallRules.bandHighHz) _rhythmicWindows++;
      }
    }
    _mag.clear();
    _t.clear();
    _windowStart = null;
  }

  /// Tiny DFT (Goertzel per bin) over 1.0–4.5 Hz on the mean-removed magnitude; returns the peak frequency.
  double _dominantHz(double mean, double fs) {
    final n = _mag.length;
    var bestHz = 0.0, bestPow = -1.0;
    for (var f = FootfallRules.scanLowHz; f <= FootfallRules.scanHighHz + 1e-9; f += FootfallRules.scanStepHz) {
      final w = 2 * math.pi * f / fs;
      final coeff = 2 * math.cos(w);
      var s0 = 0.0, s1 = 0.0, s2 = 0.0;
      for (var i = 0; i < n; i++) {
        s0 = (_mag[i] - mean) + coeff * s1 - s2;
        s2 = s1;
        s1 = s0;
      }
      final power = s1 * s1 + s2 * s2 - coeff * s1 * s2;
      if (power > bestPow) {
        bestPow = power;
        bestHz = f;
      }
    }
    return bestHz;
  }

  /// Flush the open window and return features, or null when no usable window was seen.
  FootfallFeatures? finish() {
    if (_mag.isNotEmpty) _closeWindow();
    if (_windows == 0) return null;
    return FootfallFeatures(rhythmRatio: _rhythmicWindows / _windows, verticalRms: _rmsSum / _windows, windows: _windows);
  }

  /// Live read without closing the window (for debugging / UI).
  int get windowsSoFar => _windows;
}
