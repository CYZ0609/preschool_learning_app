import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'world_map_screen.dart' show Biome;

/// Real world_map.png pixel dimensions.
const double _worldWidth = 2816;
const double _worldHeight = 1536;
const double _minZoom = 0.6;
const double _maxZoom = 2.5;

/// EDIT these positions/sizes to sit exactly over your signboards.
final List<_HotspotDef> _hotspotDefs = [
  _HotspotDef(Biome.outdoorField, Vector2(300, 500), Vector2(160, 100)),
  _HotspotDef(Biome.desert, Vector2(900, 350), Vector2(160, 100)),
  _HotspotDef(Biome.forest, Vector2(1400, 650), Vector2(160, 100)),
  _HotspotDef(Biome.indoorHome, Vector2(500, 200), Vector2(160, 100)),
  _HotspotDef(Biome.snowPolar, Vector2(1700, 300), Vector2(160, 100)),
  _HotspotDef(Biome.ocean, Vector2(1800, 800), Vector2(160, 100)),
  _HotspotDef(Biome.space, Vector2(1000, 100), Vector2(160, 100)),
];

class _HotspotDef {
  final Biome biome;
  final Vector2 position; // top-left, world-space
  final Vector2 size;
  _HotspotDef(this.biome, this.position, this.size);

  bool contains(Vector2 worldPoint) {
    return worldPoint.x >= position.x &&
        worldPoint.x <= position.x + size.x &&
        worldPoint.y >= position.y &&
        worldPoint.y <= position.y + size.y;
  }
}

/// Real screen wrapper. IMPORTANT: pan/zoom/tap are now driven by a plain
/// Flutter GestureDetector wrapping the GameWidget, NOT by Flame's own
/// ScaleDetector mixin. Testing showed Flame's mixin-based gesture
/// dispatch never fired at all in this project's setup (debug logs
/// confirmed zero callbacks despite dragging/tapping) — rather than debug
/// Flame's internal wiring blind, we use Flutter's own well-understood
/// GestureDetector and manually forward the events into the game via
/// plain public methods. This is a standard, reliable pattern.
class FlameWorldMapScreen extends StatefulWidget {
  final void Function(Biome biome) onEnterBiome;

  const FlameWorldMapScreen({super.key, required this.onEnterBiome});

  @override
  State<FlameWorldMapScreen> createState() => _FlameWorldMapScreenState();
}

class _FlameWorldMapScreenState extends State<FlameWorldMapScreen> {
  late final WorldMapFlameGame game;

  @override
  void initState() {
    super.initState();
    game = WorldMapFlameGame(onEnterBiome: widget.onEnterBiome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // ensures empty/transparent areas still receive touches
              onScaleStart: (details) {
                debugPrint('[WorldMap] Flutter GestureDetector: onScaleStart at ${details.focalPoint}');
                game.handleScaleStart(Vector2(details.focalPoint.dx, details.focalPoint.dy));
              },
              onScaleUpdate: (details) {
                game.handleScaleUpdate(
                  Vector2(details.focalPoint.dx, details.focalPoint.dy),
                  details.scale,
                );
                setState(() {}); // refresh the on-screen camera pos readout
              },
              onScaleEnd: (details) {
                debugPrint('[WorldMap] Flutter GestureDetector: onScaleEnd');
                game.handleScaleEnd();
                setState(() {});
              },
              child: GameWidget(
                game: game,
                loadingBuilder: (context) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load the world map:\n$error\n\n'
                      'Check that assets/images/world_map.png exists and '
                      'that you ran flutter pub get after adding it.',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
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

class WorldMapFlameGame extends FlameGame {
  final void Function(Biome biome) onEnterBiome;
  WorldMapFlameGame({required this.onEnterBiome});

  late final SpriteComponent mapSprite;
  final List<_HotspotVisual> hotspotVisuals = [];

  double _startZoom = 1.0;
  Vector2 _lastFocalScreenPos = Vector2.zero();
  Vector2 _gestureStartScreenPos = Vector2.zero();
  double _totalMovement = 0;
  static const double _tapMovementThreshold = 8;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    late final ui.Image mapSpriteImage;
    try {
      mapSpriteImage = await images.load('world_map.png');
      debugPrint('[WorldMap] world_map.png loaded successfully.');
    } catch (e) {
      debugPrint('[WorldMap] FAILED to load world_map.png: $e');
      rethrow;
    }

    mapSprite = SpriteComponent(
      sprite: Sprite(mapSpriteImage),
      size: Vector2(_worldWidth, _worldHeight),
      position: Vector2.zero(),
    );
    world.add(mapSprite);

    for (final def in _hotspotDefs) {
      final visual = _HotspotVisual(position: def.position, size: def.size);
      hotspotVisuals.add(visual);
      mapSprite.add(visual);
    }

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(_worldWidth / 2, _worldHeight / 2);
    camera.viewfinder.zoom = 1.0;
  }

  void _clampCamera() {
    final zoom = camera.viewfinder.zoom;
    final viewSize = size / zoom;
    final halfW = viewSize.x / 2;
    final halfH = viewSize.y / 2;

    double clampedX = camera.viewfinder.position.x;
    double clampedY = camera.viewfinder.position.y;

    clampedX = viewSize.x >= _worldWidth ? _worldWidth / 2 : clampedX.clamp(halfW, _worldWidth - halfW);
    clampedY = viewSize.y >= _worldHeight ? _worldHeight / 2 : clampedY.clamp(halfH, _worldHeight - halfH);

    camera.viewfinder.position = Vector2(clampedX, clampedY);
  }

  Vector2 _screenToWorld(Vector2 screenPoint) {
    final screenCenter = size / 2;
    final offsetFromCenter = (screenPoint - screenCenter) / camera.viewfinder.zoom;
    return camera.viewfinder.position + offsetFromCenter;
  }

  // --- Public methods, called directly by the wrapping Flutter GestureDetector ---

  void handleScaleStart(Vector2 screenPos) {
    _startZoom = camera.viewfinder.zoom;
    _lastFocalScreenPos = screenPos.clone();
    _gestureStartScreenPos = screenPos.clone();
    _totalMovement = 0;
  }

  void handleScaleUpdate(Vector2 screenPos, double scale) {
    final screenDelta = screenPos - _lastFocalScreenPos;
    _totalMovement += screenDelta.length;

    final newZoom = (_startZoom * scale).clamp(_minZoom, _maxZoom);
    camera.viewfinder.zoom = newZoom;

    final worldDelta = screenDelta / newZoom;
    camera.viewfinder.position = camera.viewfinder.position - worldDelta;

    _clampCamera();
    _lastFocalScreenPos = screenPos.clone();
  }

  void handleScaleEnd() {
    _clampCamera();
    if (_totalMovement < _tapMovementThreshold) {
      final worldPoint = _screenToWorld(_gestureStartScreenPos);
      debugPrint('[WorldMap] Treated as TAP at world position: $worldPoint');
      bool hit = false;
      for (final def in _hotspotDefs) {
        if (def.contains(worldPoint)) {
          debugPrint('[WorldMap] HIT hotspot: ${def.biome}');
          hit = true;
          onEnterBiome(def.biome);
          break;
        }
      }
      if (!hit) debugPrint('[WorldMap] Tap did not land on any hotspot.');
    }
  }
}

class _HotspotVisual extends PositionComponent {
  _HotspotVisual({required Vector2 position, required Vector2 size}) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // DEBUG OVERLAY — comment this out once hotspots are tuned to your signboards.
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0x55FF0000));
  }
}
