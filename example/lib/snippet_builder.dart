// Generates copy-ready Dart widget snippets matching the current Gallery configuration.

import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_iso/pixelfx_iso.dart';

String _toCamelCase(String kebab) {
  final parts = kebab.split(RegExp(r'[-_]'));
  if (parts.isEmpty) return kebab;
  final buf = StringBuffer(parts.first);
  for (var i = 1; i < parts.length; i++) {
    final p = parts[i];
    if (p.isEmpty) continue;
    buf
      ..write(p[0].toUpperCase())
      ..write(p.substring(1));
  }
  return buf.toString();
}

/// Build an idiomatic Dart snippet to embed [asset] in any Flutter widget tree.
String buildDartSnippet({
  required PixelAsset asset,
  bool actMode = false,
  bool isoMode = false,
  IsoDir dir = IsoDir.se,
  IsoPlane plane = IsoPlane.floor,
  String? paletteName,
  BackdropKind backdrop = BackdropKind.dark,
  bool flip = false,
  double speed = 1.0,
  bool showActor = true,
  bool showTarget = true,
  bool showSkeleton = false,
}) {
  final id = asset.meta.id;
  final short = id.contains('/') ? id.split('/').last : id;
  final varName = '${_toCamelCase(short)}Effect';
  final isAct = actMode && asset is PixelEffect && asset.act != null;
  final widgetName = isoMode
      ? 'PixelIsoView'
      : (isAct ? 'PixelActView' : 'PixelFxView');
  final propName = (!isoMode && isAct) ? 'effect' : 'asset';

  final lines = <String>[
    '// Option A: direct import from pixelfx_catalog / pixelfx_iso ($varName)',
    '// Option B: registry.getAsset(\'$id\')!',
    '$widgetName(',
    '  $propName: $varName,',
    if (isoMode) '  dir: IsoDir.${dir.name},',
    if (isoMode && asset.meta.extra['iso'] != true)
      '  plane: IsoPlane.${plane.name},',
    if (isoMode && isAct) '  actMode: true,',
    if (paletteName != null) '  palette: Pal.$paletteName,',
    '  backdrop: BackdropKind.${backdrop.name},',
    if (flip) '  flip: true,',
    if ((speed - 1.0).abs() > 1e-4) '  speed: ${speed.toStringAsFixed(2)},',
    if (!showActor) '  showActor: false,',
    if (isAct && !showTarget) '  showTarget: false,',
    if (showSkeleton) '  showSkeleton: true,',
    '  scale: 3,',
    ')',
  ];
  return lines.join('\n');
}
