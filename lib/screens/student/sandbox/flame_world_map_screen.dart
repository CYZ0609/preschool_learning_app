import 'package:flutter/material.dart';
import 'world_map_screen.dart' show Biome;
import 'package:flutter/material.dart';
import 'world_map_screen.dart' show Biome;
import '../../../widgets/jelly_button.dart'; // ✨ 新增这一行（请根据你的实际文件夹层级调整路径）

/// Real world_map.png pixel dimensions.
const double _worldWidth = 2816;
const double _worldHeight = 1536;

/// ⚠️ 注意：如果你发现“点雪地进了沙漠”，说明这里的 Offset 坐标和你的图片对不上。
/// 请根据你的图片，调整这里的 Offset(X, Y)。X是左右，Y是上下。
/// 我已经把 Size 从 (160, 100) 放大到了 (300, 200)，让用户更容易点到。
/// 采用“全区域覆盖”模式。
/// 基于 2816 x 1536 的总尺寸，把整张地图划分成了几个大的点击区块。
final List<_HotspotDef> _hotspotDefs = [
  // 1. 雪地 (左上角) - 采用你的完美参数
  _HotspotDef(Biome.snowPolar, const Offset(50, 100), const Size(700, 500)),
  
  // 2. 森林 (左下角) - 接在雪地下面，覆盖左边所有的绿树和废墟
  _HotspotDef(Biome.forest, const Offset(50, 650), const Size(800, 800)),
  
  // 3. 城镇/家里 (中上方) - 覆盖中间的马路、房子和学校
  _HotspotDef(Biome.indoorHome, const Offset(800, 50), const Size(1000, 600)),
  
  // 4. 平原 (中下方) - 覆盖中间的农田、河流和草地
  _HotspotDef(Biome.outdoorField, const Offset(900, 650), const Size(850, 800)),
  
  // 5. 太空 (右上角) - 覆盖右上角的灰色基地和火箭
  _HotspotDef(Biome.space, const Offset(1850, 50), const Size(900, 500)),
  
  // 6. 沙漠 (右侧中间) - 覆盖整个黄沙、绿洲和骆驼区域
  _HotspotDef(Biome.desert, const Offset(1800, 550), const Size(950, 500)),
  
  // 7. 海洋 (右下角) - 覆盖右下角的水域、灯塔和沙滩
  _HotspotDef(Biome.ocean, const Offset(1800, 1050), const Size(950, 450)),
];

class _HotspotDef {
  final Biome biome;
  final Offset position; // top-left, world-space
  final Size size;
  _HotspotDef(this.biome, this.position, this.size);
}

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
    debugPrint('[WorldMap] FlameWorldMapScreen initState — map screen created');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✨ 新增安全检查：防止页面快速关闭时调用 context 报错
      if (!mounted) return;
      
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
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
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
                        // ✨ 新增 cacheWidth，将原图解码分辨率压到一半，防止内存溢出和主线程卡死
                        cacheWidth: (_worldWidth ~/ 2).toInt(),
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
                              decoration: const BoxDecoration(
                                // ✨ 透明点击区域
                                color: Colors.transparent,
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
    child: JellyButton(
      color: const Color(0xFFFFAB40), // 依然使用充满活力的暖橘色
      onTap: () => Navigator.pop(context),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_rounded, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text(
            'Home',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  ),
),
          ],
        ),
      ),
    );
  }
}