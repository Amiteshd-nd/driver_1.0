// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'pick_bytes_types.dart';

const bool pickBytesSupported = true;

/// Opens the browser file dialog and resolves with the chosen file's bytes (null if nothing readable).
Future<PickedBytes?> pickBytes({String accept = 'image/png'}) async {
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = false;
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final file = files.first;
  final reader = html.FileReader();
  final done = reader.onLoadEnd.first;
  reader.readAsArrayBuffer(file);
  await done;
  final result = reader.result;
  if (result is Uint8List) return PickedBytes(file.name, result);
  if (result is ByteBuffer) return PickedBytes(file.name, result.asUint8List());
  return null;
}
