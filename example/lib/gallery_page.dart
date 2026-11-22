// Main dark pixel-studio gallery grid browsing registered PixelFx extensions and assets.

import 'package:material_ui/material_ui.dart';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_flutter/pixelfx_flutter.dart';

import 'effect_detail_dialog.dart';

class GalleryPage extends StatefulWidget {
  final PixelFxRegistry registry;

  const GalleryPage({super.key, required this.registry});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedExtensionId;
  String? _selectedCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PixelAsset> get _filteredAssets {
    final terms = _query
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    return widget.registry.search(
      terms,
      category: _selectedCategory,
      extensionId: _selectedExtensionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allAssets = widget.registry.assets;
    final filtered = _filteredAssets;
    final categories = <String>{
      for (final a in allAssets)
        if (a.meta.category.isNotEmpty) a.meta.category,
    }.toList()
      ..sort();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(allAssets.length, filtered.length, categories),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching pixel assets.',
                        style: TextStyle(color: Color(0xFF9C93B8)),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final cols =
                            (constraints.maxWidth / 225).floor().clamp(1, 6);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.92,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final asset = filtered[index];
                            return _AssetCard(
                              asset: asset,
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (_) => EffectDetailDialog(
                                  asset: asset,
                                  registry: widget.registry,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int total, int shown, List<String> categories) {
    final exts = widget.registry.extensions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFFFAE35)),
              const SizedBox(width: 8),
              const Text(
                'PixelFx Gallery',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF3EEFF),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1B2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF362F4D)),
                ),
                child: Text(
                  '$shown / $total assets',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF58F2C8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search effects, tags, categories...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.clear, size: 16),
                          ),
                    filled: true,
                    fillColor: const Color(0xFF171422),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2E2842)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (exts.length > 1) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Extensions'),
                    selected: _selectedExtensionId == null,
                    onSelected: (_) =>
                        setState(() => _selectedExtensionId = null),
                  ),
                  const SizedBox(width: 6),
                  for (final ext in exts) ...[
                    ChoiceChip(
                      label: Text(ext.manifest.name),
                      selected: _selectedExtensionId == ext.manifest.id,
                      onSelected: (_) => setState(
                        () => _selectedExtensionId = ext.manifest.id,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 6),
                for (final cat in categories) ...[
                  ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final PixelAsset asset;
  final VoidCallback onTap;

  const _AssetCard({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = asset.meta;
    final hasAct = asset is PixelEffect && (asset as PixelEffect).act != null;

    return Card(
      key: Key('asset-card-${m.id}'),
      color: const Color(0xFF171422),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2A253A)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: const Color(0xFF0A0810),
                    child: RepaintBoundary(
                      child: PixelFxView(
                        asset: asset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFFF3EEFF),
                      ),
                    ),
                  ),
                  if (hasAct)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF33214A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF8C4DE8)),
                      ),
                      child: const Text(
                        'ACT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD9B8FF),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${m.id}  •  ${m.width}x${m.height}  •  ${m.loop ? "LOOP" : "1-SHOT"}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF8F86A8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
