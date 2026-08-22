import 'dart:typed_data';

/// User-captured or gallery-picked image passed from Identify → ID Result.
class CapturedSpecimen {
  const CapturedSpecimen({
    required this.bytes,
    this.path,
  });

  final Uint8List bytes;
  final String? path;
}
