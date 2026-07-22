import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/lesson_service.dart';
import '../../../services/build_mode_service.dart';
import '../../../services/unlock_service.dart';
import '../../../data/default_map_words.dart';
import '../../../widgets/jelly_button.dart';
import 'world_map_screen.dart';

/// Phase 2: the top-down grid sandbox for one biome, in Play Mode.
/// - Terrain is a themed grid (CustomPainter, one paint call — not 400
///   individual widgets, for performance).
/// - A locked "Magic Supply Trunk" sits at grid-center holding the
///   assigned lesson's words; tapping it opens the word list, and tapping
///   a locked word is meant to launch the Universal Learning Panel
///   (Phase 3 — [onOpenWord] is the hook for that, not yet built).
/// - A few animals wander the grid on a timer, bouncing off the trunk's
///   footprint and the grid edges, flipping horizontally when blocked.
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

class _RoamingAnimal {
  double gridX, gridY;
  bool facingRight = true;
  final String emoji;
  _RoamingAnimal({required this.gridX, required this.gridY, required this.emoji});
}

class _BiomeSandboxScreenState extends State<BiomeSandboxScreen> {
  static const int gridCols = 20;
  static const int gridRows = 20;
  static const double cellSize = 48;

  // Trunk footprint: 3x3, roughly centered horizontally, near the top.
  static const int trunkX = (gridCols ~/ 2) - 1;
  static const int trunkY = 2;
  static const int trunkSize = 3;

  late List<_RoamingAnimal> animals;
  Timer? _roamTimer;
  final Random rand = Random();
  final TransformationController _viewController = TransformationController();

  bool buildMode = false;
  bool bgFailed = false; // true if the biome's floor image couldn't load
  List<String> unlockedWords = [];
  List<PlacedItem> placedItems = [];
  String? selectedItemId; // item currently "held", ready to be dragged onto the map
  final GlobalKey _gridKey = GlobalKey(); // for converting drop position -> grid cell

  // Global vocabulary catalog: every word across every age tier's default
  // bank, plus this lesson's own words — deduped. Per the spec, the
  // inventory shows ALL items regardless of which biome you're in (a kid
  // can place an igloo in the desert).
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
    animals = List.generate(3, (i) {
      return _RoamingAnimal(
        gridX: (5 + i * 4).toDouble(),
        gridY: (gridRows - 4).toDouble(),
        emoji: ['🐔', '🐑', '🐰'][i % 3],
      );
    });
    _roamTimer = Timer.periodic(const Duration(seconds: 2, milliseconds: 500), (_) => _stepAnimals());
    _loadBuildMode();

