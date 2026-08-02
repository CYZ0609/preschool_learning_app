import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/lesson_service.dart';
import '../../../services/build_mode_service.dart';
import '../../../services/unlock_service.dart';
import '../../../services/vocab_seen_service.dart';
import '../../../services/sandbox_item_service.dart';
import '../../../data/default_map_words.dart';
import '../../../widgets/jelly_button.dart';
import '../../../widgets/word_image.dart';
import 'world_map_screen.dart';

/// One roaming creature on the grid — always a placed item whose word has
/// `isMovable: true` (e.g. a teacher adds "farmer" with isMovable checked,
/// and once a child places it, it wanders the grid). There is no ambient
/// wildlife; movement only ever comes from placed items.
class _RoamingEntity {
  double gridX, gridY;
  bool facingRight = true;
  final PlacedItem placedItem; // identity key back to the real placed item
  _RoamingEntity({required this.gridX, required this.gridY, required this.placedItem});
}

class BiomeSandboxScreen extends StatefulWidget {
  final Biome biome;
  final Lesson lesson;
  final String kidId;
  final Future<void> Function(LessonWord word) onOpenWord;

  const BiomeSandboxScreen({
    super.key,
    required this.biome,
    required this.lesson,
    required this.kidId,
    required this.onOpenWord,
  });

  @override
  State<BiomeSandboxScreen> createState() => _BiomeSandboxScreenState();
}

class _BiomeSandboxScreenState extends State<BiomeSandboxScreen> {
 
  static const int gridCols = 40;
  static const int gridRows = 40;
  static const double cellSize = 96;

  final Random rand = Random();
  Timer? _roamTimer;
  final TransformationController _viewController = TransformationController();

  bool buildMode = false;
  bool bgFailed = false;
  bool _initialTransformSet = false; // guards the LayoutBuilder one-time camera lock
  bool _hasNewContent = false;      
  bool _hideUI = false; 
  List<String> unlockedWords = [];
  List<PlacedItem> placedItems = [];
  List<LessonWord> _globalItems = [];
  String? selectedItemId;
  final GlobalKey _gridKey = GlobalKey();

  // 用于记录拖拽虚影坐标的变量
  int? _hoverX;
  int? _hoverY;

  final Map<PlacedItem, _RoamingEntity> _movableRuntimes = {};

  double _minScaleFor(Size viewport) {
    final fitX = viewport.width / (gridCols * cellSize);
    final fitY = viewport.height / (gridRows * cellSize);
    return fitX > fitY ? fitX : fitY;
  }

  List<LessonWord> _globalCatalog() {
    final builtIn = <LessonWord>[
      ...defaultMapWordsFor('4-5'),
      ...defaultMapWordsFor('5-6'),
      ...defaultMapWordsFor('6-7'),
    ];
    final withGlobals = mergeCustomVocabulary(builtIn: builtIn, custom: _globalItems);
    return mergeCustomVocabulary(builtIn: withGlobals, custom: widget.lesson.words);
  }

  @override
  void initState() {
    super.initState();
    _roamTimer = Timer.periodic(const Duration(seconds: 2, milliseconds: 500), (_) => _stepEntities());
    _loadGlobalItems();
    _loadBuildMode();
    _checkNewContent();
  }

  Future<void> _loadGlobalItems() async {
    try {
      final items = await SandboxItemService.loadGlobalItems();
      if (!mounted) return;
      setState(() => _globalItems = items);
      _syncMovableRuntimes();
    } catch (e) {
      debugPrint('[BiomeSandbox] Failed to load global sandbox items: $e');
    }
  }

  Future<void> _loadBuildMode() async {
    final unlocked = await UnlockService.loadUnlockedWords(widget.kidId);
    final saved = await BuildModeService.loadPlacements(widget.kidId, widget.biome.name);
    if (!mounted) return;
    setState(() {
      unlockedWords = unlocked;
      placedItems = saved;
    });
    _syncMovableRuntimes();
  }

  Future<void> _checkNewContent() async {
    final catalogWords = _globalCatalog().map((w) => w.word).toSet();
    final seen = await VocabSeenService.loadSeenWords(widget.kidId);
    final newOnes = catalogWords.difference(seen);
    if (!mounted) return;
    setState(() => _hasNewContent = newOnes.isNotEmpty);
  }

