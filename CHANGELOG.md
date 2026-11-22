## 0.2.0

- Depend on `pixelfx_core ^0.2.0` and `pixelfx_iso ^0.1.0`.
- Add `PixelIsoView` and `PixelIsoTileView` widgets with 8-direction `IsoDir` facing, `IsoPlane` projection (`floor`, `billboard`, `wallLeft`, `wallRight`), 2.5D pitched `actMode`, skeleton debug overlay, and `BackdropKind.isoGrid`.
- Update `pixelfx_gallery` example app with 2D / 2.5D Iso preview mode, direction/plane controls, and `PixelIsoView` snippet generation across all 254 assets.

## 0.1.0

- Initial release: Flutter runtime widgets (`PixelFxView`, `PixelActView`, `PixelAssetView`), single-flight `PixelFxController`, nearest-neighbor `PixelFxPainter`, `PixelFxBaker` (`bakeFrames`, `bakeAtlas`), and interactive `pixelfx_gallery` example app (`--org faustobdls.dev`) covering all 244 catalog assets.
- Configured standalone GitHub Actions CI & pub.dev OIDC automated publishing workflows using `_ci_workspace` isolation (`flutter analyze --fatal-infos lib test`, `flutter pub publish`).
