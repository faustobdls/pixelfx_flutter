# pixelfx_flutter

Flutter runtime widgets (`PixelFxView`, `PixelActView`, `PixelAssetView`), single-flight `PixelFxController`, nearest-neighbor `PixelFxPainter` (`FilterQuality.none`), color interop (`Pal` <-> `Color`), and in-memory GPU atlas baking (`PixelFxBaker`) for `pixelfx_core`.

Includes the interactive `pixelfx_gallery` example app (`example/`).

## Usage

```dart
import 'package:pixelfx_catalog/pixelfx_catalog.dart';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_flutter/pixelfx_flutter.dart';

PixelActView(
  effect: swordSlashEffect,
  palette: Pal.ice,
  backdrop: BackdropKind.dark,
  scale: 3,
);
```
