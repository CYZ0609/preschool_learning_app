import 'package:flutter/material.dart';
import 'world_map_screen.dart' show Biome;

/// Real world_map.png pixel dimensions.
const double _worldWidth = 2816;
const double _worldHeight = 1536;

/// EDIT these positions/sizes to sit exactly over your signboards.
final List<_HotspotDef> _hotspotDefs = [
  _HotspotDef(Biome.outdoorField, const Offset(300, 500), const Size(160, 100)),
  _HotspotDef(Biome.desert, const Offset(900, 350), const Size(160, 100)),
  _HotspotDef(Biome.forest, const Offset(1400, 650), const Size(160, 100)),
  _HotspotDef(Biome.indoorHome, const Offset(500, 200), const Size(160, 100)),
  _HotspotDef(Biome.snowPolar, const Offset(1700, 300), const Size(160, 100)),
  _HotspotDef(Biome.ocean, const Offset(1800, 800), const Size(160, 100)),
  _HotspotDef(Biome.space, const Offset(1000, 100), const Size(160, 100)),
];

class _HotspotDef {
  final Biome biome;
  final Offset position; // top-left, world-space
  final Size size;
  _HotspotDef(this.biome, this.position, this.size);
}

/// Real screen wrapper.
///
/// Pan/zoom is handled entirely by Flutter's built-in [InteractiveViewer] —
/// no Flame GameWidget, no custom gesture forwarding. This sidesteps the
/// entire class of gesture-arena / touch-delivery problems this project
/// has been hitting with GameWidget specifically. Hotspots are plain
/// [Positioned] + [GestureDetector] widgets sitting on top of the map
/// image, inside the same InteractiveViewer, so they pan/zoom with it for
/// free and use completely standard Flutter tap handling.
class FlameWorldMapScreen extends StatefulWidget {
  final void Function(Biome biome) onEnterBiome;

  const FlameWorldMapScreen({super.key, required this.onEnterBiome});

  @override
  State<FlameWorldMapScreen> createState() => _FlameWorldMapScreenState();
}

class _FlameWorldMapScreenState extends State<FlameWorldMapScreen> {
  final TransformationController _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    // Center the view on the map initially.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;
      final dx = (_worldWidth / 2) - screenSize.width / 2;
      final dy = (_worldHeight / 2) - screenSize.height / 2;
      _controller.value = Matrix4.identity()..translate(-dx, -dy);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 172, 41, 41),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.4,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(200),
              constrained: false,
              child: SizedBox(
                width: _worldWidth,
                height: _worldHeight,
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/world_map.png',
                      width: _worldWidth,
                      height: _worldHeight,
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('[WorldMap] FAILED to load world_map.png: $error');
                        return Container(
                          width: _worldWidth,
                          height: _worldHeight,
                          color: const Color(0xFF2E7D32),
                          alignment: Alignment.center,
                          child: const Text(
                            'world_map.png failed to load.\nCheck assets/images/world_map.png\nand pubspec.yaml assets section.',
                            style: TextStyle(color: Colors.white, fontSize: 20),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                    for (final def in _hotspotDefs)
                      Positioned(
                        left: def.position.dx,
                        top: def.position.dy,
                        width: def.size.width,
                        height: def.size.height,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            debugPrint('[WorldMap] Tapped hotspot: ${def.biome}');
                            widget.onEnterBiome(def.biome);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0x55FF0000), // DEBUG overlay — remove once tuned to your signboards
                              border: Border.all(color: Colors.red, width: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
