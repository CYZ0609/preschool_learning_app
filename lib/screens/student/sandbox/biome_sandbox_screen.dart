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
import '../../../services/screen_time_service.dart';

/// One roaming creature on the grid
class _RoamingEntity {
  double gridX, gridY;
  bool facingRight = true;
  final PlacedItem placedItem;
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
  Timer? _screenTimer; 
  bool _isTimeUpShown = false; 

  final TransformationController _viewController = TransformationController();

  bool buildMode = false;
  bool bgFailed = false;
  bool _initialTransformSet = false; 
  bool _hasNewContent = false;      
  bool _hideUI = false; 
  List<String> unlockedWords = [];
  List<PlacedItem> placedItems = [];
  List<LessonWord> _globalItems = [];
  
  // 底部手持的新物品 ID
  String? selectedItemId;
  // 悬停时的幽灵预览 ID
  String? _previewItemId;
  
  PlacedItem? _selectedBoardItem; 
  
  final GlobalKey _gridKey = GlobalKey();

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
   _screenTimer = Timer.periodic(const Duration(minutes: 1), (_) => _recordScreenTime());
    _loadGlobalItems();
    _loadBuildMode();
    _checkNewContent();
    _checkInitialScreenTime();
  }

  Future<void> _checkInitialScreenTime() async {
    final data = await ScreenTimeService.getTodayScreenTime(widget.kidId);
    final limitReached = data['limitReached'] ?? false;
    if (limitReached) {
      _showTimeUpDialog();
    }
  }

  Future<void> _recordScreenTime() async {
    if (_isTimeUpShown) return; 

    await ScreenTimeService.updateScreenTime(1, widget.kidId);
    
    final data = await ScreenTimeService.getTodayScreenTime(widget.kidId);
    final limitReached = data['limitReached'] ?? false;
    
    if (limitReached && !_isTimeUpShown) {
      _showTimeUpDialog();
    }
  }

  void _showTimeUpDialog() {
    if (!mounted) return;
    setState(() => _isTimeUpShown = true);
    
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (_) => PopScope(
        canPop: false, 
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Time is up! ⏰', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'You have reached your daily screen time limit.\nTime to rest your eyes!',
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pop(); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8FAB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Go Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
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
    try {
      return _globalItems.firstWhere((w) => w.word == itemId);
    } catch (_) {}
    try {
      return _globalCatalog().firstWhere((w) => w.word == itemId);
    } catch (_) {
      return null;
    }
  }

  int _getItemGridSpan(String itemId) {
    final word = _wordFor(itemId);
    if (word != null && word.width != null && word.width! > 0) {
      return word.width!;
    }
    if (itemId == 'TREE') return 7; 
    if (itemId == 'SUN') return 9; 
    return 3;
  }

  double _getItemScale(String itemId) => 2.0; 

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
    if (buildMode) return; 

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
    final clampedX = gridX.clamp(0, gridCols - 1);
    final clampedY = gridY.clamp(0, gridRows - 1);

    setState(() {
      placedItems.add(PlacedItem(itemId: itemId, gridX: clampedX.toDouble(), gridY: clampedY.toDouble()));
    });
    _syncMovableRuntimes();

    try {
      await BuildModeService.savePlacements(widget.kidId, widget.biome.name, placedItems);
    } catch (e) {
      debugPrint('[BiomeSandbox] Failed to save placement: $e');
    }
  }

  Future<void> _moveExistingItemTo(PlacedItem oldItem, int gridX, int gridY) async {
    final clampedX = gridX.clamp(0, gridCols - 1);
    final clampedY = gridY.clamp(0, gridRows - 1);

    setState(() {
      placedItems.remove(oldItem);
      final newItem = PlacedItem(
        itemId: oldItem.itemId, 
        gridX: clampedX.toDouble(), 
        gridY: clampedY.toDouble()
      );
      placedItems.add(newItem);
      _selectedBoardItem = newItem; 
    });
    
    _syncMovableRuntimes();

    try {
      await BuildModeService.savePlacements(widget.kidId, widget.biome.name, placedItems);
    } catch (e) {
      debugPrint('[BiomeSandbox] Failed to save move: $e');
    }
  }

  Future<void> _packUpItem(PlacedItem item) async {
    setState(() {
      placedItems.remove(item);
      if (_selectedBoardItem == item) _selectedBoardItem = null; 
    });
    _syncMovableRuntimes();
    await BuildModeService.savePlacements(widget.kidId, widget.biome.name, placedItems);
  }

  @override
  void dispose() {
    _roamTimer?.cancel();
    _screenTimer?.cancel();
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
          setState(() {
            selectedItemId = word.word;
            _selectedBoardItem = null; 
          });
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

  Widget _buildPlacedItemWidget(PlacedItem placed, {bool facingRight = true}) {
    final span = _getItemGridSpan(placed.itemId);
    
    Widget content = Container(
      decoration: _selectedBoardItem == placed
          ? BoxDecoration(
              border: Border.all(color: Colors.yellowAccent, width: 4),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.2),
            )
          : null,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(facingRight ? 1.0 : -1.0, 1.0),
        child: SizedBox(
          width: cellSize * span,
          height: cellSize * span,
          child: _wordFor(placed.itemId) != null
              ? WordImage(
                  imageAsset: _wordFor(placed.itemId)!.imageAsset,
                  scale: _getItemScale(placed.itemId),
                )
              : const Icon(Icons.emoji_nature_rounded, color: Colors.white70),
        ),
      ),
    );

