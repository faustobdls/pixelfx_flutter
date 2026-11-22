import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_flutter/pixelfx_flutter.dart';
import 'package:pixelfx_iso/pixelfx_iso.dart';

final PureEffect _testPulseEffect = PureEffect(
  meta: const EffectMeta(
    id: 'test/pulse',
    name: 'Test Pulse',
    desc: 'Minimal pure pulse effect for widget tests.',
    size: (16, 16),
    origin: (8, 8),
    duration: 0.5,
    loop: true,
    fps: 10,
    actorScale: 1,
    defaultOptions: {'palette': Pal.fire},
  ),
  act: const ActSpec(
    poses: [
      PoseKey(-0.1, kStand),
      PoseKey(0.1, kReady),
      PoseKey(0.4, kStand),
    ],
    hits: [HitSpec(t: 0.1, shake: 0.1, amp: 2.0)],
  ),
  onDraw: (p, t, o) {
    final c = ramp(o.palette);
    p.glow(0, 0, 5, c[1], 0.7);
    p.dot(0, 0, c[3]);
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('color interop round-trips Flutter Color and ABGR int', () {
    const src = Color(0xCC12AB34);
    final abgr = colorToAbgr(src);
    final back = abgrToColor(abgr);
    expect(back.toARGB32(), equals(src.toARGB32()));

    final palInts = colorsToPalette(const [Color(0xFFFF0000), Color(0xFF0000FF)]);
    expect(palInts[0], equals(0xFF0000FF)); // RGBA red = ABGR 0xFF0000FF
    expect(palInts[1], equals(0xFFFF0000)); // RGBA blue = ABGR 0xFFFF0000
  });

  test('PixelFxBaker bakes individual frames and packed atlas cleanly', () async {
    final frames = await PixelFxBaker.bakeFrames(_testPulseEffect, seed: 3);
    expect(frames.length, equals(5));
    expect(frames.first.width, equals(16));
    expect(frames.first.height, equals(16));
    for (final img in frames) {
      img.dispose();
    }

    final atlas = await PixelFxBaker.bakeAtlas(
      _testPulseEffect,
      seed: 3,
      options: {'palette': paletteToColors(Pal.fire)},
    );
    expect(atlas.frameCount, equals(5));
    expect(atlas.frameWidth, equals(16));
    expect(atlas.frameHeight, equals(16));
    expect(atlas.image.width, equals(atlas.columns * 16));
    expect(atlas.image.height, equals(atlas.rows * 16));
    expect(atlas.frameRect(4).width, equals(16));
    atlas.dispose();
  });

  test('PixelFxController supports single-flight decode, seek, skeleton, and actMode', () async {
    final hits = <HitSpec>[];
    final ctrl = PixelFxController(
      asset: _testPulseEffect,
      actMode: true,
      showSkeleton: true,
      onHit: hits.add,
    );

    await ctrl.flushDecodeForTest();
    expect(ctrl.image, isNotNull);
    expect(ctrl.currentSkeleton, isNotNull);

    ctrl.seekToTime(0.25);
    await ctrl.flushDecodeForTest();
    expect(hits, isNotEmpty);

    ctrl.step(0.05);
    await ctrl.flushDecodeForTest();
    ctrl.dispose();
  });

  testWidgets('PixelFxView and PixelActView render crisp CustomPaint trees', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            PixelFxView(
              asset: _testPulseEffect,
              scale: 4,
              palette: const [
                Color(0xFF100820),
                Color(0xFF3A1F6B),
                Color(0xFF8C4DE8),
                Color(0xFFF5D8FF),
              ],
            ),
            PixelActView(
              effect: _testPulseEffect,
              scale: 2,
              showSkeleton: true,
            ),
          ],
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PixelFxView), findsOneWidget);
    expect(find.byType(PixelActView), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    final sized = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sized.width, equals(64));
    expect(sized.height, equals(64));
  });

  testWidgets('PixelIsoView and PixelIsoTileView render 2.5D iso effects and acted rigs', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            PixelIsoTileView(
              tileAsset: isoStoneTile,
              scale: 2,
            ),
            PixelIsoView(
              asset: _testPulseEffect,
              dir: IsoDir.ne,
              plane: IsoPlane.floor,
              actMode: true,
              showSkeleton: true,
              scale: 2,
            ),
          ],
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(PixelIsoTileView), findsOneWidget);
    expect(find.byType(PixelIsoView), findsNWidgets(2));
  });
}
