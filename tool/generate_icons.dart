// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  final densities = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in densities.entries) {
    final folder = entry.key;
    final size = entry.value;
    final pngBytes = createIconPng(size);
    final file = File('android/app/src/main/res/$folder/ic_launcher.png');
    file.writeAsBytesSync(pngBytes);
    print('Generated $folder/ic_launcher.png ($size x $size)');
  }

  // Also create a 512x512 play store icon
  final playStoreIcon = createIconPng(512);
  File('android/app/src/main/res/playstore-icon.png')
      .writeAsBytesSync(playStoreIcon);
  print('Generated playstore-icon.png (512 x 512)');
}

Uint8List createIconPng(int size) {
  // Rasterize icon onto an RGBA buffer
  final buffer = Uint8List(size * size * 4);
  final center = size / 2.0;
  final radius = size * 0.44; // Squircle / circle radius

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final idx = (y * size + x) * 4;
      final dx = x - center;
      final dy = y - center;
      final dist = math.sqrt(dx * dx + dy * dy);

      // Super-sampled distance for anti-aliasing
      if (dist <= radius) {
        final edgeAlpha = (radius - dist).clamp(0.0, 1.0);

        // Blue gradient (#007AFF -> #0051B3)
        final t = (x + y) / (2.0 * size);
        final r = (0 * (1 - t) + 0 * t).round();
        final g = (122 * (1 - t) + 81 * t).round();
        final b = (255 * (1 - t) + 179 * t).round();

        // Draw Globe Glyph in Center
        final globeRadius = radius * 0.58;
        final inGlobe = dist <= globeRadius;

        bool isWhiteGlyph = false;
        if (inGlobe) {
          // Globe outer circle ring
          final ringDist = (dist - globeRadius).abs();
          if (ringDist < size * 0.035) {
            isWhiteGlyph = true;
          }
          // Horizontal equator line
          if (dy.abs() < size * 0.03) {
            isWhiteGlyph = true;
          }
          // Horizontal latitude arcs
          final latOffset = globeRadius * 0.5;
          if ((dy.abs() - latOffset).abs() < size * 0.025) {
            final maxWidthAtLat = math.sqrt(
              math.max(0.0, globeRadius * globeRadius - dy * dy),
            );
            if (dx.abs() <= maxWidthAtLat) {
              isWhiteGlyph = true;
            }
          }
          // Vertical prime meridian line
          if (dx.abs() < size * 0.03) {
            isWhiteGlyph = true;
          }
          // Vertical ellipse meridian
          final ellipseVal =
              (dx * dx) / (globeRadius * 0.52 * globeRadius * 0.52) +
              (dy * dy) / (globeRadius * globeRadius);
          if ((ellipseVal - 1.0).abs() < 0.18) {
            isWhiteGlyph = true;
          }
        }

        if (isWhiteGlyph) {
          buffer[idx] = 255;
          buffer[idx + 1] = 255;
          buffer[idx + 2] = 255;
          buffer[idx + 3] = (255 * edgeAlpha).round();
        } else {
          buffer[idx] = r;
          buffer[idx + 1] = g;
          buffer[idx + 2] = b;
          buffer[idx + 3] = (255 * edgeAlpha).round();
        }
      } else {
        // Transparent outside
        buffer[idx] = 0;
        buffer[idx + 1] = 0;
        buffer[idx + 2] = 0;
        buffer[idx + 3] = 0;
      }
    }
  }

  return encodePng(size, size, buffer);
}

Uint8List encodePng(int width, int height, Uint8List rgba) {
  // Simple uncompressed PNG encoder using raw deflate blocks
  final signature = [137, 80, 78, 71, 13, 10, 26, 10];

  // IHDR
  final ihdrData = ByteData(13);
  ihdrData.setUint32(0, width);
  ihdrData.setUint32(4, height);
  ihdrData.setUint8(8, 8); // bit depth 8
  ihdrData.setUint8(9, 6); // RGBA
  ihdrData.setUint8(10, 0); // compression
  ihdrData.setUint8(11, 0); // filter
  ihdrData.setUint8(12, 0); // interlace
  final ihdrChunk = makeChunk('IHDR', ihdrData.buffer.asUint8List());

  // IDAT (filter 0: None for each scanline)
  final rawScanlines = BytesBuilder();
  for (int y = 0; y < height; y++) {
    rawScanlines.addByte(0); // filter type 0
    final start = y * width * 4;
    rawScanlines.add(rgba.sublist(start, start + width * 4));
  }
  final uncompressed = rawScanlines.toBytes();
  final compressed = zlibCompress(uncompressed);
  final idatChunk = makeChunk('IDAT', compressed);

  // IEND
  final iendChunk = makeChunk('IEND', Uint8List(0));

  final result = BytesBuilder();
  result.add(signature);
  result.add(ihdrChunk);
  result.add(idatChunk);
  result.add(iendChunk);
  return result.toBytes();
}

Uint8List makeChunk(String type, Uint8List data) {
  final length = data.length;
  final chunk = BytesBuilder();
  final lenBytes = ByteData(4)..setUint32(0, length);
  chunk.add(lenBytes.buffer.asUint8List());

  final typeBytes = Uint8List.fromList(type.codeUnits);
  chunk.add(typeBytes);
  chunk.add(data);

  final crcData = Uint8List.fromList([...typeBytes, ...data]);
  final crc = calculateCrc32(crcData);
  final crcBytes = ByteData(4)..setUint32(0, crc);
  chunk.add(crcBytes.buffer.asUint8List());

  return chunk.toBytes();
}

Uint8List zlibCompress(Uint8List data) {
  return Uint8List.fromList(zlib.encode(data));
}

int calculateCrc32(Uint8List data) {
  int crc = 0xFFFFFFFF;
  for (int byte in data) {
    crc ^= byte;
    for (int j = 0; j < 8; j++) {
      if ((crc & 1) != 0) {
        crc = (crc >>> 1) ^ 0xEDB88320;
      } else {
        crc >>>= 1;
      }
    }
  }
  return (~crc) & 0xFFFFFFFF;
}
