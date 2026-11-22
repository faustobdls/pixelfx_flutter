// In-memory frame & packed GPU sprite-sheet atlas baker for Flutter runtime use.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'color_interop.dart';
import 'frame_image.dart';

/// Packed GPU texture atlas containing every frame of a baked [PixelAsset].
class PixelFxSheetAtlas {
  final ui.Image image;
  final int frameWidth;
  final int frameHeight;
  final int columns;
  final int rows;
  final int frameCount;
  final int fps;
  final bool loop;
  final (int ox, int oy) origin;

  const PixelFxSheetAtlas({
    required this.image,
    required this.frameWidth,
    required this.frameHeight,
    required this.columns,
    required this.rows,
    required this.frameCount,
    required this.fps,
    required this.loop,
    required this.origin,
  });

  /// Source rectangle in atlas pixels for frame [index].
  ui.Rect frameRect(int index) {
    final i = index.clamp(0, math.max(0, frameCount - 1));
    final col = i % columns;
    final row = i ~/ columns;
    return ui.Rect.fromLTWH(
      (col * frameWidth).toDouble(),
      (row * frameHeight).toDouble(),
      frameWidth.toDouble(),
      frameHeight.toDouble(),
    );
  }

  /// Release the backing GPU [ui.Image].
  void dispose() => image.dispose();
}

/// Pre-bakes programmatic [PixelAsset] sequences into GPU [ui.Image] frames or atlases.
class PixelFxBaker {
  const PixelFxBaker._();

  /// Bake each frame of [asset] into an individual [ui.Image].
  static Future<List<ui.Image>> bakeFrames(
    PixelAsset asset, {
    BackdropKind bg = BackdropKind.none,
    int? fps,
    int? seed,
    bool showActor = true,
    Map<String, Object?> options = const {},
    List<PostProcessor> postProcessors = const [],
  }) async {
    final m = asset.meta;
    final w = m.width;
    final h = m.height;
    final useFps = fps ?? m.fps;
    final n = math.max(1, (m.duration * useFps).round() + (m.loop ? 0 : 1));
    final frame = createFrame(w, h);
    final bgBuf = backdrop(bg, w, h, m.originY);
    final normOpts = normalizeFlutterOptions(options);
    final flip = (normOpts['flip'] as bool?) ?? false;
    final lightK = (normOpts['light'] as num?)?.toDouble() ?? 1.0;
    final applyEdge = !isScreenMeta(m);
    final inst = asset.createInstance({
      'x': m.originX,
      'y': m.originY,
      'seed': ?seed,
      ...normOpts,
    });

    final rgba = Uint8List(w * h * 4);
    final images = <ui.Image>[];
    for (var i = 0; i < n; i++) {
      if (i > 0) inst.update(1.0 / useFps);
      renderAssetFrameInto(
        frame,
        asset,
        inst,
        showActor: showActor,
        flip: flip,
        applyEdgeFade: applyEdge,
        postProcessors: postProcessors,
      );
      composite(frame, rgba, bgBuffer: bgBuf, lightK: lightK);
      images.add(await rgbaToUiImage(rgba, w, h));
    }
    return images;
  }

  /// Pack every frame of [asset] into a single [PixelFxSheetAtlas] GPU texture.
  static Future<PixelFxSheetAtlas> bakeAtlas(
    PixelAsset asset, {
    BackdropKind bg = BackdropKind.none,
    int? fps,
    int? seed,
    bool showActor = false,
    Map<String, Object?> options = const {},
    List<PostProcessor> postProcessors = const [],
  }) async {
    final m = asset.meta;
    final w = m.width;
    final h = m.height;
    final useFps = fps ?? m.fps;
    final n = math.max(1, (m.duration * useFps).round() + (m.loop ? 0 : 1));
    final cols = math.min(n, math.max(1, math.sqrt((n * h) / w).ceil()));
    final rows = (n / cols).ceil();
    final sheetW = cols * w;
    final sheetH = rows * h;

    final atlasRgba = Uint8List(sheetW * sheetH * 4);
    final frameRgba = Uint8List(w * h * 4);
    final frame = createFrame(w, h);
    final bgBuf = backdrop(bg, w, h, m.originY);
    final normOpts = normalizeFlutterOptions(options);
    final flip = (normOpts['flip'] as bool?) ?? false;
    final lightK = (normOpts['light'] as num?)?.toDouble() ?? 1.0;
    final applyEdge = !isScreenMeta(m);
    final inst = asset.createInstance({
      'x': m.originX,
      'y': m.originY,
      'seed': ?seed,
      ...normOpts,
    });

    for (var i = 0; i < n; i++) {
      if (i > 0) inst.update(1.0 / useFps);
      renderAssetFrameInto(
        frame,
        asset,
        inst,
        showActor: showActor,
        flip: flip,
        applyEdgeFade: applyEdge,
        postProcessors: postProcessors,
      );
      composite(frame, frameRgba, bgBuffer: bgBuf, lightK: lightK);
      final gx = (i % cols) * w;
      final gy = (i ~/ cols) * h;
      for (var y = 0; y < h; y++) {
        final srcStart = y * w * 4;
        final dstStart = ((gy + y) * sheetW + gx) * 4;
        atlasRgba.setRange(dstStart, dstStart + w * 4, frameRgba, srcStart);
      }
    }

    final img = await rgbaToUiImage(atlasRgba, sheetW, sheetH);
    return PixelFxSheetAtlas(
      image: img,
      frameWidth: w,
      frameHeight: h,
      columns: cols,
      rows: rows,
      frameCount: n,
      fps: useFps,
      loop: m.loop,
      origin: m.origin,
    );
  }
}
