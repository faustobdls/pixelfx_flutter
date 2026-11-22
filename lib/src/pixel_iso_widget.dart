// Interactive Flutter widgets for 2.5D isometric VFX, 8-direction pitched rigs, and diamond tiles.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_iso/pixelfx_iso.dart';

import 'frame_image.dart';
import 'painter_widget.dart';

/// Displays any [PixelAsset] in 2.5D isometric space with 8-direction [IsoDir],
/// configurable [IsoPlane] projection, optional 26.565-deg pitched character [actMode],
/// skeleton overlay, and crisp nearest-neighbor scaling.
class PixelIsoView extends StatefulWidget {
  final PixelAsset asset;
  final IsoDir dir;
  final IsoPlane plane;
  final IsoProjection projection;
  final double pitch;
  final bool actMode;
  final bool playing;
  final bool? loop;
  final double speed;
  final BackdropKind? backdrop;
  final bool showActor;
  final bool showTarget;
  final bool showSkeleton;
  final bool flip;
  final int? seed;
  final double light;
  final List<Object>? palette;
  final Map<String, Object?> options;
  final List<PostProcessor> postProcessors;
  final void Function(HitSpec hit)? onHit;
  final double? scale;
  final BoxFit fit;

  const PixelIsoView({
    super.key,
    required this.asset,
    this.dir = IsoDir.se,
    this.plane = IsoPlane.floor,
    this.projection = const IsoProjection.standard(),
    this.pitch = kIsoCameraPitch,
    this.actMode = false,
    this.playing = true,
    this.loop,
    this.speed = 1.0,
    this.backdrop,
    this.showActor = true,
    this.showTarget = true,
    this.showSkeleton = false,
    this.flip = false,
    this.seed,
    this.light = 1.0,
    this.palette,
    this.options = const {},
    this.postProcessors = const [],
    this.onHit,
    this.scale,
    this.fit = BoxFit.contain,
  });

  @override
  State<PixelIsoView> createState() => _PixelIsoViewState();
}

