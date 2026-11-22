// Entrypoint for the PixelFx Gallery interactive showcase app (org: faustobdls.dev).

import 'package:material_ui/material_ui.dart';
import 'package:pixelfx_catalog/pixelfx_catalog.dart';
import 'package:pixelfx_core/pixelfx_core.dart';

import 'gallery_page.dart';

void main() {
  runApp(PixelFxGalleryApp());
}

class PixelFxGalleryApp extends StatelessWidget {
  final PixelFxRegistry registry;

  PixelFxGalleryApp({
    super.key,
    PixelFxRegistry? registry,
  }) : registry = registry ?? createDefaultRegistry();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PixelFx Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0C15),
        splashFactory: NoSplash.splashFactory,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFAE35),
          secondary: Color(0xFF58F2C8),
          surface: Color(0xFF171422),
        ),
      ),
      home: GalleryPage(registry: registry),
    );
  }
}
