import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'world_map_screen.dart' show Biome;

/// EDIT to your actual world_map.png pixel dimensions.
const double _worldWidth = 2048;
const double _worldHeight = 1152;
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

class FlameWorldMapScreen extends StatelessWidget {
  final void Function(Biome biome) onEnterBiome;

  const FlameWorldMapScreen({super.key, required this.onEnterBiome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Positioned.fill (not just a bare child) — a bare GameWidget
          // inside a Stack can size to its own intrinsic size instead of
          // filling the available space, which is what caused black
          // edges on wider/taller tablet aspect ratios.
          Positioned.fill(
            child: GameWidget(
              game: WorldMapFlameGame(onEnterBiome: onEnterBiome),
              loadingBuilder: (context) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              // If onLoad() throws (e.g. world_map.png missing or not
              // declared correctly), this shows the actual error instead
              // of the game silently appearing frozen/unresponsive.
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

/// Everything — pan, pinch-zoom, AND tap-to-select-biome — goes through
/// this single ScaleDetector. Mixing a second, separate Flame gesture
/// system (TapCallbacks on child components) alongside it caused the two
/// to compete in the gesture arena, which is what made taps flaky. A
/// single source of truth for all touch input avoids that entirely.
class WorldMapFlameGame extends FlameGame with ScaleDetector {
  final void Function(Biome biome) onEnterBiome;
  WorldMapFlameGame({required this.onEnterBiome});

  late final SpriteComponent mapSprite;
  final List<_HotspotVisual> hotspotVisuals = [];

  double _startZoom = 1.0;
  Vector2 _lastFocalScreenPos = Vector2.zero();
  Vector2 _gestureStartScreenPos = Vector2.zero();
  double _totalMovement = 0; // accumulated screen-space movement this gesture
  static const double _tapMovementThreshold = 8; // px — below this, treat as a tap not a pan

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    late final ui.Image mapSpriteImage;
    try {
      mapSpriteImage = await images.load('world_map.png');
      debugPrint('[WorldMap] world_map.png loaded successfully.');
    } catch (e) {
      debugPrint('[WorldMap] FAILED to load world_map.png: $e');
      debugPrint('[WorldMap] Check: file exists at assets/images/world_map.png, '
          'and you ran flutter pub get after adding it.');
      rethrow; // surfaces in GameWidget's errorBuilder instead of failing silently
    }

    mapSprite = SpriteComponent(
      sprite: Sprite(mapSpriteImage),
      size: Vector2(_worldWidth, _worldHeight),
      position: Vector2.zero(),
    );
    world.add(mapSprite);

    // Hotspots are purely visual here (debug red boxes) — tap detection
    // for them is handled centrally below, not via their own TapCallbacks.
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

  /// Converts a screen-space point (e.g. a tap position) into world-space
  /// coordinates, given the camera's current pan/zoom. Since the
  /// viewfinder's anchor is Anchor.center, viewfinder.position maps to
  /// the exact center of the screen.
  Vector2 _screenToWorld(Vector2 screenPoint) {
    final screenCenter = size / 2;
    final offsetFromCenter = (screenPoint - screenCenter) / camera.viewfinder.zoom;
    return camera.viewfinder.position + offsetFromCenter;
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _startZoom = camera.viewfinder.zoom;
    _lastFocalScreenPos = info.eventPosition.global.clone();
    _gestureStartScreenPos = info.eventPosition.global.clone();
    _totalMovement = 0;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final currentScreenPos = info.eventPosition.global;

    // PAN — accumulate incrementally frame-to-frame (this is the fix:
    // previously this subtracted only the latest incremental delta from a
    // FIXED start position every frame, which barely moved the camera).
    final screenDelta = currentScreenPos - _lastFocalScreenPos;
    _totalMovement += screenDelta.length;

    final newZoom = (_startZoom * info.scale.global.x).clamp(_minZoom, _maxZoom);
    camera.viewfinder.zoom = newZoom;

    final worldDelta = screenDelta / newZoom;
    camera.viewfinder.position = camera.viewfinder.position - worldDelta;

    _clampCamera();
    _lastFocalScreenPos = currentScreenPos.clone();
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _clampCamera();

    // A gesture that barely moved is a TAP, not a pan/pinch. Check it
    // against every hotspot's world-space rect.
    if (_totalMovement < _tapMovementThreshold) {
      final worldPoint = _screenToWorld(_gestureStartScreenPos);
      for (final def in _hotspotDefs) {
        if (def.contains(worldPoint)) {
          onEnterBiome(def.biome);
          break;
        }
      }
    }
  }
}

/// Purely visual debug rectangle over a signboard — no tap handling of
/// its own; see WorldMapFlameGame's unified onScaleEnd for tap detection.
class _HotspotVisual extends PositionComponent {
  _HotspotVisual({required Vector2 position, required Vector2 size}) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // DEBUG OVERLAY — comment this out once hotspots are tuned to your signboards.
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0x55FF0000));
  }
}
