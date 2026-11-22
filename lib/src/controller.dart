// Animation controller bridging pixelfx_core simulation with single-flight ui.Image decoding.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pixelfx_core/pixelfx_core.dart';

import 'color_interop.dart';
import 'frame_image.dart';

/// Drives playback, stepping, seeking, backdrop selection, and safe GPU upload
/// for any [PixelAsset] (or [PixelEffect] in optional [actMode]).
class PixelFxController extends ChangeNotifier {
  PixelAsset _asset;
  bool _actMode;
  bool _playing;
  bool _loop;
  double _speed;
  BackdropKind _backdropKind;
  bool _showActor;
  bool _showTarget;
  bool _flip;
  bool _showSkeleton;
  int? _seed;
  double _lightK;
  Map<String, Object?> _options;
  List<PostProcessor> _postProcessors;
  void Function(HitSpec hit)? _onHit;

  late int _width;
  late int _height;
  late int _pivotX;
  late int _pivotY;
  late PixelFrame _frame;
  Uint32List? _bgBuffer;
  late Uint8List _rgbaBuffer;

  AssetInstance? _instance;
  double _startTime = 0.0;
  double _endTime = 0.0;
  double _elapsed = 0.0;
  double _accum = 0.0;

  ui.Image? _image;
  bool _decoding = false;
  bool _needsDecode = true;
  bool _disposed = false;
  SkeletonView? _skeleton;
  Pose? _pose;
  (int sx, int sy) _shake = (0, 0);
  bool _frozen = false;

  PixelFxController({
    required PixelAsset asset,
    bool actMode = false,
    this._playing = true,
    bool? loop,
    this._speed = 1.0,
    BackdropKind? backdropKind,
    this._showActor = true,
    this._showTarget = true,
    this._flip = false,
    this._showSkeleton = false,
    this._seed,
    this._lightK = 1.0,
    this._options = const {},
    this._postProcessors = const [],
    this._onHit,
  })  : _asset = asset,
        _actMode = actMode && asset is PixelEffect && asset.act != null,
        _loop = loop ?? asset.meta.loop,
        _backdropKind = backdropKind ?? asset.meta.bg {
    _rebuildSurfaceAndInstance(renderNow: true);
  }

  PixelAsset get asset => _asset;
  bool get actMode => _actMode;
  bool get playing => _playing;
  bool get loop => _loop;
  double get speed => _speed;
  BackdropKind get backdropKind => _backdropKind;
  bool get showActor => _showActor;
  bool get showTarget => _showTarget;
  bool get flip => _flip;
  bool get showSkeleton => _showSkeleton;
  int? get seed => _seed;
  double get lightK => _lightK;
  Map<String, Object?> get options => _options;

  int get frameWidth => _width;
  int get frameHeight => _height;
  (int ox, int oy) get pivot => (_pivotX, _pivotY);
  ui.Image? get image => _image;
  SkeletonView? get currentSkeleton => _showSkeleton ? _skeleton : null;
  Pose? get currentPose => _pose;
  (int sx, int sy) get shake => _shake;
  bool get frozen => _frozen;
  bool get done => _instance?.done ?? false;

  int get targetFps => _actMode ? 60 : math.max(1, _asset.meta.fps);
  double get currentTime => _elapsed;
  double get totalDuration => math.max(0.0, _endTime - _startTime);
  int get frameCount =>
      math.max(1, (totalDuration * targetFps).round() + (_loop ? 0 : 1));
  double get progress =>
      totalDuration <= 0.0 ? 0.0 : (_elapsed / totalDuration).clamp(0.0, 1.0);

  void play() {
    if (!_playing) {
      if (!_loop && _elapsed >= totalDuration && totalDuration > 0.0) {
        restart();
      }
      _playing = true;
      notifyListeners();
    }
  }

  void pause() {
    if (_playing) {
      _playing = false;
      notifyListeners();
    }
  }

  void togglePlay() => _playing ? pause() : play();

  void restart() {
    _elapsed = 0.0;
    _accum = 0.0;
    _createFreshInstance();
    _renderToBuffer();
    _scheduleDecode();
    notifyListeners();
  }

