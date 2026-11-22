## Unreleased

- Update `example` gallery widget test expectations for the full 244-effect catalog.
- Update standalone GitHub Actions CI & pub.dev OIDC publish workflows to use `_ci_workspace` isolation (`flutter analyze --fatal-infos lib test`, `flutter pub publish`), `workflow_dispatch` `dry_run` support, and `CHANGELOG.md` heading validation.

## 0.1.0

- Initial Wave 0 release: Flutter runtime widgets (`PixelFxView`, `PixelActView`, `PixelAssetView`), single-flight `PixelFxController`, nearest-neighbor `PixelFxPainter`, `PixelFxBaker` (`bakeFrames`, `bakeAtlas`), and interactive `pixelfx_gallery` example app (`--org faustobdls.dev`).
