// Crisp nearest-neighbor CustomPainter with camera-shake and skeleton debug overlay.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:pixelfx_core/pixelfx_core.dart';

import 'frame_image.dart';

/// Renders a [ui.Image] produced by [PixelFxController] with `FilterQuality.none`,
/// optional integer camera-shake offset, and optional 3D rig skeleton overlay.
class PixelFxPainter extends CustomPainter {
  final ui.Image? image;
  final int frameWidth;
  final int frameHeight;
  final (int ox, int oy) pivot;
  final (int sx, int sy) shake;
  final BoxFit fit;
  final SkeletonView? skeleton;
  final Pose? pose;
  final bool flip;

  const PixelFxPainter({
    required this.image,
    required this.frameWidth,
    required this.frameHeight,
    this.pivot = const (0, 0),
    this.shake = const (0, 0),
    this.fit = BoxFit.contain,
    this.skeleton,
    this.pose,
    this.flip = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null || size.isEmpty || frameWidth <= 0 || frameHeight <= 0) {
      return;
    }

    final srcSize = Size(frameWidth.toDouble(), frameHeight.toDouble());
    final fitted = applyBoxFit(fit, srcSize, size);
    final dstRect = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );

    final scaleX = dstRect.width / frameWidth;
    final scaleY = dstRect.height / frameHeight;
    final shakenDst = dstRect.shift(Offset(shake.$1 * scaleX, shake.$2 * scaleY));

    drawCrispImage(canvas, img, shakenDst);

    final skel = skeleton;
    if (skel != null) {
      _paintSkeleton(canvas, shakenDst, scaleX, scaleY, skel);
    }
  }

  void _paintSkeleton(
    Canvas canvas,
    Rect dst,
    double scaleX,
    double scaleY,
    SkeletonView skel,
  ) {
    final poseX = pose?.x ?? 0.0;
    final poseY = pose?.y ?? 0.0;

    Offset toCanvas(Vec3 j) {
      final lx = flip ? -(poseX + j.$1) : (poseX + j.$1);
      final ly = poseY + j.$2;
      return Offset(
        dst.left + (pivot.$1 + lx) * scaleX,
        dst.top + (pivot.$2 + ly) * scaleY,
      );
    }

    final bonePaint = Paint()
      ..color = const Color(0xCC58F2C8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final (aName, bName) in skel.bones) {
      final a = skel.joints[aName];
      final b = skel.joints[bName];
      if (a != null && b != null) {
        canvas.drawLine(toCanvas(a), toCanvas(b), bonePaint);
      }
    }

    final jointPaint = Paint()..color = const Color(0xFFEAF6FF);
    final handlePaint = Paint()..color = const Color(0xFFFFA938);

    for (final e in skel.joints.entries) {
      final isHandle = skel.handles.contains(e.key);
      canvas.drawCircle(
        toCanvas(e.value),
        isHandle ? 3.5 : 2.2,
        isHandle ? handlePaint : jointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PixelFxPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.frameWidth != frameWidth ||
      oldDelegate.frameHeight != frameHeight ||
      oldDelegate.pivot != pivot ||
      oldDelegate.shake != shake ||
      oldDelegate.fit != fit ||
      oldDelegate.skeleton != skeleton ||
      oldDelegate.pose != pose ||
      oldDelegate.flip != flip;
}