  /// Advance simulation by [dtSeconds] (called by the Ticker or manually in tests).
  void step(double dtSeconds) {
    if (_disposed || !_playing || dtSeconds <= 0.0) return;
    final inst = _instance;
    if (inst == null) return;

    final dt = dtSeconds * _speed;
    final total = totalDuration;
    if (total <= 0.0 && _asset is StaticPixelAsset) return;

    final stepDt = 1.0 / targetFps;
    _accum += dt;
    var advanced = false;

    while (_accum + 1e-9 >= stepDt) {
      _accum -= stepDt;
      if (!_loop && _elapsed >= total && !_actMode) {
        _playing = false;
        break;
      }
      inst.update(stepDt);
      _elapsed += stepDt;
      advanced = true;

      if (_actMode && inst is ActInstance && inst.done) {
        if (_loop) {
          _elapsed = 0.0;
          _createFreshInstance();
        } else {
          _playing = false;
        }
        break;
      }
      if (!_actMode && _loop && total > 0.0 && _elapsed >= total) {
        _elapsed = _elapsed % total;
      }
    }

    if (advanced) {
      _renderToBuffer();
      _scheduleDecode();
      notifyListeners();
    }
  }

  /// Jump cleanly to normalized position [u] in `0.0..1.0`.
  void seekNormalized(double u) {
    final target = u.clamp(0.0, 1.0) * totalDuration;
    seekToTime(target);
  }

  /// Seek to exact local elapsed seconds from the start of the clip (`0..totalDuration`).
  void seekToTime(double seconds) {
    if (_disposed) return;
    final clamped =
        totalDuration <= 0.0 ? 0.0 : seconds.clamp(0.0, totalDuration);
    final stepDt = 1.0 / targetFps;
    final steps = (clamped / stepDt).round();
    _createFreshInstance();
    _elapsed = 0.0;
    _accum = 0.0;
    final inst = _instance;
    if (inst != null) {
      for (var i = 0; i < steps; i++) {
        inst.update(stepDt);
        _elapsed += stepDt;
      }
    }
    _renderToBuffer();
    _scheduleDecode();
    notifyListeners();
  }

  /// Step forward or backward by [delta] discrete frames while paused.
  void stepFrame(int delta) {
    _playing = false;
    final stepDt = 1.0 / targetFps;
    final next = (_elapsed + delta * stepDt);
    if (_loop && totalDuration > 0.0) {
      seekToTime(((next % totalDuration) + totalDuration) % totalDuration);
    } else {
      seekToTime(next);
    }
  }

  /// Reconfigure asset, actMode, palette/options, or playback properties atomically.
  void updateConfig({
    PixelAsset? asset,
    bool? actMode,
    bool? playing,
    bool? loop,
    double? speed,
    BackdropKind? backdropKind,
    bool? showActor,
    bool? showTarget,
    bool? flip,
    bool? showSkeleton,
    int? seed,
    bool clearSeed = false,
    double? lightK,
    Map<String, Object?>? options,
    List<PostProcessor>? postProcessors,
    void Function(HitSpec hit)? onHit,
  }) {
    var needsRebuild = false;
    var needsRedraw = false;

    if (asset != null && !identical(asset, _asset)) {
      _asset = asset;
      _loop = loop ?? asset.meta.loop;
      _backdropKind = backdropKind ?? asset.meta.bg;
      _elapsed = 0.0;
      _accum = 0.0;
      needsRebuild = true;
    }
    final nextAct = (actMode ?? _actMode) &&
        _asset is PixelEffect &&
        (_asset as PixelEffect).act != null;
    if (nextAct != _actMode) {
      _actMode = nextAct;
      _elapsed = 0.0;
      _accum = 0.0;
      needsRebuild = true;
    }
    if (playing != null) _playing = playing;
    if (loop != null) _loop = loop;
    if (speed != null) _speed = speed;
    if (backdropKind != null && backdropKind != _backdropKind) {
      _backdropKind = backdropKind;
      _bgBuffer = backdrop(_backdropKind, _width, _height, _pivotY);
      needsRedraw = true;
    }
    if (showActor != null && showActor != _showActor) {
      _showActor = showActor;
      needsRedraw = true;
    }
    if (showTarget != null && showTarget != _showTarget) {
      _showTarget = showTarget;
      needsRedraw = true;
    }
    if (flip != null && flip != _flip) {
      _flip = flip;
      needsRebuild = true;
    }
    if (showSkeleton != null && showSkeleton != _showSkeleton) {
      _showSkeleton = showSkeleton;
      needsRedraw = true;
    }
    if (clearSeed && _seed != null) {
      _seed = null;
      needsRebuild = true;
    } else if (seed != null && seed != _seed) {
      _seed = seed;
      needsRebuild = true;
    }
    if (lightK != null && lightK != _lightK) {
      _lightK = lightK;
      needsRedraw = true;
    }
    if (options != null && !_optionsEqual(options, _options)) {
      _options = options;
      needsRebuild = true;
    }
    if (postProcessors != null) {
      _postProcessors = postProcessors;
      needsRedraw = true;
    }
    if (onHit != null) {
      _onHit = onHit;
      if (_instance is ActInstance) {
        (_instance! as ActInstance).onHit = onHit;
      }
    }

    if (needsRebuild) {
      _rebuildSurfaceAndInstance(renderNow: true);
      notifyListeners();
    } else if (needsRedraw) {
      _renderToBuffer();
      _scheduleDecode();
      notifyListeners();
    }
  }

