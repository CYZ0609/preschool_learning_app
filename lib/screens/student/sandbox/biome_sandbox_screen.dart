import 'package:flutter/material.dart';
import '../../../services/lesson_service.dart';
import '../../../services/build_mode_service.dart';
import '../../../services/unlock_service.dart';
import '../../../data/default_map_words.dart';
import '../../../widgets/jelly_button.dart';
import 'world_map_screen.dart';

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

  final TransformationController _viewController = TransformationController();

  bool buildMode = false;
  bool bgFailed = false;
  bool _initialTransformSet = false; // guards the LayoutBuilder one-time camera lock below
  List<String> unlockedWords = [];
  List<PlacedItem> placedItems = [];
  String? selectedItemId;
  final GlobalKey _gridKey = GlobalKey();

  double _minScaleFor(Size viewport) {
    final fitX = viewport.width / (gridCols * cellSize);
    final fitY = viewport.height / (gridRows * cellSize);
    return fitX > fitY ? fitX : fitY; // never let empty space show past the grid's edge
  }

  List<LessonWord> _globalCatalog() {
    final seen = <String>{};
    final all = <LessonWord>[
      ...defaultMapWordsFor('4-5'),
      ...defaultMapWordsFor('5-6'),
      ...defaultMapWordsFor('6-7'),
      ...widget.lesson.words,
    ];
    return all.where((w) => seen.add(w.word)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadBuildMode();
    // Initial camera lock now happens in build()'s LayoutBuilder, not here —
    // setting it in a post-frame callback left InteractiveViewer's internal
    // interactive boundaries stale (computed from the pre-transform state)
    // until the user's first touch forced a recalculation, causing a
    // one-tap-to-fix black-border glitch. Computing it synchronously inside
    // LayoutBuilder, before InteractiveViewer's first build, avoids that.
  }

  Future<void> _loadBuildMode() async {
    final unlocked = await UnlockService.loadUnlockedWords(widget.kidId);
    final saved = await BuildModeService.loadPlacements(widget.kidId, widget.biome.name);
    if (!mounted) return;
    setState(() {
      unlockedWords = unlocked;
      placedItems = saved;
    });
  }

  LessonWord? _wordFor(String itemId) {
    try {
      return _globalCatalog().firstWhere((w) => w.word == itemId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _placeItemAt(String itemId, int gridX, int gridY) async {
    final clampedX = gridX.clamp(0, gridCols - 1);
    final clampedY = gridY.clamp(0, gridRows - 1);
    if (_isTrunkCell(clampedX, clampedY)) return;

    final word = _wordFor(itemId);
    if (word == null) {
      debugPrint('[BiomeSandbox] WARNING: no LessonWord found for itemId "$itemId" — placing anyway, but it will show as a fallback icon.');
    } else {
      debugPrint('[BiomeSandbox] Placing "$itemId" using asset: ${word.imageAsset}');
    }

    setState(() {
      placedItems.add(PlacedItem(itemId: itemId, gridX: clampedX.toDouble(), gridY: clampedY.toDouble()));
      unlockedWords.remove(itemId);
    });

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
    await BuildModeService.savePlacements(widget.kidId, widget.biome.name, placedItems);
  }

  @override
  void dispose() {
    _viewController.dispose();
    super.dispose();
  }

  bool _isTrunkCell(int x, int y) =>
      x >= trunkX && x < trunkX + trunkSize && y >= trunkY && y < trunkY + trunkSize;

  void _openInventoryModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _InventoryModal(
        catalog: _globalCatalog(),
        unlockedWords: unlockedWords,
        onTapLocked: (word) {
          Navigator.pop(context);
          widget.onOpenWord(word);
        },
        onTapUnlocked: (word) {
          Navigator.pop(context);
          setState(() => selectedItemId = word.word);
        },
        onMockUnlock: (word) {
          if (!unlockedWords.contains(word)) {
            setState(() => unlockedWords.add(word));
          }
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

            // One-time initial camera lock, computed from REAL layout
            // constraints (not MediaQuery, which can be available before
            // InteractiveViewer itself has actually settled its own
            // internal boundary cache). Guarded by _initialTransformSet so
            // it only runs once, and only once we have a real, finite size
            // to work with.
            if (!_initialTransformSet && viewport.isFinite && viewport.width > 0 && viewport.height > 0) {
              _initialTransformSet = true;
              final scale = _minScaleFor(viewport);
              final dx = (trunkX + trunkSize / 2) * cellSize - (viewport.width / 2) / scale;
              final dy = (trunkY + trunkSize / 2) * cellSize - (viewport.height / 2) / scale;
              _viewController.value = Matrix4.identity()
                ..scale(scale)
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
                              Positioned(
                                left: trunkX * cellSize,
                                top: trunkY * cellSize,
                                child: GestureDetector(
                                  onTap: _openInventoryModal,
                                  child: TweenAnimationBuilder<double>(
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
                                      // Chest art: tries a biome-specific image first
                                      // (e.g. assets/images/chest_desert.png), falls
                                      // back to a generic chest image if that one
                                      // isn't there yet, and finally falls back to
                                      // the emoji if no chest art has been added at
                                      // all — so this never breaks while you're
                                      // still generating/adding the AI images.
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
                                ),
                              ),
                              for (final placed in placedItems)
                                Positioned(
                                  left: placed.gridX * cellSize,
                                  top: placed.gridY * cellSize,
                                  child: GestureDetector(
                                    onTap: buildMode ? () => _packUpItem(placed) : null,
                                    child: SizedBox(
                                      width: cellSize,
                                      height: cellSize,
                                      child: _wordFor(placed.itemId) != null
                                          ? Image.asset(_wordFor(placed.itemId)!.imageAsset, fit: BoxFit.contain)
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
                ? Image.asset(word!.imageAsset, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.emoji_nature_rounded))
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
  final void Function(String word) onMockUnlock;

  const _InventoryModal({
    required this.catalog,
    required this.unlockedWords,
    required this.onTapLocked,
    required this.onTapUnlocked,
    required this.onMockUnlock,
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

  void _showMockQuiz(LessonWord word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Answer a question to unlock ${word.word}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Wrong Answer', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => localUnlocked.add(word.word));
              widget.onMockUnlock(word.word);
            },
            child: const Text('Correct Answer', style: TextStyle(color: Color(0xFF4DD9C0))),
          ),
        ],
      ),
    );
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
                          _showMockQuiz(word);
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
                                child: Image.asset(
                                  word.imageAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.emoji_nature_rounded, size: 48),
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
                                    child: Image.asset(word.imageAsset, fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const SizedBox()),
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
