import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/lesson_service.dart';
import '../../../services/build_mode_service.dart';
import '../../../services/unlock_service.dart';
import '../../../services/vocab_seen_service.dart';
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
  final void Function(LessonWord word) onOpenWord;

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
  static const int gridCols = 20;
  static const int gridRows = 20;
  static const double cellSize = 48;

  static const int trunkX = (gridCols ~/ 2) - 1;
  static const int trunkY = 2;
  static const int trunkSize = 3;

  final Random rand = Random();
  Timer? _roamTimer;
  final TransformationController _viewController = TransformationController();

  bool buildMode = false;
  bool bgFailed = false;
  bool _initialTransformSet = false; // guards the LayoutBuilder one-time camera lock
  bool _hasNewContent = false;       // drives the yellow "!" badge on the Trunk
  List<String> unlockedWords = [];
  List<PlacedItem> placedItems = [];
  String? selectedItemId;
  final GlobalKey _gridKey = GlobalKey();

  // One runtime roaming entity per currently-placed item whose word has
  // isMovable == true. Keyed by PlacedItem object identity so it survives
  // placedItems being replaced/reloaded without losing sync — see
  // _syncMovableRuntimes().
  final Map<PlacedItem, _RoamingEntity> _movableRuntimes = {};

  double _minScaleFor(Size viewport) {
    final fitX = viewport.width / (gridCols * cellSize);
    final fitY = viewport.height / (gridRows * cellSize);
    return fitX > fitY ? fitX : fitY;
  }

  // The ONE place built-in tiers + teacher custom vocabulary get merged —
  // see mergeCustomVocabulary's doc comment for why this matters for
  // backend integration (requirement #4).
  List<LessonWord> _globalCatalog() {
    final builtIn = <LessonWord>[
      ...defaultMapWordsFor('4-5'),
      ...defaultMapWordsFor('5-6'),
      ...defaultMapWordsFor('6-7'),
    ];
    return mergeCustomVocabulary(builtIn: builtIn, custom: widget.lesson.words);
  }

  @override
  void initState() {
    super.initState();
    _roamTimer = Timer.periodic(const Duration(seconds: 2, milliseconds: 500), (_) => _stepEntities());
    _loadBuildMode();
    _checkNewContent();
  }

  Future<void> _loadBuildMode() async {
    final unlocked = await UnlockService.loadUnlockedWords(widget.kidId);
    final saved = await BuildModeService.loadPlacements(widget.kidId, widget.biome.name);
    // Age-based auto-unlock (requirement #3): every word from an EASIER
    // tier than this kid's own is unlocked for free, no practice needed.
    final autoUnlocked = autoUnlockedWordsFor(widget.lesson.ageGroup);
    if (!mounted) return;
    setState(() {
      unlockedWords = {...unlocked, ...autoUnlocked}.toList();
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
      return _globalCatalog().firstWhere((w) => w.word == itemId);
    } catch (_) {
      return null;
    }
  }

  // --- Dynamic pathfinding (requirement #1 + #5) ---
  // Every candidate cell's "can I walk here" answer comes from whatever
  // LessonWord.isPassable says for whatever's placed there — never a
  // hardcoded word list. Plants (isPassable: true) let movers straight
  // through; fences/rocks/walls (isPassable: false) block them.

  bool _isTrunkCell(int x, int y) =>
      x >= trunkX && x < trunkX + trunkSize && y >= trunkY && y < trunkY + trunkSize;

  Set<String> _computeObstacleCells() {
    final obstacles = <String>{};
    for (final p in placedItems) {
      final word = _wordFor(p.itemId);
      if (word != null && !word.isPassable) {
        obstacles.add('${p.gridX.round()},${p.gridY.round()}');
      }
    }
    return obstacles;
  }

  bool _isBlockedFor(int x, int y, Set<String> obstacles) {
    if (x < 0 || x >= gridCols || y < 0 || y >= gridRows) return true;
    if (_isTrunkCell(x, y)) return true; // the trunk is always solid
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
        // If blocked: entity just stays put this tick and picks a fresh
        // random direction next tick — same "bounce" behavior as before,
        // now checked against dynamic obstacles instead of a fixed list.
      }
    });
  }

  // Keeps _movableRuntimes in sync with placedItems: adds a runtime
  // roamer (starting at its placed position) for any newly-placed item
  // whose word is isMovable, and drops runtimes for items that were
  // packed up. NOTE: wandered position is intentionally NOT persisted
  // back to Firestore every tick (that would spam writes); a movable
  // item resumes roaming from its originally-placed cell if the kid
  // leaves and re-enters the biome. That's a deliberate simplification.
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
    if (_isTrunkCell(clampedX, clampedY)) return;

    final word = _wordFor(itemId);
    if (word == null) {
      debugPrint('[BiomeSandbox] WARNING: no LessonWord found for itemId "$itemId" — placing anyway, but it will show as a fallback icon.');
    }

    setState(() {
      placedItems.add(PlacedItem(itemId: itemId, gridX: clampedX.toDouble(), gridY: clampedY.toDouble()));
      unlockedWords.remove(itemId);
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
      unlockedWords.add(item.itemId);
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
    // Requirement #4: opening the Inventory is "seeing" the new words —
    // mark everything currently in the catalog as seen and hide the badge.
    final catalog = _globalCatalog();
    VocabSeenService.markWordsSeen(widget.kidId, catalog.map((w) => w.word));
    setState(() => _hasNewContent = false);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _InventoryModal(
        catalog: catalog,
        unlockedWords: unlockedWords,
        onTapLocked: (word) {
          Navigator.pop(context);
          widget.onOpenWord(word);
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
              final dx = (trunkX + trunkSize / 2) * cellSize - (viewport.width / 2) / scale;
              final dy = (trunkY + trunkSize / 2) * cellSize - (viewport.height / 2) / scale;
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
                      onAcceptWithDetails: (details) {
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
                              // Trunk landmark, with the yellow "new content" badge.
                              Positioned(
                                left: trunkX * cellSize,
                                top: trunkY * cellSize,
                                child: GestureDetector(
                                  onTap: _openInventoryModal,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0, end: 1),
                                        duration: const Duration(seconds: 2),
                                        curve: Curves.easeInOut,
                                        builder: (context, value, child) => Transform.translate(
                                          offset: Offset(0, -4 * (0.5 - (value - 0.5).abs()) * 2),
                                          child: child,
                                        ),
                                        child: Container(
                                          width: trunkSize * cellSize,
                                          height: trunkSize * cellSize,
                                          alignment: Alignment.center,
                                          child: Image.asset(
                                            'assets/images/chest_${widget.biome.name}.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Image.asset(
                                              'assets/images/chest.png',
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  const Text('🎁', style: TextStyle(fontSize: 56)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_hasNewContent)
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFC107),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                            ),
                                            child: const Icon(Icons.priority_high_rounded, color: Colors.black87, size: 16),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // Movable placed items (e.g. a teacher-added "farmer").
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
                                        width: cellSize,
                                        height: cellSize,
                                        child: _wordFor(entry.key.itemId) != null
                                            ? WordImage(imageAsset: _wordFor(entry.key.itemId)!.imageAsset)
                                            : const Icon(Icons.emoji_nature_rounded, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ),
                              // Static (non-movable) placed items.
                              for (final placed in placedItems)
                                if (_wordFor(placed.itemId)?.isMovable != true)
                                  Positioned(
                                    left: placed.gridX * cellSize,
                                    top: placed.gridY * cellSize,
                                    child: GestureDetector(
                                      onTap: buildMode ? () => _packUpItem(placed) : null,
                                      child: SizedBox(
                                        width: cellSize,
                                        height: cellSize,
                                        child: _wordFor(placed.itemId) != null
                                            ? WordImage(imageAsset: _wordFor(placed.itemId)!.imageAsset)
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
                  ),
                  itemCount: pageItems.length,
                  itemBuilder: (context, i) {
                    final word = pageItems[i];
                    final isUnlocked = localUnlocked.contains(word.word);
                    return GestureDetector(
                      onTap: () {
                        if (isUnlocked) {
                          Navigator.pop(context);
                          widget.onTapUnlocked(word);
                        } else {
                          // Real flow: this pops the Inventory and calls
                          // onOpenWord, which student_home.dart wires to
                          // the actual UniversalLearningPanel ->
                          // UnlockFinaleScreen practice game.
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