    // Lock the initial camera on the trunk, per the spec.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dx = (trunkX + trunkSize / 2) * cellSize - 150;
      final dy = (trunkY + trunkSize / 2) * cellSize - 150;
      _viewController.value = Matrix4.identity()..translate(-dx, -dy);
    });
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
    if (_isTrunkCell(clampedX, clampedY)) return; // can't place on the trunk

    // Sanity-check the image asset exists in our lookup BEFORE placing —
    // if _wordFor returns null, the item has no matching art and we log
    // it instead of silently placing a broken/invisible item.
    final word = _wordFor(itemId);
    if (word == null) {
      debugPrint('[BiomeSandbox] WARNING: no LessonWord found for itemId "$itemId" — placing anyway, but it will show as a fallback icon.');
    } else {
      debugPrint('[BiomeSandbox] Placing "$itemId" using asset: ${word.imageAsset}');
      // REMINDER: if this image doesn't actually appear, check:
      //   1. The file really exists at that exact path under assets/images/
      //   2. pubspec.yaml has `assets:` -> `- assets/images/` listed
      //      (a whole-folder wildcard, already set up in this project)
      //   3. You ran `flutter pub get` after adding any new image files
    }

    setState(() {
      placedItems.add(PlacedItem(itemId: itemId, gridX: clampedX.toDouble(), gridY: clampedY.toDouble()));
      unlockedWords.remove(itemId);
      // NOT clearing selectedItemId here — continuous placement per spec:
      // the item stays "held" so the child can drop it again immediately.
    });

    // This Firestore write was previously unguarded — a network error or
    // permission issue here would throw an uncaught exception straight out
    // of an async callback and crash the app. Now it just logs and keeps
    // the local placement working even if the save fails.
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
    _roamTimer?.cancel();
    _viewController.dispose();
    super.dispose();
  }

  bool _isTrunkCell(int x, int y) =>
      x >= trunkX && x < trunkX + trunkSize && y >= trunkY && y < trunkY + trunkSize;

  bool _isBlocked(int x, int y) {
    if (x < 0 || x >= gridCols || y < 0 || y >= gridRows) return true;
    return _isTrunkCell(x, y);
  }

  void _stepAnimals() {
    setState(() {
      for (final animal in animals) {
        final dir = rand.nextInt(4);
        int dx = 0, dy = 0;
        switch (dir) {
          case 0: dx = 1; break;
          case 1: dx = -1; break;
          case 2: dy = 1; break;
          case 3: dy = -1; break;
        }
        final targetX = animal.gridX.round() + dx;
        final targetY = animal.gridY.round() + dy;
        if (!_isBlocked(targetX, targetY)) {
          animal.gridX = targetX.toDouble();
          animal.gridY = targetY.toDouble();
          if (dx != 0) animal.facingRight = dx > 0;
        }
        // If blocked, animal just stays put this tick (a tiny "bounce" is
        // implied by the AnimatedPositioned curve not moving) and will
        // pick a fresh random direction next tick.
      }
    });
  }

  void _openInventoryModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black54, // semi-transparent overlay — game stays visible-ish behind
      builder: (context) => _InventoryModal(
        catalog: _globalCatalog(),
        unlockedWords: unlockedWords,
        onTapLocked: (word) {
          Navigator.pop(context);
          widget.onOpenWord(word); // enters the practice/unlock flow
        },
        onTapUnlocked: (word) {
          Navigator.pop(context);
          setState(() => selectedItemId = word.word); // enter placement mode
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
      body: Stack(
        children: [
          InteractiveViewer(
            transformationController: _viewController,
            minScale: 0.8,
            maxScale: 2.5,
            boundaryMargin: EdgeInsets.zero,
            constrained: false,
            child: DragTarget<String>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) {
                // details.offset is in GLOBAL screen coordinates. Since this
                // DragTarget is itself a descendant of the InteractiveViewer's
                // transformed content, converting via ITS OWN RenderBox
                // automatically accounts for the current pan/zoom — no
                // manual matrix math needed.
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
                                // Floor art missing/misnamed — fall back to the
                                // color+grid painter instead of a broken-image icon.
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && !bgFailed) setState(() => bgFailed = true);
                                });
                                return CustomPaint(
                                  size: Size(gridCols * cellSize, gridRows * cellSize),
                                  painter: _TerrainPainter(biome: widget.biome, cols: gridCols, rows: gridRows, cellSize: cellSize, showGrid: buildMode),
                                );
                              },
                            ),
                      // Grid lines ONLY visible in Build Mode, layered over
                      // the real floor image (the painter above only draws
                      // lines itself in the fallback-color case).
                      if (buildMode && !bgFailed)
                        CustomPaint(
                          size: Size(gridCols * cellSize, gridRows * cellSize),
                          painter: _GridLinesPainter(cols: gridCols, rows: gridRows, cellSize: cellSize),
                        ),
                      // Trunk landmark
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
                              child: const Text('🎁', style: TextStyle(fontSize: 56)),
                            ),
                          ),
                        ),
                      ),
                      // Roaming animals
                      for (final animal in animals)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeInOut,
                          left: animal.gridX * cellSize,
                          top: animal.gridY * cellSize,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..scale(animal.facingRight ? 1.0 : -1.0, 1.0),
                            child: Text(animal.emoji, style: const TextStyle(fontSize: 36)),
                          ),
                        ),
                      // Placed items (Build Mode)
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
                      // Streamlined: one tap both enters Build Mode AND
                      // opens the inventory — no separate "tap edit, then
                      // tap +" two-step anymore.
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
          // Floating "held" item — drag this onto the map to place it.
          // Stays selected after each drop (continuous placement).
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
                    onLongPress: () => setState(() => selectedItemId = null), // long-press to cancel
                    child: _HeldItemChip(word: _wordFor(selectedItemId!), label: selectedItemId!, showHint: true),
                  ),
                ),
              ),
            ),
        ],
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

    if (!showGrid) return; // grid lines only visible in Build Mode

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

/// The unified global inventory + unlock modal. Shows every vocabulary
/// word across every biome (4x4 grid, paginated). Locked items show a
/// padlock and launch the practice flow; unlocked items select for
/// placement.
class _InventoryModal extends StatefulWidget {
  final List<LessonWord> catalog;
  final List<String> unlockedWords;
  final void Function(LessonWord word) onTapLocked;
  final void Function(LessonWord word) onTapUnlocked;
  final void Function(String word) onMockUnlock; // syncs test-flow unlocks back to the parent screen

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
  static const itemsPerPage = 9; // 3x3
  int page = 0;
  late List<String> localUnlocked; // mutable copy so the Mock Quiz can unlock in-place
  late List<LessonWord> sortedCatalog;

  @override
  void initState() {
    super.initState();
    localUnlocked = List.from(widget.unlockedWords);
    sortedCatalog = List.from(widget.catalog)..sort((a, b) => a.difficulty.compareTo(b.difficulty));
  }

  // --- TEMPORARY TEST SCAFFOLDING ---
  // Lets you exercise the full "tap locked -> answer -> item unlocks and
  // turns colored" loop without needing to actually play through a real
  // Learning Panel session each time. Swap the "Correct Answer" button's
  // action for widget.onTapLocked(word) (the real flow) once you're done
  // testing, or leave both available side by side.
  void _showMockQuiz(LessonWord word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Answer a question to unlock ${word.word}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // wrong answer — just closes, no unlock
            child: const Text('Wrong Answer', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => localUnlocked.add(word.word));
              widget.onMockUnlock(word.word); // sync back to parent so it survives modal close/reopen
            },
            child: const Text('Correct Answer', style: TextStyle(color: Color(0xFF4DD9C0))),
          ),
        ],
      ),
    );
  }
  // --- END TEMPORARY TEST SCAFFOLDING ---

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
                    crossAxisCount: 3, // 3x3 per the spec
                    crossAxisSpacing: 16, // increased spacing
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
                              // Always show the original image, enlarged —
                              // both locked and unlocked states use the
                              // same base art, per the spec.
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
                                // Grayscale filter over the same image.
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
                                // 30% opacity black overlay.
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                // White lock icon, centered, top layer.
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
