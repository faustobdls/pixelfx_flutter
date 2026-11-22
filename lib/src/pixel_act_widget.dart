// Flutter widget that performs an acted effect (3D rig actor, target dummy, hit-stop, camera shake).

import 'package:flutter/widgets.dart';
import 'package:pixelfx_core/pixelfx_core.dart';

import 'controller.dart';
import 'pixel_asset_widget.dart';

/// Displays an acted [PixelEffect] complete with animated hero rig,
/// windup/follow-through poses, hit-stop freeze frames, camera shake,
/// target dummy knockback/skin effects, and optional skeleton debug overlay.
class PixelActView extends StatelessWidget {
  final PixelEffect effect;
  final PixelFxController? controller;
  final List<Object>? palette;
  final int? seed;
  final BackdropKind? backdrop;
  final bool flip;
  final bool playing;
  final bool? loop;
  final double speed;
  final bool showActor;
  final bool showTarget;
  final bool showSkeleton;
  final double light;
  final double? scale;
  final BoxFit fit;
  final Map<String, Object?> options;
  final List<PostProcessor> postProcessors;
  final void Function(HitSpec hit)? onHit;

  const PixelActView({
    super.key,
    required this.effect,
    this.controller,
    this.palette,
    this.seed,
    this.backdrop,
    this.flip = false,
    this.playing = true,
    this.loop,
    this.speed = 1.0,
    this.showActor = true,
    this.showTarget = true,
    this.showSkeleton = false,
    this.light = 1.0,
    this.scale,
    this.fit = BoxFit.contain,
    this.options = const {},
    this.postProcessors = const [],
    this.onHit,
  });

  @override
  Widget build(BuildContext context) {
    final mergedOpts = palette == null
        ? options
        : <String, Object?>{...options, 'palette': palette};

    return PixelAssetView(
      asset: effect,
      controller: controller,
      actMode: true,
      playing: playing,
      loop: loop,
      speed: speed,
      backdrop: backdrop,
      showActor: showActor,
      showTarget: showTarget,
      flip: flip,
      showSkeleton: showSkeleton,
      seed: seed,
      light: light,
      options: mergedOpts,
      postProcessors: postProcessors,
      onHit: onHit,
      scale: scale,
      fit: fit,
    );
  }
}