class _PixelIsoViewState extends State<PixelIsoView>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  late PixelIsoFrame _frame;
  late Uint8List _rgba;
  Uint32List? _bgBuffer;
  AssetInstance? _inst;
  int _frameW = 1;
  int _frameH = 1;
  (int ox, int oy) _pivot = const (0, 0);
  double _accum = 0.0;
  double _elapsed = 0.0;
  bool _playing = true;

  ui.Image? _image;
  bool _decoding = false;
  bool _pendingRedecode = false;
  bool _disposed = false;

  bool get _effectiveActMode =>
      widget.actMode &&
      widget.asset is PixelEffect &&
      (widget.asset as PixelEffect).act != null;

  bool get _effectiveLoop => widget.loop ?? widget.asset.meta.loop;

  @override
  void initState() {
    super.initState();
    _playing = widget.playing;
    _rebuildInstance();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant PixelIsoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      _playing = widget.playing;
    }
    final changed = !identical(oldWidget.asset, widget.asset) ||
        oldWidget.dir != widget.dir ||
        oldWidget.plane != widget.plane ||
        oldWidget.projection != widget.projection ||
        oldWidget.pitch != widget.pitch ||
        oldWidget.actMode != widget.actMode ||
        oldWidget.showActor != widget.showActor ||
        oldWidget.showTarget != widget.showTarget ||
        oldWidget.seed != widget.seed ||
        oldWidget.palette != widget.palette ||
        oldWidget.backdrop != widget.backdrop;
    if (changed) {
      _rebuildInstance();
    }
  }

  void _rebuildInstance() {
    final m = widget.asset.meta;
    final mergedOpts = <String, Object?>{
      ...widget.options,
      if (widget.palette != null) 'palette': widget.palette,
      if (widget.seed != null) 'seed': widget.seed,
      'light': widget.light,
    };

    if (_effectiveActMode) {
      final bounds = isoActBounds(
        widget.asset,
        RigRasterizer.instance,
        dir: widget.dir,
        projection: widget.projection,
        pitch: widget.pitch,
      );
      _frameW = bounds.width;
      _frameH = bounds.height;
      _pivot = (bounds.originX, bounds.originY);
      mergedOpts['x'] = bounds.originX;
      mergedOpts['y'] = bounds.originY;
      _inst = IsoActInstance(
        source: widget.asset,
        spec: IsoActSpec(
          dir: widget.dir,
          plane: widget.plane,
          projection: widget.projection,
          pitch: widget.pitch,
        ),
        options: mergedOpts,
        showActor: widget.showActor,
        showTarget: widget.showTarget,
        onHit: widget.onHit,
      );
    } else {
      final isNativeIso = m.extra['iso'] == true;
      final targetAsset = isNativeIso
          ? widget.asset
          : IsoProjectedEffect(
              widget.asset,
              plane: widget.plane,
              projection: widget.projection,
              dir: widget.dir,
              bg: widget.backdrop ?? BackdropKind.isoGrid,
            );
      _frameW = targetAsset.meta.width;
      _frameH = targetAsset.meta.height;
      _pivot = targetAsset.meta.origin;
      mergedOpts['x'] = targetAsset.meta.originX;
      mergedOpts['y'] = targetAsset.meta.originY;
      _inst = targetAsset.createInstance(mergedOpts);
    }

    _frame = createIsoFrame(_frameW, _frameH);
    _rgba = Uint8List(_frameW * _frameH * 4);
    final bgKind = widget.backdrop ??
        (m.bg == BackdropKind.dark && m.extra['iso'] == true
            ? BackdropKind.isoGrid
            : (m.extra['iso'] == true ? m.bg : BackdropKind.isoGrid));
    _bgBuffer = backdrop(bgKind, _frameW, _frameH, _pivot.$2);
    _accum = 0.0;
    _elapsed = 0.0;
    _renderCurrent();
    _scheduleDecode();
  }

  void _renderCurrent() {
    clearIsoFrame(_frame);
    final inst = _inst;
    if (inst != null) {
      inst.draw(_frame, DrawLayer.both);
      for (final fx in widget.postProcessors) {
        fx.apply(_frame, inst.t, inst.options);
      }
    }
    composite(_frame, _rgba, bgBuffer: _bgBuffer, lightK: widget.light);
  }

  void _scheduleDecode() {
    if (_disposed) return;
    if (_decoding) {
      _pendingRedecode = true;
      return;
    }
    _decoding = true;
    final copy = Uint8List.fromList(_rgba);
    rgbaToUiImage(copy, _frameW, _frameH).then((img) {
      _decoding = false;
      if (_disposed) {
        img.dispose();
        return;
      }
      _image?.dispose();
      _image = img;
      if (mounted) setState(() {});
      if (_pendingRedecode) {
        _pendingRedecode = false;
        _scheduleDecode();
      }
    });
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (!_playing || dt <= 0.0 || _inst == null) return;
    final clampedDt = dt > 0.1 ? 0.1 : dt;
    final fps = widget.asset.meta.fps > 0 ? widget.asset.meta.fps : 30;
    final stepDt = 1.0 / fps;
    _accum += clampedDt * widget.speed;

    var advanced = false;
    while (_accum >= stepDt) {
      _accum -= stepDt;
      _inst!.update(stepDt);
      _elapsed += stepDt;
      advanced = true;
      if (_effectiveActMode && _inst is IsoActInstance && _inst!.done) {
        if (_effectiveLoop) {
          _rebuildInstance();
        } else {
          _playing = false;
        }
        break;
      }
      final dur = widget.asset.meta.duration;
      if (!_effectiveActMode && _effectiveLoop && dur > 0.0 && _elapsed >= dur) {
        _elapsed %= dur;
      }
    }

    if (advanced) {
      _renderCurrent();
      _scheduleDecode();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inst = _inst;
    final skeleton = widget.showSkeleton && inst is IsoActInstance
        ? inst.currentSkeleton
        : null;
    final pose = inst is IsoActInstance ? inst.pose : null;
    final shake = inst is IsoActInstance ? inst.shake : const (0, 0);

    final painter = CustomPaint(
      painter: PixelFxPainter(
        image: _image,
        frameWidth: _frameW,
        frameHeight: _frameH,
        pivot: _pivot,
        shake: shake,
        fit: widget.fit,
        skeleton: skeleton,
        pose: pose,
        flip: widget.flip,
      ),
      child: widget.scale != null
          ? SizedBox(
              width: _frameW * widget.scale!,
              height: _frameH * widget.scale!,
            )
          : const SizedBox.expand(),
    );

    if (widget.scale != null) {
      return SizedBox(
        width: _frameW * widget.scale!,
        height: _frameH * widget.scale!,
        child: painter,
      );
    }
    return painter;
  }
}

/// Convenience widget framing a 2:1 dimetric tile or prop asset over an isometric stage.
class PixelIsoTileView extends StatelessWidget {
  final PixelAsset tileAsset;
  final IsoDir dir;
  final BackdropKind backdrop;
  final double? scale;
  final List<Object>? palette;
  final int? seed;
  final BoxFit fit;

  const PixelIsoTileView({
    super.key,
    required this.tileAsset,
    this.dir = IsoDir.se,
    this.backdrop = BackdropKind.isoGrid,
    this.scale,
    this.palette,
    this.seed,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) => PixelIsoView(
        asset: tileAsset,
        dir: dir,
        plane: IsoPlane.floor,
        backdrop: backdrop,
        scale: scale,
        palette: palette,
        seed: seed,
        fit: fit,
      );
}
