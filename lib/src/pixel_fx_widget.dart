// Ergonomic Flutter widget for playing any PixelEffect or PixelAsset.

import 'package:flutter/widgets.dart';
import 'package:pixelfx_core/pixelfx_core.dart';

import 'controller.dart';
import 'pixel_asset_widget.dart';

/// Declarative widget for rendering any [PixelEffect] or [PixelAsset]
/// with crisp pixel-art scaling, optional custom palette, and backdrop control.
class PixelFxView extends StatelessWidget {
  final PixelAsset asset;
  final PixelFxController? controller;
  final List<Object>? palette;
  final int? seed;
  final BackdropKind? backdrop;
  final bool flip;
  final bool playing;
  final bool? loop;
  final double speed;
  final bool showActor;
  final bool showSkeleton;
  final double light;
  final double? scale;
  final BoxFit fit;
  final Map<String, Object?> options;
  final List<PostProcessor> postProcessors;

  const PixelFxView({
    super.key,
    required this.asset,
    this.controller,
    this.palette,
    this.seed,
    this.backdrop,
    this.flip = false,
    this.playing = true,
    this.loop,
    this.speed = 1.0,
    this.showActor = true,
    this.showSkeleton = false,
    this.light = 1.0,
    this.scale,
    this.fit = BoxFit.contain,
    this.options = const {},
    this.postProcessors = const [],
  });

  @override
  Widget build(BuildContext context) {
    final mergedOpts = palette == null
        ? options
        : <String, Object?>{...options, 'palette': palette};

    return PixelAssetView(
      asset: asset,
      controller: controller,
      actMode: false,
      playing: playing,
      loop: loop,
      speed: speed,
      backdrop: backdrop,
      showActor: showActor,
      flip: flip,
      showSkeleton: showSkeleton,
      seed: seed,
      light: light,
      options: mergedOpts,
      postProcessors: postProcessors,
      scale: scale,
      fit: fit,
    );
  }
}
