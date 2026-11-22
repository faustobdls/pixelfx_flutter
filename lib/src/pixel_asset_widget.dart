// Generic animated widget driving any PixelAsset via TickerProviderStateMixin.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:pixelfx_core/pixelfx_core.dart';

import 'controller.dart';
import 'painter_widget.dart';

/// Displays any programmatic [PixelAsset] (effects, acts, critters, props, UI badges)
/// at crisp nearest-neighbor scaling using Flutter's [Ticker].
class PixelAssetView extends StatefulWidget {
  final PixelAsset asset;
  final PixelFxController? controller;
  final bool actMode;
  final bool playing;
  final bool? loop;
  final double speed;
  final BackdropKind? backdrop;
  final bool showActor;
  final bool showTarget;
  final bool flip;
  final bool showSkeleton;
  final int? seed;
  final double light;
  final Map<String, Object?> options;
  final List<PostProcessor> postProcessors;
  final void Function(HitSpec hit)? onHit;
  final double? scale;
  final BoxFit fit;

  const PixelAssetView({
    super.key,
    required this.asset,
    this.controller,
    this.actMode = false,
    this.playing = true,
    this.loop,
    this.speed = 1.0,
    this.backdrop,
    this.showActor = true,
    this.showTarget = true,
    this.flip = false,
    this.showSkeleton = false,
    this.seed,
    this.light = 1.0,
    this.options = const {},
    this.postProcessors = const [],
    this.onHit,
    this.scale,
    this.fit = BoxFit.contain,
  });

  @override
  State<PixelAssetView> createState() => _PixelAssetViewState();
}

class _PixelAssetViewState extends State<PixelAssetView>
    with SingleTickerProviderStateMixin {
  PixelFxController? _ownedController;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  PixelFxController get _effectiveController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = _createOwnedController();
    }
    _effectiveController.addListener(_onControllerChanged);
    _ticker = createTicker(_onTick)..start();
  }

  PixelFxController _createOwnedController() => PixelFxController(
        asset: widget.asset,
        actMode: widget.actMode,
        playing: widget.playing,
        loop: widget.loop,
        speed: widget.speed,
        backdropKind: widget.backdrop,
        showActor: widget.showActor,
        showTarget: widget.showTarget,
        flip: widget.flip,
        showSkeleton: widget.showSkeleton,
        seed: widget.seed,
        lightK: widget.light,
        options: widget.options,
        postProcessors: widget.postProcessors,
        onHit: widget.onHit,
      );

  @override
  void didUpdateWidget(covariant PixelAssetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)
          ?.removeListener(_onControllerChanged);
      if (widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      } else {
        _ownedController ??= _createOwnedController();
      }
      _effectiveController.addListener(_onControllerChanged);
    }

    if (widget.controller == null && _ownedController != null) {
      _ownedController!.updateConfig(
        asset: widget.asset,
        actMode: widget.actMode,
        playing: widget.playing,
        loop: widget.loop ?? widget.asset.meta.loop,
        speed: widget.speed,
        backdropKind: widget.backdrop ?? widget.asset.meta.bg,
        showActor: widget.showActor,
        showTarget: widget.showTarget,
        flip: widget.flip,
        showSkeleton: widget.showSkeleton,
        seed: widget.seed,
        clearSeed: widget.seed == null,
        lightK: widget.light,
        options: widget.options,
        postProcessors: widget.postProcessors,
        onHit: widget.onHit,
      );
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt > 0.0 && widget.controller == null) {
      _ownedController?.step(dt > 0.1 ? 0.1 : dt);
    } else if (dt > 0.0 && widget.controller != null) {
      widget.controller!.step(dt > 0.1 ? 0.1 : dt);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _effectiveController.removeListener(_onControllerChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _effectiveController;
    final painter = CustomPaint(
      painter: PixelFxPainter(
        image: ctrl.image,
        frameWidth: ctrl.frameWidth,
        frameHeight: ctrl.frameHeight,
        pivot: ctrl.pivot,
        shake: ctrl.shake,
        fit: widget.fit,
        skeleton: ctrl.currentSkeleton,
        pose: ctrl.currentPose,
        flip: ctrl.flip,
      ),
      child: widget.scale != null
          ? SizedBox(
              width: ctrl.frameWidth * widget.scale!,
              height: ctrl.frameHeight * widget.scale!,
            )
          : const SizedBox.expand(),
    );

    if (widget.scale != null) {
      return SizedBox(
        width: ctrl.frameWidth * widget.scale!,
        height: ctrl.frameHeight * widget.scale!,
        child: painter,
      );
    }
    return painter;
  }
}
