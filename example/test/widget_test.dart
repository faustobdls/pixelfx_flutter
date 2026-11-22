import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixelfx_gallery/effect_detail_dialog.dart';
import 'package:pixelfx_gallery/main.dart';

void main() {
  testWidgets('Gallery loads Wave 0 catalog, filters by search, and opens inspector', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PixelFxGalleryApp());
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('PixelFx Gallery'), findsOneWidget);
    expect(find.text('15 / 15 assets'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sword');
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('1 / 15 assets'), findsOneWidget);
    expect(find.byKey(const Key('asset-card-melee/sword-slash')), findsOneWidget);

    await tester.tap(find.byKey(const Key('asset-card-melee/sword-slash')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(EffectDetailDialog), findsOneWidget);
    expect(find.text('Copy Dart'), findsOneWidget);

    await tester.tap(find.text('Act'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Skeleton'));
    await tester.pump(const Duration(milliseconds: 50));

    final iceChip = find.ancestor(
      of: find.descendant(
        of: find.byType(EffectDetailDialog),
        matching: find.text('ice'),
      ),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(iceChip);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(iceChip);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Copy Dart'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Copied!'), findsOneWidget);
    expect(find.text('Copied Dart snippet for melee/sword-slash'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(EffectDetailDialog), findsNothing);
  });
}