if (buildMode) {
      final currentScale = _viewController.value.getMaxScaleOnAxis();
      return LongPressDraggable<PlacedItem>(
        data: placed, 
        // ✨ 自定义锚点：精确计算你手指按在物品上的哪个相对像素，并乘以当前地图的缩放比例
        dragAnchorStrategy: (Draggable<Object> draggable, BuildContext context, Offset position) {
          final RenderBox renderObject = context.findRenderObject() as RenderBox;
          final Offset localPosition = renderObject.globalToLocal(position); // 获取手指在物体内的坐标
          // 因为拖拽图像视觉上放大了 1.1 倍，这里也要乘以 1.1，确保手指完美压在按下的原点上
          return localPosition * (currentScale * 1.1);
        },
        feedback: Material(
          color: Colors.transparent,
          // ✨ 移除了导致位移的 FractionalTranslation，直接以左上角原点进行放大
          child: Transform.scale(
            scale: currentScale * 1.1, 
            alignment: Alignment.topLeft,
            child: content,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: content), // 原地留个半透明残影
        onDragStarted: () => setState(() {
          _selectedBoardItem = placed;
          _previewItemId = placed.itemId; // 激活幽灵预览
        }),
        onDragEnd: (_) => setState(() => _previewItemId = null),
        child: GestureDetector(
          onTap: () => setState(() => _selectedBoardItem = placed),
          child: content,
        ),
      );
    }
    
    return content;
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
                    child: DragTarget<Object>(
                      onWillAcceptWithDetails: (_) => true,
                      onMove: (details) {
                        final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final localMap = renderBox.globalToLocal(details.offset);
                        
                        int gridX, gridY;
                        
                        // ✨ 核心分支逻辑：新物品和旧物品的拖拽坐标原点不同
                        if (details.data is String) {
                          // 1. 从底部拿上来的新物品：由于它默认居中于手指，需减去一半体积推算左上角
                          final dragId = details.data as String;
                          final span = _getItemGridSpan(dragId);
                          gridX = ((localMap.dx - (span * cellSize) / 2) / cellSize).round();
                          gridY = ((localMap.dy - (span * cellSize) / 2) / cellSize).round();
                          
                          if (_hoverX != gridX || _hoverY != gridY) {
                            setState(() {
                              _hoverX = gridX;
                              _hoverY = gridY;
                              _previewItemId = dragId;
                            });
                          }
                        } else if (details.data is PlacedItem) {
                          // 2. 从地图上抓起的旧物品：details.offset 已经精准指向了物品的左上角，直接除以格子大小！
                          final placed = details.data as PlacedItem;
                          gridX = (localMap.dx / cellSize).round();
                          gridY = (localMap.dy / cellSize).round();
                          
                          if (_hoverX != gridX || _hoverY != gridY) {
                            setState(() {
                              _hoverX = gridX;
                              _hoverY = gridY;
                              _previewItemId = placed.itemId;
                            });
                          }
                        }
                      },
                      onLeave: (_) {
                        setState(() {
                          _hoverX = null;
                          _hoverY = null;
                          _previewItemId = null;
                        });
                      },
                      onAcceptWithDetails: (details) {
                        final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final localMap = renderBox.globalToLocal(details.offset);
                        
                        int gridX, gridY;

                        // ✨ 落地时也采用相同的分支判断逻辑
                        if (details.data is String) {
                          final dragId = details.data as String;
                          final span = _getItemGridSpan(dragId);
                          gridX = ((localMap.dx - (span * cellSize) / 2) / cellSize).round();
                          gridY = ((localMap.dy - (span * cellSize) / 2) / cellSize).round();
                          
                          setState(() {
                            _hoverX = null;
                            _hoverY = null;
                            _previewItemId = null;
                          });
                          _placeItemAt(dragId, gridX, gridY);

                        } else if (details.data is PlacedItem) {
                          final placed = details.data as PlacedItem;
                          gridX = (localMap.dx / cellSize).round();
                          gridY = (localMap.dy / cellSize).round();
                          
                          setState(() {
                            _hoverX = null;
                            _hoverY = null;
                            _previewItemId = null;
                          });
                          _moveExistingItemTo(placed, gridX, gridY);
                        }
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
                            
                              for (final entry in _movableRuntimes.entries)
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeInOut,
                                  left: entry.value.gridX * cellSize,
                                  top: entry.value.gridY * cellSize,
                                  child: _buildPlacedItemWidget(entry.key, facingRight: entry.value.facingRight),
                                ),
                                
                              for (final placed in placedItems)
                                if (_wordFor(placed.itemId)?.isMovable != true)
                                  Positioned(
                                    left: placed.gridX * cellSize,
                                    top: placed.gridY * cellSize,
                                    child: _buildPlacedItemWidget(placed),
                                  ),
                                  
                              if (buildMode && _hoverX != null && _hoverY != null && _previewItemId != null)
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
                                      width: cellSize * _getItemGridSpan(_previewItemId!),
                                      height: cellSize * _getItemGridSpan(_previewItemId!),
                                      child: _wordFor(_previewItemId!) != null
                                          ? WordImage(
                                              imageAsset: _wordFor(_previewItemId!)!.imageAsset,
                                              scale: _getItemScale(_previewItemId!), 
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
                        // ✨ 替换后：
JellyButton(
  color: const Color(0xFF80DEEA), // 使用清新的薄荷青，和右侧的橘色形成很好的视觉呼应
  onTap: _confirmExit,
  child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.explore_rounded, color: Colors.white, size: 18), // 换成更有探索感的指南针/地图图标
      SizedBox(width: 6),
      Text(
        'Map', 
        style: TextStyle(
          color: Colors.white, 
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        )
      ),
    ],
  ),
),
                        const Spacer(),
                        JellyButton(
                          color: buildMode ? const Color(0xFF4DD9C0) : const Color(0xFFFFAB40),
                          onTap: () {
                            setState(() {
                              buildMode = !buildMode;
                              if (!buildMode) {
                                selectedItemId = null;
                                _selectedBoardItem = null; 
                              }
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(buildMode ? Icons.edit_off_rounded : Icons.construction_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(buildMode ? 'Finish Editing' : 'Edit Map'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (buildMode && _selectedBoardItem != null)
                  Positioned(
                    bottom: 120, 
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => setState(() => _selectedBoardItem = null),
                            ),
                            Container(width: 1, height: 24, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 8)),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                              label: const Text('Remove from Map', style: TextStyle(color: Colors.white)),
                              onPressed: () => _packUpItem(_selectedBoardItem!),
                            ),
                          ],
                        ),
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
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: Material(
                            color: Colors.transparent,
                            child: _HeldItemChip(word: _wordFor(selectedItemId!), label: selectedItemId!),
                          ),
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
                  
                if (buildMode)
                  Positioned(
                    bottom: 32,
                    right: 24,
                    child: FloatingActionButton.extended(
                      onPressed: _openInventoryModal,
                      backgroundColor: const Color(0xFFFFAB40),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: SizedBox(
            width: 56, height: 56,
            child: word != null
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
    super.key,
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