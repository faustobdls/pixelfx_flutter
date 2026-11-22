## 0.1.0

- Initial release: Flutter runtime widgets (`PixelFxView`, `PixelActView`, `PixelAssetView`), single-flight `PixelFxController`, nearest-neighbor `PixelFxPainter`, `PixelFxBaker` (`bakeFrames`, `bakeAtlas`), and interactive `pixelfx_gallery` example app (`--org faustobdls.dev`) covering all 244 catalog assets.
- Configured standalone GitHub Actions CI & pub.dev OIDC automated publishing workflows using `_ci_workspace` isolation (`flutter analyze --fatal-infos lib test`, `flutter pub publish`).