  /// Exposed for unit testing: decode one frame and wait for completion.
  Future<void> flushDecodeForTest() async {
    _scheduleDecode();
    while (_decoding || _needsDecode) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  void _rebuildSurfaceAndInstance({required bool renderNow}) {
    final m = _asset.meta;
    if (_actMode && _asset is PixelEffect) {
      final fx = _asset as PixelEffect;
      final b = actBounds(fx);
      const pad = 6;
      _width = b.x1 - b.x0 + pad * 2;
      _height = b.y1 - b.y0 + pad * 2;
      _pivotX = pad - b.x0;
      _pivotY = pad - b.y0;
      final span = actSpan(fx);
      _startTime = span.$1;
      _endTime = m.loop ? m.duration * 2.0 : span.$2 + 0.3;
    } else {
      _width = m.width;
      _height = m.height;
      _pivotX = m.originX;
      _pivotY = m.originY;
      _startTime = 0.0;
      _endTime = m.duration;
    }

    _frame = createFrame(_width, _height);
    _bgBuffer = backdrop(_backdropKind, _width, _height, _pivotY);
    _rgbaBuffer = Uint8List(_width * _height * 4);
    _createFreshInstance();

    if (renderNow) {
      _renderToBuffer();
      _scheduleDecode();
    }
  }

  void _createFreshInstance() {
    final norm = normalizeFlutterOptions(_options);
    final merged = <String, Object?>{
      'x': _pivotX,
      'y': _pivotY,
      'flip': _flip,
      'seed': ?_seed,
      ...norm,
    };
    if (_actMode && _asset is PixelEffect) {
      final act = createAct(_asset as PixelEffect, merged);
      act.onHit = _onHit;
      _instance = act;
    } else {
      _instance = _asset.createInstance(merged);
    }
  }

  void _renderToBuffer() {
    final inst = _instance;
    if (inst == null) return;

    if (inst is ActInstance) {
      clearFrame(_frame);
      inst.draw(_frame, DrawLayer.both, _showActor, _showTarget);
      for (final pp in _postProcessors) {
        pp.apply(_frame, inst.t, inst.options);
      }
      _pose = inst.pose;
      _skeleton = _showSkeleton ? skeleton(inst.pose) : null;
      _shake = inst.shake;
      _frozen = inst.frozen;
    } else {
      final applyEdge = !isScreenMeta(_asset.meta);
      renderAssetFrameInto(
        _frame,
        _asset,
        inst,
        showActor: _showActor,
        flip: _flip,
        applyEdgeFade: applyEdge,
        postProcessors: _postProcessors,
      );
      _pose = _asset.meta.hasActor ? kStand : null;
      _skeleton =
          (_showSkeleton && _asset.meta.hasActor) ? skeleton(kStand) : null;
      _shake = (0, 0);
      _frozen = false;
    }

    composite(
      _frame,
      _rgbaBuffer,
      bgBuffer: _bgBuffer,
      lightK: _lightK,
    );
  }

  void _scheduleDecode() {
    _needsDecode = true;
    if (_decoding || _disposed) return;
    _pumpDecode();
  }

  void _pumpDecode() {
    if (_disposed || !_needsDecode || _decoding) return;
    _decoding = true;
    _needsDecode = false;

    final snapshot = Uint8List.fromList(_rgbaBuffer);
    final w = _width;
    final h = _height;
    rgbaToUiImage(snapshot, w, h).then((decoded) {
      _decoding = false;
      if (_disposed) {
        decoded.dispose();
        return;
      }
      final prev = _image;
      _image = decoded;
      prev?.dispose();
      notifyListeners();
      if (_needsDecode) {
        _pumpDecode();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}

bool _optionsEqual(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key)) return false;
    final av = e.value;
    final bv = b[e.key];
    if (identical(av, bv)) continue;
    if (av is List && bv is List) {
      if (!listEquals<Object?>(av, bv)) return false;
    } else if (av is Map && bv is Map) {
      if (!mapEquals<Object?, Object?>(av, bv)) return false;
    } else if (av != bv) {
      return false;
    }
  }
  return true;
}
