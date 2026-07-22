import 'package:flutter/material.dart';

enum Biome { outdoorField, indoorHome, forest, desert, snowPolar, ocean, space }

extension BiomeInfo on Biome {
  String get label {
    switch (this) {
      case Biome.outdoorField: return 'OUTDOOR FIELD';
      case Biome.indoorHome: return 'HOME';
      case Biome.forest: return 'FOREST';
      case Biome.desert: return 'DESERT';
      case Biome.snowPolar: return 'SNOW';
      case Biome.ocean: return 'OCEAN';
      case Biome.space: return 'SPACE';
    }
  }

  String get emoji {
    switch (this) {
      case Biome.outdoorField: return '🌾';
      case Biome.indoorHome: return '🏡';
      case Biome.forest: return '🌲';
      case Biome.desert: return '🏜️';
      case Biome.snowPolar: return '❄️';
      case Biome.ocean: return '🌊';
      case Biome.space: return '🚀';
    }
  }

  Color get color {
    switch (this) {
      case Biome.outdoorField: return const Color(0xFF8BC34A);
      case Biome.indoorHome: return const Color(0xFFD7A86E);
      case Biome.forest: return const Color(0xFF2E7D32);
      case Biome.desert: return const Color(0xFFE0B84C);
      case Biome.snowPolar: return const Color(0xFFB3E5FC);
      case Biome.ocean: return const Color(0xFF29B6F6);
      case Biome.space: return const Color(0xFF37474F);
    }
  }

  // Real floor art per biome, provided by the teacher/dev.
  String get floorAsset {
    switch (this) {
      case Biome.outdoorField: return 'assets/images/bg_plains.png';
      case Biome.indoorHome: return 'assets/images/bg_city.png';
      case Biome.forest: return 'assets/images/bg_forest.png';
      case Biome.desert: return 'assets/images/bg_desert.png';
      case Biome.snowPolar: return 'assets/images/bg_snow.png';
      case Biome.ocean: return 'assets/images/bg_ocean.png';
      case Biome.space: return 'assets/images/bg_space.png';
    }
  }

  // Fractional position (0.0-1.0) on the 2048x1080 world map.
  Offset get mapPosition {
    switch (this) {
      case Biome.outdoorField: return const Offset(0.15, 0.55);
      case Biome.indoorHome: return const Offset(0.30, 0.30);
      case Biome.forest: return const Offset(0.48, 0.65);
      case Biome.desert: return const Offset(0.65, 0.35);
      case Biome.snowPolar: return const Offset(0.80, 0.60);
      case Biome.ocean: return const Offset(0.90, 0.25);
      case Biome.space: return const Offset(0.50, 0.15);
    }
  }
}

/// Phase 1: the macro world map. A bounded, pannable/zoomable illustrated
/// map with 7 biome hotspots. Tapping a biome does NOT immediately
/// navigate — it highlights the biome and reveals a [GO!] button, so a
/// stray/accidental tap never yanks a toddler into the wrong scene.
class WorldMapScreen extends StatefulWidget {
  final String ageGroup;
  final String kidId;
  final void Function(Biome biome) onEnterBiome;

  const WorldMapScreen({
    super.key,
    required this.ageGroup,
    required this.kidId,
    required this.onEnterBiome,
  });

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  Biome? selectedBiome;
  final TransformationController _controller = TransformationController();

  static const double worldWidth = 2048;
  static const double worldHeight = 1080;

  void _selectBiome(Biome biome) {
    setState(() => selectedBiome = biome);
  }

  void _clearSelection() {
    setState(() => selectedBiome = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1B2B),
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              // Tapping empty space clears the selection — the doc's
              // "anti-accidental touch" requirement.
              onTap: _clearSelection,
              child: InteractiveViewer(
                transformationController: _controller,
                boundaryMargin: EdgeInsets.zero, // hard-stop at world edges
                minScale: 1.0,
                maxScale: 2.5,
                child: SizedBox(
                  width: worldWidth,
                  height: worldHeight,
                  child: Stack(
                    children: [
                      // Placeholder world background — replace with a real
                      // illustrated panoramic map asset when available.
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1B3A2E), Color(0xFF2D5A3D), Color(0xFF1B3A2E)],
                          ),
                        ),
                      ),
                      for (final biome in Biome.values)
                        Positioned(
                          left: biome.mapPosition.dx * worldWidth - 60,
                          top: biome.mapPosition.dy * worldHeight - 60,
                          child: GestureDetector(
                            onTap: () => _selectBiome(biome),
                            child: _BiomeHotspot(
                              biome: biome,
                              isSelected: selectedBiome == biome,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // GO! confirm button — only appears once a biome is selected.
            if (selectedBiome != null)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedBiome!.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => widget.onEnterBiome(selectedBiome!),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4DD9C0),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF4DD9C0).withOpacity(0.6), blurRadius: 24, spreadRadius: 4),
                            ],
                          ),
                          child: const Center(
                            child: Text('GO!\n🚀', textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BiomeHotspot extends StatelessWidget {
  final Biome biome;
  final bool isSelected;
  const _BiomeHotspot({required this.biome, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: biome.color.withOpacity(isSelected ? 0.95 : 0.75),
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: Colors.amberAccent, width: 4)
            : Border.all(color: Colors.white24, width: 2),
        boxShadow: isSelected
            ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.6), blurRadius: 20, spreadRadius: 4)]
            : [],
      ),
      child: Center(
        child: Text(biome.emoji, style: const TextStyle(fontSize: 48)),
      ),
    );
  }
}
