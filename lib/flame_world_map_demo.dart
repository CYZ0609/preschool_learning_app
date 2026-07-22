// STANDALONE DEMO — not wired into the real app yet.
// Run this on its own (flutter run -t lib/flame_world_map_demo.dart) to
// tune the camera feel and hotspot positions. Once it's right, we embed
// WorldMapGame inside a normal screen in the real app via GameWidget,
// instead of replacing main.dart.
//
// Setup:
// 1. Add `flame: ^1.18.0` to pubspec.yaml (already done).
// 2. Put your map image at assets/images/world_map.png — Flame's default
//    image loader looks in assets/images/ automatically, matching your
//    existing folder.
// 3. Update WORLD_WIDTH / WORLD_HEIGHT below to your image's real pixel
//    dimensions (Flame needs to know the map's true size to compute pan
//    bounds and zoom limits correctly).
// 4. Update the `hotspots` list positions/sizes below to sit exactly over
//    your PLAINS / DESERT / FOREST signboards — the semi-transparent red
//    overlay makes them visible while you adjust; remove that once tuned.

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';

void main() {
  runApp(
    GameWidget(game: WorldMapGame()),
  );
}

/// EDIT THESE to match your actual world_map.png pixel dimensions.
const double worldWidth = 2048;
const double worldHeight = 1152;

const double minZoom = 0.6;
const double maxZoom = 2.5;

/// EDIT THESE positions/sizes to sit over your real signboards.
/// Position/size are in world-space pixels (same coordinate space as the
/// map image itself), NOT screen pixels — since these are children of the
/// map sprite, they automatically pan/zoom together with it.
final List<_HotspotDef> hotspotDefs = [
  _HotspotDef('PLAINS', Vector2(300, 500), Vector2(160, 100)),
  _HotspotDef('DESERT', Vector2(900, 350), Vector2(160, 100)),
  _HotspotDef('FOREST', Vector2(1400, 650), Vector2(160, 100)),
];

class _HotspotDef {
  final String name;
  final Vector2 position;
  final Vector2 size;
  _HotspotDef(this.name, this.position, this.size);
}

class WorldMapGame extends FlameGame with ScaleDetector {
  late final SpriteComponent mapSprite;

  // Tracks pinch/pan gesture state between onScaleStart and onScaleUpdate.
  double _startZoom = 1.0;
  Vector2 _startFocalWorldPos = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final mapSpriteImage = await images.load('world_map.png');
    mapSprite = SpriteComponent(
      sprite: Sprite(mapSpriteImage),
      size: Vector2(worldWidth, worldHeight),
      position: Vector2.zero(),
    );
    world.add(mapSprite);

    // Hotspots are added as children of the map sprite itself, so Flame's
    // component transform system automatically keeps them perfectly
    // aligned with the map through every pan/zoom — no manual coordinate
    // math needed on our part.
    for (final def in hotspotDefs) {
      mapSprite.add(BiomeHotspot(name: def.name, position: def.position, size: def.size));
    }

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(worldWidth / 2, worldHeight / 2);
    camera.viewfinder.zoom = 1.0;
  }

  /// Clamps the camera so the map's edges never scroll into view as black
  /// space. This is done manually (rather than relying solely on a single
  /// setBounds() call) so it stays correct across Flame API versions and
  /// interacts cleanly with our custom pinch-zoom handling below.
  void _clampCamera() {
    final zoom = camera.viewfinder.zoom;
    final viewSize = size / zoom; // visible world-space area at current zoom

    final halfW = viewSize.x / 2;
    final halfH = viewSize.y / 2;

    double clampedX = camera.viewfinder.position.x;
    double clampedY = camera.viewfinder.position.y;

    if (viewSize.x >= worldWidth) {
      clampedX = worldWidth / 2; // fully zoomed out horizontally — center it
    } else {
      clampedX = clampedX.clamp(halfW, worldWidth - halfW);
    }

    if (viewSize.y >= worldHeight) {
      clampedY = worldHeight / 2;
    } else {
      clampedY = clampedY.clamp(halfH, worldHeight - halfH);
    }

    camera.viewfinder.position = Vector2(clampedX, clampedY);
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _startZoom = camera.viewfinder.zoom;
    _startFocalWorldPos = camera.viewfinder.position.clone();
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // info.scale.global carries the pinch scale factor (1.0 = no change);
    // for a single-finger pan, this stays ~1.0 and info.delta carries the
    // drag movement instead — Flame's ScaleDetector unifies both gestures
    // into one callback stream, matching how Flutter's own onScale works.
    final newZoom = (_startZoom * info.scale.global.x).clamp(minZoom, maxZoom);
    camera.viewfinder.zoom = newZoom;

    // Pan: convert the screen-space drag delta into world-space movement,
    // scaled by the current zoom (so panning feels consistent regardless
    // of zoom level).
    final worldDelta = info.delta.global / newZoom;
    camera.viewfinder.position = _startFocalWorldPos - worldDelta;

    _clampCamera();
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _clampCamera();
  }
}

/// An invisible (well — semi-transparent red while tuning) tappable area
/// placed directly over a signboard on the map image.
class BiomeHotspot extends PositionComponent with TapCallbacks {
  final String name;

  BiomeHotspot({required this.name, required Vector2 position, required Vector2 size})
      : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // DEBUG OVERLAY — remove this paint once hotspot positions are tuned
    // to match your signboards exactly.
    final debugPaint = Paint()..color = const Color(0x55FF0000);
    canvas.drawRect(size.toRect(), debugPaint);
  }

  @override
  void onTapDown(TapDownEvent event) {
    // ignore: avoid_print
    print('Biome tapped: $name');
  }
}