  LessonWord? _wordFor(String itemId) {
    try {
      return widget.lesson.words.firstWhere((w) => w.word == itemId);
    } catch (_) {}

    // 2. 优先级其次：检查老师在后台设置的全局物品（这能成功覆盖掉系统默认的树和石头）
    try {
      return _globalItems.firstWhere((w) => w.word == itemId);
    } catch (_) {}

    // 3. 优先级最低：如果老师没改过，才使用系统自带的默认属性
    try {
      return _globalCatalog().firstWhere((w) => w.word == itemId);
    } catch (_) {
      return null;
    }
  }

  // ✨ 动态读取物品尺寸
  int _getItemGridSpan(String itemId) {
    final word = _wordFor(itemId);
    
    // 如果模型里读取到了后台设置的 width，就优先用后台的尺寸
    if (word != null && word.width != null && word.width! > 0) {
      return word.width!;
    }
    
    // 兜底逻辑：如果后台没设，再用默认值
    if (itemId == 'TREE') return 7; 
    if (itemId == 'SUN') return 9; 
    return 3;
  }

  // ✨ 新增：动态读取物品放大倍数
  double _getItemScale(String itemId) {
    // 之后如果你在 LessonWord 数据库里也加了 scale 字段，可以解除下面这两行的注释来读取：
    // final word = _wordFor(itemId);
    // if (word != null && word.scale != null) return word.scale!;
    
    // 目前先统一默认放大 1.6 倍，你可以随意改这个数字看看效果[cite: 2]
    return 2.0; 
  }

  Set<String> _computeObstacleCells() {
    final obstacles = <String>{};
    for (final p in placedItems) {
      final word = _wordFor(p.itemId);
      if (word != null && !word.isPassable) {
        final span = _getItemGridSpan(p.itemId);
        for (int dx = 0; dx < span; dx++) {
          for (int dy = 0; dy < span; dy++) {
            obstacles.add('${p.gridX.round() + dx},${p.gridY.round() + dy}');
          }
        }
      }
    }
    return obstacles;
  }

  bool _isBlockedFor(int x, int y, Set<String> obstacles) {
    if (x < 0 || x >= gridCols || y < 0 || y >= gridRows) return true;
    return obstacles.contains('$x,$y');
  }

  void _stepEntities() {
    final obstacles = _computeObstacleCells();
    setState(() {
      for (final entity in _movableRuntimes.values) {
        final dir = rand.nextInt(4);
        int dx = 0, dy = 0;
        switch (dir) {
          case 0: dx = 1; break;
          case 1: dx = -1; break;
          case 2: dy = 1; break;
          case 3: dy = -1; break;
        }
        final targetX = entity.gridX.round() + dx;
        final targetY = entity.gridY.round() + dy;
        if (!_isBlockedFor(targetX, targetY, obstacles)) {
          entity.gridX = targetX.toDouble();
          entity.gridY = targetY.toDouble();
          if (dx != 0) entity.facingRight = dx > 0;
        }
      }
    });
  }

  void _syncMovableRuntimes() {
    final movableNow = placedItems.where((p) => _wordFor(p.itemId)?.isMovable == true).toSet();
    _movableRuntimes.removeWhere((p, _) => !movableNow.contains(p));
    for (final p in movableNow) {
      _movableRuntimes.putIfAbsent(p, () => _RoamingEntity(gridX: p.gridX, gridY: p.gridY, placedItem: p));
    }
  }

