import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Shrinks images before vision API calls to reduce upload tokens and latency.
class ImageCompressor {
  const ImageCompressor({
    this.maxSide = 768,
    this.jpegQuality = 72,
  });

  final int maxSide;
  final int jpegQuality;

  Uint8List forVision(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longest <= maxSide) {
      return Uint8List.fromList(img.encodeJpg(decoded, quality: jpegQuality));
    }

    final scale = maxSide / longest;
    final resized = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
  }
}
