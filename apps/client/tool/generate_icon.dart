import 'dart:io';

import 'package:image/image.dart' as img;

/// Generates the app launcher icon (512x512) matching the web gradient logo.
void main() {
  const size = 512;
  final image = img.Image(width: size, height: size);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (size * 2);
      final r = (0x6C * (1 - t) + 0x00 * t).round();
      final g = (0x5C * (1 - t) + 0xD2 * t).round();
      final b = (0xE7 * (1 - t) + 0xA0 * t).round();
      image.setPixelRgb(x, y, r, g, b);
    }
  }

  final radius = 96;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x < radius ? radius - x : (x > size - radius ? x - (size - radius) : 0);
      final dy = y < radius ? radius - y : (y > size - radius ? y - (size - radius) : 0);
      if (dx * dx + dy * dy > radius * radius) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }

  _drawArrow(image, size);

  final out = File('assets/app_icon.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote ${out.path}');
}

void _drawArrow(img.Image image, int size) {
  final white = img.ColorRgb8(255, 255, 255);
  final cx = size ~/ 2;
  final top = (size * 0.28).round();
  final bottom = (size * 0.72).round();
  final wing = (size * 0.12).round();

  for (var y = top; y <= bottom; y++) {
    _setThick(image, cx, y, white, 6);
  }
  for (var i = 0; i <= wing; i++) {
    _setThick(image, cx - i, bottom - i, white, 5);
    _setThick(image, cx + i, bottom - i, white, 5);
  }
  for (var x = cx - (size * 0.22).round(); x <= cx + (size * 0.22).round(); x++) {
    _setThick(image, x, (size * 0.76).round(), white, 5);
  }
}

void _setThick(img.Image image, int x, int y, img.Color color, int thickness) {
  for (var dy = -thickness; dy <= thickness; dy++) {
    for (var dx = -thickness; dx <= thickness; dx++) {
      if (x + dx >= 0 &&
          y + dy >= 0 &&
          x + dx < image.width &&
          y + dy < image.height) {
        image.setPixel(x + dx, y + dy, color);
      }
    }
  }
}
