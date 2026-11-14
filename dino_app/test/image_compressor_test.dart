import 'dart:typed_data';

import 'package:dino_app/data/services/image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageCompressor.mimeTypeFor', () {
    test('recognizes HEIC and HEIF container brands', () {
      Uint8List fileTypeHeader(String brand) => Uint8List.fromList([
        0, 0, 0, 24, // ftyp box size
        0x66, 0x74, 0x79, 0x70, // ftyp
        ...brand.codeUnits,
        0, 0, 0, 0, // minor version
      ]);

      expect(ImageCompressor.mimeTypeFor(fileTypeHeader('heic')), 'image/heic');
      expect(ImageCompressor.mimeTypeFor(fileTypeHeader('mif1')), 'image/heif');
    });

    test('recognizes JPEG output from image conversion', () {
      expect(
        ImageCompressor.mimeTypeFor(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
        ),
        'image/jpeg',
      );
    });
  });
}
