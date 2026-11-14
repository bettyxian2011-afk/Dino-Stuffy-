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

  /// MIME type for the bytes returned by [forVision]. Most decodable images
  /// are re-encoded as JPEG; HEIC/HEIF pass through when the Dart decoder does
  /// not support them and must keep their original MIME type for Gemini.
  static String mimeTypeFor(Uint8List bytes) {
    if (_hasPrefix(bytes, const [0xff, 0xd8, 0xff])) return 'image/jpeg';
    if (_hasPrefix(bytes, const [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ])) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        _hasAscii(bytes, 0, 'RIFF') &&
        _hasAscii(bytes, 8, 'WEBP')) {
      return 'image/webp';
    }

    // HEIF-family files are ISO Base Media containers with a `ftyp` box.
    if (bytes.length >= 12 && _hasAscii(bytes, 4, 'ftyp')) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (const {
        'heic',
        'heix',
        'hevc',
        'hevx',
        'heim',
        'heis',
      }.contains(brand)) {
        return 'image/heic';
      }
      if (const {'mif1', 'msf1'}.contains(brand)) return 'image/heif';
    }

    // The image picker normally supplies JPEGs; keep legacy behavior for
    // unknown byte fixtures while correctly identifying HEIC/HEIF above.
    return 'image/jpeg';
  }

  static bool _hasPrefix(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static bool _hasAscii(Uint8List bytes, int offset, String value) {
    if (bytes.length < offset + value.length) return false;
    for (var i = 0; i < value.length; i++) {
      if (bytes[offset + i] != value.codeUnitAt(i)) return false;
    }
    return true;
  }

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
