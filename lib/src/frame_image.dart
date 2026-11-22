// Frame rendering, compositing, edge fading, and RGBA -> ui.Image decoding.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pixelfx_core/pixelfx_core.dart';

/// Matches upstream full-screen classification (16:9 and >= 320 px wide).
bool isScreenMeta(AssetMeta meta) =>
    meta.width >= 320 && ((meta.width / meta.height) - 16.0 / 9.0).abs() < 0.05;

/// Decode tightly packed RGBA8888 bytes into a Flutter [ui.Image].
Future<ui.Image> rgbaToUiImage(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// Shared asset render pass (back layer -> optional actor -> front layer -> postFX -> edgeFade).
void renderAssetFrameInto(
  PixelFrame frame,
  PixelAsset asset,
  AssetInstance instance, {
  bool showActor = true,
  bool flip = false,
  bool applyEdgeFade = false,
  List<PostProcessor> postProcessors = const [],
}) {
  clearFrame(frame);
  final meta = asset.meta;
  final hasActor = meta.hasActor &&
      showActor &&
      instance is EffectInstance &&
      instance.options['actor'] is ActorDefinition;

  if (!hasActor) {
    instance.draw(frame, DrawLayer.both);
  } else {
    final fxInst = instance;
    final actorDef = fxInst.options['actor'] as ActorDefinition;
    final fx = asset as PixelEffect;
    final tt = meta.loop
        ? (fxInst.t % meta.duration)
        : (fxInst.t < meta.duration ? fxInst.t : meta.duration);
    fxInst.draw(frame, DrawLayer.back);
    drawActor(
      painterFor(frame).place(
        meta.originX.toDouble(),
        meta.originY.toDouble(),
        flip: flip,
      ),
      actorDef,
      actorAlphaOf(fx, tt, fxInst.options),
    );
    fxInst.draw(frame, DrawLayer.front);
  }

  for (final pp in postProcessors) {
    pp.apply(frame, instance.t, instance.options);
  }
  if (applyEdgeFade) {
    edgeFade(frame);
  }
}

/// Composite a [PixelFrame] into RGBA bytes (reusing [outBuffer] if sized right)
/// and decode it into a GPU [ui.Image].
Future<ui.Image> compositeFrameToImage(
  PixelFrame frame, {
  Uint32List? bgBuffer,
  int? bgColor,
  double lightK = 1.0,
  Uint8List? outBuffer,
}) {
  final need = frame.w * frame.h * 4;
  final rgba =
      (outBuffer != null && outBuffer.length == need) ? outBuffer : Uint8List(need);
  composite(frame, rgba, bgBuffer: bgBuffer, bgColor: bgColor, lightK: lightK);
  return rgbaToUiImage(rgba, frame.w, frame.h);
}

/// Draw [image] onto [canvas] into [dstRect] with strict nearest-neighbor filtering.
void drawCrispImage(
  ui.Canvas canvas,
  ui.Image image,
  ui.Rect dstRect, {
  ui.Rect? srcRect,
}) {
  final src = srcRect ??
      ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
  final paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..isAntiAlias = false;
  canvas.drawImageRect(image, src, dstRect, paint);
}
