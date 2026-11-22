// Interactive detail studio modal for inspecting effects, palettes, acts, and 3D skeletons.

import 'dart:async' show unawaited;

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_flutter/pixelfx_flutter.dart';

import 'snippet_builder.dart';

class EffectDetailDialog extends StatefulWidget {
  final PixelAsset asset;
  final PixelFxRegistry registry;

  const EffectDetailDialog({
    super.key,
    required this.asset,
    required this.registry,
  });

  @override
  State<EffectDetailDialog> createState() => _EffectDetailDialogState();
}

class _EffectDetailDialogState extends State<EffectDetailDialog> {
  late final PixelFxController _controller;
  String? _selectedPalette;
  bool _actMode = false;
  bool _flip = false;
  bool _showActor = true;
  bool _showTarget = true;
  bool _showSkeleton = false;
  double _speed = 1.0;
  bool _copied = false;
  late BackdropKind _backdrop;

  bool get _supportsAct =>
      widget.asset is PixelEffect && (widget.asset as PixelEffect).act != null;

  @override
  void initState() {
    super.initState();
    _backdrop = widget.asset.meta.bg;
    _controller = PixelFxController(
      asset: widget.asset,
      actMode: false,
      loop: widget.asset.meta.loop,
      backdropKind: _backdrop,
    );
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _applyConfig() {
    final palettes = widget.registry.palettes;
    final selectedRamp =
        _selectedPalette != null ? palettes[_selectedPalette!] : null;
    _controller.updateConfig(
      actMode: _actMode,
      flip: _flip,
      showActor: _showActor,
      showTarget: _showTarget,
      showSkeleton: _showSkeleton,
      speed: _speed,
      backdropKind: _backdrop,
      options: selectedRamp == null
          ? const {}
          : <String, Object?>{'palette': selectedRamp},
    );
  }

  void _copySnippet() {
    final snippet = buildDartSnippet(
      asset: widget.asset,
      actMode: _actMode,
      paletteName: _selectedPalette,
      backdrop: _backdrop,
      flip: _flip,
      speed: _speed,
      showActor: _showActor,
      showTarget: _showTarget,
      showSkeleton: _showSkeleton,
    );
    unawaited(
      Clipboard.setData(ClipboardData(text: snippet)).catchError((Object _) {}),
    );
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied Dart snippet for ${widget.asset.meta.id}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.asset.meta;
    final paletteNames = widget.registry.palettes.keys.toList(growable: false);

    return Dialog(
      backgroundColor: const Color(0xFF151220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF2E2842)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF3EEFF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${m.id}  •  ${m.width}x${m.height}px  •  ${m.fps} fps  •  ${m.loop ? "LOOP" : "ONE-SHOT"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9C93B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _copySnippet,
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                    label: Text(_copied ? 'Copied!' : 'Copy Dart'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                m.desc,
                style: const TextStyle(fontSize: 13, color: Color(0xFFC5BED9)),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              Container(
                height: 230,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0810),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2E2842)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: PixelAssetView(
                          asset: widget.asset,
                          controller: _controller,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xB8151220),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            't=${_controller.currentTime.toStringAsFixed(2)}s / '
                            '${_controller.totalDuration.toStringAsFixed(2)}s  '
                            '(${_controller.frameWidth}x${_controller.frameHeight})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE0DAFA),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_controller.frozen)
                      const Positioned(
                        right: 10,
                        top: 8,
                        child: Chip(
                          label: Text('FROZEN'),
                          backgroundColor: Color(0xFF3E1838),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    tooltip: _controller.playing ? 'Pause' : 'Play',
                    onPressed: _controller.togglePlay,
                    icon: Icon(
                      _controller.playing ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Step -1 frame',
                    onPressed: () => _controller.stepFrame(-1),
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton(
                    tooltip: 'Step +1 frame',
                    onPressed: () => _controller.stepFrame(1),
                    icon: const Icon(Icons.skip_next),
                  ),
                  IconButton(
                    tooltip: 'Restart',
                    onPressed: _controller.restart,
                    icon: const Icon(Icons.replay),
                  ),
                  Expanded(
                    child: Slider(
                      value: _controller.progress,
                      onChanged: (v) {
                        _controller.pause();
                        _controller.seekNormalized(v);
                      },
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Speed:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9C93B8)),
                  ),
                  for (final s in const [0.25, 0.5, 1.0, 2.0])
                    ChoiceChip(
                      label: Text('${s}x'),
                      selected: (_speed - s).abs() < 1e-4,
                      onSelected: (_) {
                        setState(() => _speed = s);
                        _applyConfig();
                      },
                    ),
                  const SizedBox(width: 8),
                  if (_supportsAct)
                    FilterChip(
                      label: const Text('Act'),
                      selected: _actMode,
                      onSelected: (v) {
                        setState(() => _actMode = v);
                        _applyConfig();
                      },
                    ),
                  FilterChip(
                    label: const Text('Flip'),
                    selected: _flip,
                    onSelected: (v) {
                      setState(() => _flip = v);
                      _applyConfig();
                    },
                  ),
                  FilterChip(
                    label: const Text('Actor'),
                    selected: _showActor,
                    onSelected: (v) {
                      setState(() => _showActor = v);
                      _applyConfig();
                    },
                  ),
                  if (_actMode)
                    FilterChip(
                      label: const Text('Target'),
                      selected: _showTarget,
                      onSelected: (v) {
                        setState(() => _showTarget = v);
                        _applyConfig();
                      },
                    ),
                  FilterChip(
                    label: const Text('Skeleton'),
                    selected: _showSkeleton,
                    onSelected: (v) {
                      setState(() => _showSkeleton = v);
                      _applyConfig();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Backdrop:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9C93B8)),
                  ),
                  for (final kind in BackdropKind.values)
                    ChoiceChip(
                      label: Text(kind.name),
                      selected: _backdrop == kind,
                      onSelected: (_) {
                        setState(() => _backdrop = kind);
                        _applyConfig();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Palette Swatches',
                style: TextStyle(fontSize: 12, color: Color(0xFF9C93B8)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Default'),
                    selected: _selectedPalette == null,
                    onSelected: (_) {
                      setState(() => _selectedPalette = null);
                      _applyConfig();
                    },
                  ),
                  for (final name in paletteNames)
                    _PaletteChip(
                      name: name,
                      colors: paletteToColors(widget.registry.palettes[name]!),
                      selected: _selectedPalette == name,
                      onSelected: () {
                        setState(() => _selectedPalette = name);
                        _applyConfig();
                      },
                    ),
                ],
              ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  final String name;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onSelected;

  const _PaletteChip({
    required this.name,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final step = (colors.length / 4).ceil().clamp(1, colors.length);
    final dots = [
      for (var i = 0; i < colors.length && i < step * 4; i += step) colors[i],
    ];
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in dots)
            Container(
              width: 7,
              height: 10,
              margin: const EdgeInsets.only(right: 1.5),
              color: c,
            ),
          const SizedBox(width: 4),
          Text(name, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