  Future<void> _placeItemAt(String itemId, int gridX, int gridY) async {
    debugPrint('[BiomeSandbox] _placeItemAt called: $itemId at ($gridX, $gridY)');
    
    final clampedX = gridX.clamp(0, gridCols - 1);
    final clampedY = gridY.clamp(0, gridRows - 1);

    final word = _wordFor(itemId);
    if (word == null) {
      debugPrint('[BiomeSandbox] WARNING: no LessonWord found for itemId "$itemId" — placing anyway.');
    }

    setState(() {
      placedItems.add(PlacedItem(itemId: itemId, gridX: clampedX.toDouble(), gridY: clampedY.toDouble()));
    });
    _syncMovableRuntimes();

    try {
      await BuildModeService.savePlacements(widget.kidId, widget.biome.name, placedItems);
    } catch (e, stack) {
      debugPrint('[BiomeSandbox] Failed to save placement for "$itemId": $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> _packUpItem(PlacedItem item) async {
    setState(() {
      placedItems.remove(item);
    });
    _syncMovableRuntimes();
    await BuildModeService.savePlacements(widget.kidId, widget.biome.name, placedItems);
  }

  @override
  void dispose() {
    _roamTimer?.cancel();
    _viewController.dispose();
    super.dispose();
  }

  void _openInventoryModal() {
    final catalog = _globalCatalog();
    VocabSeenService.markWordsSeen(widget.kidId, catalog.map((w) => w.word));
    setState(() => _hasNewContent = false);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _InventoryModal(
        catalog: catalog,
        unlockedWords: unlockedWords,
        onTapLocked: (word) async {
          Navigator.pop(context);
          setState(() => _hideUI = true);
          await widget.onOpenWord(word);
          if (mounted) {
            setState(() => _hideUI = false);
           
            await _loadBuildMode();
          }
        },
        onTapUnlocked: (word) {
          Navigator.pop(context);
          setState(() => selectedItemId = word.word);
        },
      ),
    );
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Return to main map?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.biggest;

            if (!_initialTransformSet && viewport.isFinite && viewport.width > 0 && viewport.height > 0) {
              _initialTransformSet = true;
              final scale = _minScaleFor(viewport);
              // 镜头自动聚焦到地图正中心
              final dx = (gridCols / 2) * cellSize - (viewport.width / 2) / scale;
              final dy = (gridRows / 2) * cellSize - (viewport.height / 2) / scale;
              _viewController.value = Matrix4.identity()
                ..scale(scale, scale, scale)
                ..translate(-dx, -dy);
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _viewController,
                    minScale: _minScaleFor(viewport),
                    maxScale: 2.5,
                    boundaryMargin: EdgeInsets.zero,
                    constrained: false,
                    child: DragTarget<String>(
                      onWillAcceptWithDetails: (_) => true,
                      
                      onMove: (details) {
                        final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final local = renderBox.globalToLocal(details.offset);
                        final gridX = (local.dx / cellSize).floor();
                        final gridY = (local.dy / cellSize).floor();
                        
                        if (_hoverX != gridX || _hoverY != gridY) {
                          setState(() {
                            _hoverX = gridX;
                            _hoverY = gridY;
                          });
                        }
                      },
                      
                      onLeave: (_) {
                        setState(() {
                          _hoverX = null;
                          _hoverY = null;
                        });
                      },
                      
                      onAcceptWithDetails: (details) {
                        setState(() {
                          _hoverX = null;
                          _hoverY = null;
                        });

                        final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final local = renderBox.globalToLocal(details.offset);
                        final gridX = (local.dx / cellSize).floor();
                        final gridY = (local.dy / cellSize).floor();
                        _placeItemAt(details.data, gridX, gridY);
                      },
                      builder: (context, candidateData, rejectedData) {
                        return SizedBox(
                          key: _gridKey,
                          width: gridCols * cellSize,
                          height: gridRows * cellSize,
                          child: Stack(
                            children: [
                              bgFailed
                                  ? CustomPaint(
                                      size: Size(gridCols * cellSize, gridRows * cellSize),
                                      painter: _TerrainPainter(biome: widget.biome, cols: gridCols, rows: gridRows, cellSize: cellSize, showGrid: buildMode),
                                    )
                                  : Image.asset(
                                      widget.biome.floorAsset,
                                      width: gridCols * cellSize,
                                      height: gridRows * cellSize,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted && !bgFailed) setState(() => bgFailed = true);
                                        });
                                        return CustomPaint(
                                          size: Size(gridCols * cellSize, gridRows * cellSize),
                                          painter: _TerrainPainter(biome: widget.biome, cols: gridCols, rows: gridRows, cellSize: cellSize, showGrid: buildMode),
                                        );
                                      },
                                    ),
                              if (buildMode && !bgFailed)
                                CustomPaint(
                                  size: Size(gridCols * cellSize, gridRows * cellSize),
                                  painter: _GridLinesPainter(cols: gridCols, rows: gridRows, cellSize: cellSize),
                                ),
                            
                              // Movable placed items
                              for (final entry in _movableRuntimes.entries)
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeInOut,
                                  left: entry.value.gridX * cellSize,
                                  top: entry.value.gridY * cellSize,
                                  child: GestureDetector(
                                    onTap: buildMode ? () => _packUpItem(entry.key) : null,
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()..scale(entry.value.facingRight ? 1.0 : -1.0, 1.0),
                                      child: SizedBox(
                                        width: cellSize * _getItemGridSpan(entry.key.itemId),
                                        height: cellSize * _getItemGridSpan(entry.key.itemId),
                                        child: _wordFor(entry.key.itemId) != null
                                            ? WordImage(
                                                imageAsset: _wordFor(entry.key.itemId)!.imageAsset,
                                                scale: _getItemScale(entry.key.itemId), // ✨ 修改：传入放大倍数
                                              )
                                            : const Icon(Icons.emoji_nature_rounded, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ),
                              // Static placed items
                              for (final placed in placedItems)
                                if (_wordFor(placed.itemId)?.isMovable != true)
                                  Positioned(
                                    left: placed.gridX * cellSize,
                                    top: placed.gridY * cellSize,
                                    child: GestureDetector(
                                      onTap: buildMode ? () => _packUpItem(placed) : null,
                                      child: SizedBox(
                                        width: cellSize * _getItemGridSpan(placed.itemId),
                                        height: cellSize * _getItemGridSpan(placed.itemId),
                                        child: _wordFor(placed.itemId) != null
                                            ? WordImage(
                                                imageAsset: _wordFor(placed.itemId)!.imageAsset,
                                                scale: _getItemScale(placed.itemId), // ✨ 修改：传入放大倍数
                                              )
                                            : const Icon(Icons.emoji_nature_rounded, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                  
                              // 虚影 (Ghost Preview) 显示层
                              if (buildMode && _hoverX != null && _hoverY != null && selectedItemId != null)
                                Positioned(
                                  left: _hoverX!.clamp(0, gridCols - 1) * cellSize,
                                  top: _hoverY!.clamp(0, gridRows - 1) * cellSize,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2), 
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      width: cellSize * _getItemGridSpan(selectedItemId!),
                                      height: cellSize * _getItemGridSpan(selectedItemId!),
                                      child: _wordFor(selectedItemId!) != null
                                          ? WordImage(
                                              imageAsset: _wordFor(selectedItemId!)!.imageAsset,
                                              scale: _getItemScale(selectedItemId!), // ✨ 修改：传入放大倍数
                                            )
                                          : const Icon(Icons.emoji_nature_rounded, color: Colors.white70),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (!_hideUI)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _confirmExit,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.map_rounded, color: Color(0xFF333333)),
                          ),
                        ),
                        const Spacer(),
                        JellyButton(
                          color: const Color(0xFFFFAB40),
                          onTap: () {
                            setState(() => buildMode = true);
                            _openInventoryModal();
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.construction_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text('Build / Inventory'),
                            ],
                          ),
                        ),
                        if (buildMode) ...[
                          const SizedBox(width: 8),
                          JellyButton(
                            color: const Color(0xFF888888),
                            onTap: () => setState(() {
                              buildMode = false;
                              selectedItemId = null;
                            }),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(Icons.check_rounded, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (buildMode && selectedItemId != null)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Draggable<String>(
                        data: selectedItemId!,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _HeldItemChip(word: _wordFor(selectedItemId!), label: selectedItemId!),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: _HeldItemChip(word: _wordFor(selectedItemId!), label: selectedItemId!),
                        ),
                        child: GestureDetector(
                          onLongPress: () => setState(() => selectedItemId = null),
                          child: _HeldItemChip(word: _wordFor(selectedItemId!), label: selectedItemId!, showHint: true),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeldItemChip extends StatelessWidget {
  final LessonWord? word;
  final String label;
  final bool showHint;
  const _HeldItemChip({required this.word, required this.label, this.showHint = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: SizedBox(
            width: 56, height: 56,
            child: word != null
                // 这里的 WordImage 没加 scale，因为你可能希望背包和底部的拖拽图标保持原来的大小不出界
                ? WordImage(imageAsset: word!.imageAsset, errorWidget: const Icon(Icons.emoji_nature_rounded))
                : const Icon(Icons.emoji_nature_rounded),
          ),
        ),
        if (showHint)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
              child: const Text('Drag onto the map! (long-press to cancel)',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}

class _TerrainPainter extends CustomPainter {
  final Biome biome;
  final int cols, rows;
  final double cellSize;
  final bool showGrid;
  _TerrainPainter({required this.biome, required this.cols, required this.rows, required this.cellSize, required this.showGrid});

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = biome.color.withOpacity(0.85);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    if (!showGrid) return;

    final gridLinePaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;
    for (int x = 0; x <= cols; x++) {
      canvas.drawLine(Offset(x * cellSize, 0), Offset(x * cellSize, rows * cellSize), gridLinePaint);
    }
    for (int y = 0; y <= rows; y++) {
      canvas.drawLine(Offset(0, y * cellSize), Offset(cols * cellSize, y * cellSize), gridLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TerrainPainter oldDelegate) => oldDelegate.showGrid != showGrid;
}

class _GridLinesPainter extends CustomPainter {
  final int cols, rows;
  final double cellSize;
  _GridLinesPainter({required this.cols, required this.rows, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final gridLinePaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1;
    for (int x = 0; x <= cols; x++) {
      canvas.drawLine(Offset(x * cellSize, 0), Offset(x * cellSize, rows * cellSize), gridLinePaint);
    }
    for (int y = 0; y <= rows; y++) {
      canvas.drawLine(Offset(0, y * cellSize), Offset(cols * cellSize, y * cellSize), gridLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinesPainter oldDelegate) => false;
}

class _InventoryModal extends StatefulWidget {
  final List<LessonWord> catalog;
  final List<String> unlockedWords;
  final void Function(LessonWord word) onTapLocked;
  final void Function(LessonWord word) onTapUnlocked;

  const _InventoryModal({
    required this.catalog,
    required this.unlockedWords,
    required this.onTapLocked,
    required this.onTapUnlocked,
  });

  @override
  State<_InventoryModal> createState() => _InventoryModalState();
}

class _InventoryModalState extends State<_InventoryModal> {
  static const itemsPerPage = 9;
  int page = 0;
  late List<String> localUnlocked;
  late List<LessonWord> sortedCatalog;

  @override
  void initState() {
    super.initState();
    localUnlocked = List.from(widget.unlockedWords);
    sortedCatalog = List.from(widget.catalog)..sort((a, b) => a.difficulty.compareTo(b.difficulty));
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (sortedCatalog.length / itemsPerPage).ceil().clamp(1, 999);
    final start = page * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, sortedCatalog.length);
    final pageItems = sortedCatalog.sublist(start, end);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 360,
          height: 460,
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Inventory 🎒', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 112,
                  ),
                  itemCount: pageItems.length,
                  itemBuilder: (context, i) {
                    final word = pageItems[i];
                    final isUnlocked = localUnlocked.contains(word.word);
                    return GestureDetector(
                      onTap: () {
                        if (isUnlocked) {
                          widget.onTapUnlocked(word);
                        } else {
                          widget.onTapLocked(word);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                // 背包里的图片也没加 scale，保证它们能乖乖待在格子里
                                child: WordImage(
                                  imageAsset: word.imageAsset,
                                  errorWidget: const Icon(Icons.emoji_nature_rounded, size: 48),
                                ),
                              ),
                              if (!isUnlocked) ...[
                                ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                                  child: SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: WordImage(
                                      imageAsset: word.imageAsset,
                                      errorWidget: const SizedBox(),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(word.word, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  JellyButton(
                    color: const Color(0xFF80DEEA),
                    onTap: page > 0 ? () => setState(() => page--) : null,
                    padding: const EdgeInsets.all(8),
                    borderRadius: 14,
                    child: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                  ),
                  Text('Page ${page + 1} / $totalPages', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  JellyButton(
                    color: const Color(0xFF80DEEA),
                    onTap: page < totalPages - 1 ? () => setState(() => page++) : null,
                    padding: const EdgeInsets.all(8),
                    borderRadius: 14,
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}