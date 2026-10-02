/// Platform-conditional file picker: `dart:html` on web, a stub elsewhere.
/// Exposes `pickBytes({accept})`, `pickBytesSupported` and `PickedBytes`.
library;

export 'pick_bytes_stub.dart' if (dart.library.html) 'pick_bytes_web.dart';
export 'pick_bytes_types.dart';
