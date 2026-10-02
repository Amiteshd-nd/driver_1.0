import 'dart:typed_data';

/// A file chosen by the admin for upload (name + bytes).
class PickedBytes {
  const PickedBytes(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
