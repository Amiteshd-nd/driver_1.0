/// Offline queue for `submit_run` payloads. Each payload is one JSON file in the app
/// documents directory (SharedPreferences on web). `flush()` retries on start/resume.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/models.dart';
import '../../core/repos/repos.dart';

/// True for errors worth retrying later (no network, timeout, host unreachable).
bool isNetworkError(Object e) {
  if (e is TimeoutException) return true;
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused') ||
      s.contains('Connection reset') ||
      s.contains('Network is unreachable') ||
      s.contains('XMLHttpRequest error') ||
      s.contains('Connection closed') ||
      s.contains('HandshakeException');
}

class RunQueue with WidgetsBindingObserver {
  RunQueue(this._api) {
    WidgetsBinding.instance.addObserver(this);
  }

  final AppApi _api;
  static const _prefsKey = 'run_queue_web';
  bool _flushing = false;

  /// Results that arrived from a background flush (the UI may show the newest card on Today).
  final List<RunResult> flushedResults = [];
  final StreamController<RunResult> _onFlushed = StreamController<RunResult>.broadcast();
  Stream<RunResult> get onFlushed => _onFlushed.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(flush());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onFlushed.close();
  }

  Future<Directory?> _dir() async {
    if (kIsWeb) return null;
    try {
      final base = await getApplicationDocumentsDirectory();
      final d = Directory('${base.path}/flyingcobra_queue');
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    } catch (_) {
      return null;
    }
  }

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final id = payload['client_run_id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    final json = jsonEncode(payload);
    final dir = await _dir();
    if (dir != null) {
      await File('${dir.path}/$id.json').writeAsString(json, flush: true);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? <String>[];
      list.removeWhere((s) => s.contains('"client_run_id":"$id"'));
      list.add(json);
      await prefs.setStringList(_prefsKey, list);
    } catch (_) {}
  }

  Future<int> pendingCount() async => (await _loadAll()).length;

  Future<List<_Queued>> _loadAll() async {
    final out = <_Queued>[];
    final dir = await _dir();
    if (dir != null) {
      try {
        await for (final f in dir.list()) {
          if (f is File && f.path.endsWith('.json')) {
            try {
              final m = (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
              out.add(_Queued(m, file: f));
            } catch (_) {
              await f.delete();
            }
          }
        }
      } catch (_) {}
      return out;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final s in prefs.getStringList(_prefsKey) ?? const <String>[]) {
        try {
          out.add(_Queued((jsonDecode(s) as Map).cast<String, dynamic>(), raw: s));
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  Future<void> _remove(_Queued q) async {
    if (q.file != null) {
      try {
        await q.file!.delete();
      } catch (_) {}
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? <String>[];
      list.remove(q.raw);
      await prefs.setStringList(_prefsKey, list);
    } catch (_) {}
  }

  /// Submits every queued payload. Removes on success or `duplicate: true`; keeps on network error.
  /// Returns the results that produced a card or a verdict (not duplicates).
  Future<List<RunResult>> flush() async {
    if (_flushing || _api.uid == null) return const [];
    _flushing = true;
    final delivered = <RunResult>[];
    try {
      final items = await _loadAll();
      items.sort((a, b) => (a.payload['started_at'] ?? '').toString().compareTo((b.payload['started_at'] ?? '').toString()));
      for (final q in items) {
        try {
          final r = await _api.submitRun(q.payload).timeout(const Duration(seconds: 30));
          await _remove(q);
          if (!r.duplicate) {
            delivered.add(r);
            flushedResults.add(r);
            if (!_onFlushed.isClosed) _onFlushed.add(r);
          }
        } catch (e) {
          if (isNetworkError(e)) break; // still offline; try again on next resume
          // A server-side refusal will not fix itself: drop it so the queue never wedges.
          await _remove(q);
        }
      }
    } finally {
      _flushing = false;
    }
    return delivered;
  }
}

class _Queued {
  _Queued(this.payload, {this.file, this.raw});
  final Map<String, dynamic> payload;
  final File? file;
  final String? raw;
}

/// Reading this provider once (e.g. on Today or Run) starts the lifecycle observer and flushes.
final runQueueProvider = Provider<RunQueue>((ref) {
  final q = RunQueue(ref.watch(apiProvider));
  ref.onDispose(q.dispose);
  unawaited(q.flush());
  return q;
});
