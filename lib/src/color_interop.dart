// Interoperability between Flutter Color (ARGB32) and pixelfx_core packed ABGR ints.

import 'dart:ui' show Color;

import 'package:pixelfx_core/pixelfx_core.dart';

/// Convert a Flutter [Color] (`0xAARRGGBB`) to a packed little-endian
/// `pixelfx_core` RGBA8888 integer (`0xAABBGGRR`).
int colorToAbgr(Color color) {
  final argb = color.toARGB32();
  final a = (argb >>> 24) & 0xff;
  final r = (argb >>> 16) & 0xff;
  final g = (argb >>> 8) & 0xff;
  final b = argb & 0xff;
  return ((a << 24) | (b << 16) | (g << 8) | r) & 0xffffffff;
}

/// Convert a packed little-endian `pixelfx_core` integer (`0xAABBGGRR`)
/// into a Flutter [Color].
Color abgrToColor(int abgr) => Color.fromARGB(
      (abgr >>> 24) & 0xff,
      abgr & 0xff,
      (abgr >>> 8) & 0xff,
      (abgr >>> 16) & 0xff,
    );

/// Convert a Flutter [Color] list into packed ABGR integers for `options['palette']`.
List<int> colorsToPalette(List<Color> colors) => [
      for (final c in colors) colorToAbgr(c),
    ];

/// Convert any `pixelfx_core` ramp (hex strings, ints, or Flutter [Color]s)
/// into Flutter [Color]s.
List<Color> paletteToColors(List<Object> palette) => [
      for (final item in palette)
        if (item is Color) item else abgrToColor(hex(item)),
    ];

/// Normalize option entries so Flutter [Color] palettes seamlessly work in `pixelfx_core`.
Map<String, Object?> normalizeFlutterOptions(Map<String, Object?> options) {
  if (options.isEmpty) return const {};
  final out = Map<String, Object?>.of(options);
  final pal = out['palette'];
  if (pal is List && pal.any((e) => e is Color)) {
    out['palette'] = [
      for (final item in pal)
        if (item is Color) colorToAbgr(item) else item,
    ];
  }
  return out;
}
