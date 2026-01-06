part of 'dye_game_page.dart';

class _DyeGamePageState extends State<DyeGamePage> {
  static const int _rowCount = 9;
  static const int _colCount = 6;
  static const double _minorGap = 0;
  static const double _majorGap = 14;
  static const Set<int> _rowGapOverrides = {2, 5};
  static const int _summaryCount = 2;
  static const double _summaryScale = 0.62;
  static const double _summaryGap = 8;
  static const double _summaryItemGap = 6;
  static const double _cellRadius = 0;
  static const int _customRowCount = 10;
  static const int _customColCount = 3;
  static const double _customCellGap = 4;
  static const double _customCellRadius = 8;
  static const Color _baseColor = kBaseCellColor;
  static const RowPattern _defaultRowPattern = RowPattern.red2blue1;
  Color _hitColor = const Color(0xFFE53935);
  Color _missColor = const Color(0xFF1E88E5);
  final GlobalKey<CalculationPanelState> _calculationPanelKey =
      GlobalKey<CalculationPanelState>();

  final List<List<CellData>> _cells = List.generate(
    _rowCount,
    (_) => List.generate(
      _colCount,
      (_) => CellData(
        value: null,
        colors: List<Color>.filled(4, _baseColor),
        lockOrder: null,
      ),
    ),
  );
  final List<List<CellData>> _customCells = List.generate(
    _customRowCount,
    (_) => List.generate(
      _customColCount,
      (_) => CellData(
        value: null,
        colors: List<Color>.filled(4, _baseColor),
      ),
    ),
  );
  final List<RowPattern> _customRowPatterns = List.generate(
    _customRowCount,
    (_) => _defaultRowPattern,
  );

  CompareMode _mode = CompareMode.horizontal;
  int _threshold = 2;
  bool _cross3Compare = false;
  int? _fixedRow;
  int? _fixedCol;
  List<DiffMarker> _diffMarkers = const [];
  int _lockSequence = 0;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final data = await GameStorage.load();
    if (data == null) return;
    final loadedCells = data['cells'];
    if (loadedCells is! List<List<CellData>>) return;
    final customCells = data['customCells'] as List<List<CellData>>?;
    final customPatterns = data['customPatterns'] as List<RowPattern>?;
    final mode = data['mode'] as CompareMode?;
    final threshold = data['threshold'] as int?;
    final cross3Compare = data['cross3Compare'] as bool?;
    final fixedRow = data['fixedRow'] as int?;
    final fixedCol = data['fixedCol'] as int?;

    if (!mounted) return;
    setState(() {
      if (mode != null) {
        _mode = mode;
      }
      if (threshold != null) {
        _threshold = threshold;
      }
      if (cross3Compare != null) {
        _cross3Compare = cross3Compare;
      }
      _fixedRow = fixedRow;
      _fixedCol = fixedCol;
      if (_fixedRow != null && _fixedCol != null) {
        _fixedCol = null;
      }
      for (int row = 0; row < _rowCount; row++) {
        for (int col = 0; col < _colCount; col++) {
          final source = loadedCells[row][col];
          final target = _cells[row][col];
          target.value = source.value;
          target.colors = List<Color>.from(source.colors);
          target.locked = source.locked;
          target.lockOrder = source.lockOrder;
        }
      }
      if (customCells != null) {
        for (int row = 0; row < _customRowCount; row++) {
          for (int col = 0; col < _customColCount; col++) {
            final source = customCells[row][col];
            final target = _customCells[row][col];
            target.value = source.value;
            target.colors = List<Color>.from(source.colors);
            target.locked = false;
            target.lockOrder = null;
          }
        }
      }
      if (customPatterns != null) {
        for (int index = 0; index < _customRowCount; index++) {
          _customRowPatterns[index] = customPatterns[index];
        }
      }
      _normalizeLockOrders();
      _applyColoring(updateColors: false);
    });
  }

  Future<void> _saveState() async {
    await GameStorage.save(
      cells: _cells,
      customCells: _customCells,
      customPatterns: _customRowPatterns,
      mode: _mode,
      threshold: _threshold,
      cross3Compare: _cross3Compare,
      fixedRow: _fixedRow,
      fixedCol: _fixedCol,
    );
  }

  void _applyColoring({bool updateColors = true}) {
    if (updateColors) {
      for (int row = 0; row < _rowCount; row++) {
        for (int col = 0; col < _colCount; col++) {
          final cell = _cells[row][col];
          if (cell.locked) continue;
          cell.colors = List<Color>.filled(4, _baseColor);
        }
      }
    }
    final markers = <DiffMarker>[];
    switch (_mode) {
      case CompareMode.horizontal:
        final step = _cross3Compare ? 3 : 1;
        for (int row = 0; row < _rowCount; row++) {
          for (int col = 0; col < _colCount - step; col++) {
            final a = _cells[row][col].value;
            final b = _cells[row][col + step].value;
            final color = GameLogic.pairColor(
              a: a,
              b: b,
              threshold: _threshold,
              hitColor: _hitColor,
              missColor: _missColor,
            );
            if (color == null) continue;
            if (updateColors) {
              _setRightHalf(row, col, color);
              _setLeftHalf(row, col + step, color);
            }
            markers.add(
              DiffMarker(
                rowA: row,
                colA: col,
                rowB: row,
                colB: col + step,
                value: GameLogic.digitDiff(a!, b!),
                ),
            );
          }
        }
        if (updateColors) {
          _fillHorizontalEdges(step);
        }
        break;
      case CompareMode.vertical:
        final step = _cross3Compare ? 3 : 1;
        for (int row = 0; row < _rowCount - step; row++) {
          for (int col = 0; col < _colCount; col++) {
            final a = _cells[row][col].value;
            final b = _cells[row + step][col].value;
            final color = GameLogic.pairColor(
              a: a,
              b: b,
              threshold: _threshold,
              hitColor: _hitColor,
              missColor: _missColor,
            );
            if (color == null) continue;
            if (updateColors) {
              _setBottomHalf(row, col, color);
              _setTopHalf(row + step, col, color);
            }
            markers.add(
              DiffMarker(
                rowA: row,
                colA: col,
                rowB: row + step,
                colB: col,
                value: GameLogic.digitDiff(a!, b!),
                ),
            );
          }
        }
        if (updateColors) {
          _fillVerticalEdges(step);
        }
        break;
      case CompareMode.diagonalDownRight:
        for (int row = 0; row < _rowCount - 1; row++) {
          for (int col = 0; col < _colCount - 1; col++) {
            final a = _cells[row][col].value;
            final b = _cells[row + 1][col + 1].value;
            final color = GameLogic.pairColor(
              a: a,
              b: b,
              threshold: _threshold,
              hitColor: _hitColor,
              missColor: _missColor,
            );
            if (color == null) continue;
            if (updateColors) {
              _setDiagonalDownRightCluster(row, col, color);
            }
            markers.add(
              DiffMarker(
                rowA: row,
                colA: col,
                rowB: row + 1,
                colB: col + 1,
                value: GameLogic.digitDiff(a!, b!),
              ),
            );
          }
        }
        break;
      case CompareMode.diagonalDownLeft:
        for (int row = 0; row < _rowCount - 1; row++) {
          for (int col = 1; col < _colCount; col++) {
            final a = _cells[row][col].value;
            final b = _cells[row + 1][col - 1].value;
            final color = GameLogic.pairColor(
              a: a,
              b: b,
              threshold: _threshold,
              hitColor: _hitColor,
              missColor: _missColor,
            );
            if (color == null) continue;
            if (updateColors) {
              _setDiagonalDownLeftCluster(row, col, color);
            }
            markers.add(
              DiffMarker(
                rowA: row,
                colA: col,
                rowB: row + 1,
                colB: col - 1,
                value: GameLogic.digitDiff(a!, b!),
              ),
            );
          }
        }
        break;
      case CompareMode.fixed:
        final fixedRow = _fixedRow;
        final fixedCol = _fixedCol;
        if (fixedRow != null) {
          for (int row = 0; row < _rowCount; row++) {
            if (row == fixedRow) continue;
            for (int col = 0; col < _colCount; col++) {
              final a = _cells[fixedRow][col].value;
              final b = _cells[row][col].value;
              final color = GameLogic.pairColor(
                a: a,
                b: b,
                threshold: _threshold,
                hitColor: _hitColor,
                missColor: _missColor,
              );
              if (color == null) continue;
              if (updateColors) {
                _setFullCell(row, col, color);
              }
              markers.add(
                DiffMarker(
                  rowA: fixedRow,
                  colA: col,
                  rowB: row,
                  colB: col,
                  value: GameLogic.digitDiff(a!, b!),
                ),
              );
            }
          }
        } else if (fixedCol != null) {
          for (int row = 0; row < _rowCount; row++) {
            for (int col = 0; col < _colCount; col++) {
              if (col == fixedCol) continue;
              final a = _cells[row][fixedCol].value;
              final b = _cells[row][col].value;
              final color = GameLogic.pairColor(
                a: a,
                b: b,
                threshold: _threshold,
                hitColor: _hitColor,
                missColor: _missColor,
              );
              if (color == null) continue;
              if (updateColors) {
                _setFullCell(row, col, color);
              }
              markers.add(
                DiffMarker(
                  rowA: row,
                  colA: fixedCol,
                  rowB: row,
                  colB: col,
                  value: GameLogic.digitDiff(a!, b!),
                ),
              );
            }
          }
        }
        break;
    }
    _diffMarkers = markers;
  }

  void _recolor() {
    setState(_applyColoring);
    unawaited(_saveState());
  }

  void _updateMode(CompareMode mode) {
    setState(() {
      _mode = mode;
      _applyColoring();
    });
    unawaited(_saveState());
  }

  void _updateThreshold(int value) {
    setState(() {
      _threshold = value;
      _applyColoring();
    });
    unawaited(_saveState());
  }

  void _toggleCross3() {
    setState(() {
      _cross3Compare = !_cross3Compare;
      _applyColoring();
    });
    unawaited(_saveState());
  }

  void _selectFixedRow(int row) {
    setState(() {
      _fixedRow = _fixedRow == row ? null : row;
      if (_fixedRow != null) {
        _fixedCol = null;
      }
      _applyColoring();
    });
    unawaited(_saveState());
  }

  void _selectFixedCol(int col) {
    setState(() {
      _fixedCol = _fixedCol == col ? null : col;
      if (_fixedCol != null) {
        _fixedRow = null;
      }
      _applyColoring();
    });
    unawaited(_saveState());
  }

  void _randomizeAll() {
    final rng = Random();
    setState(() {
      for (final row in _cells) {
        for (final cell in row) {
          if (cell.locked) continue;
          cell.value = rng.nextInt(10);
        }
      }
    });
    unawaited(_saveState());
  }

  void _shiftUpAll() {
    setState(() {
      final snapshot = _cells
          .map(
            (row) => row
                .map(
                  (cell) => CellData(
                    value: cell.value,
                    colors: List<Color>.from(cell.colors),
                    locked: cell.locked,
                    lockOrder: cell.lockOrder,
                  ),
                )
                .toList(),
          )
          .toList();
      for (int row = 0; row < _rowCount - 1; row++) {
        for (int col = 0; col < _colCount; col++) {
          final source = snapshot[row + 1][col];
          final target = _cells[row][col];
          target.value = source.value;
          target.colors = List<Color>.from(source.colors);
          target.locked = source.locked;
          target.lockOrder = source.lockOrder;
        }
      }
      for (int col = 0; col < _colCount; col++) {
        final cell = _cells[_rowCount - 1][col];
        cell.value = null;
        cell.locked = false;
        cell.lockOrder = null;
        cell.colors = List<Color>.filled(4, _baseColor);
      }
      _applyColoring(updateColors: false);
    });
    unawaited(_saveState());
  }

  void _shiftDownAll() {
    setState(() {
      final snapshot = _cells
          .map(
            (row) => row
                .map(
                  (cell) => CellData(
                    value: cell.value,
                    colors: List<Color>.from(cell.colors),
                    locked: cell.locked,
                    lockOrder: cell.lockOrder,
                  ),
                )
                .toList(),
          )
          .toList();
      for (int row = _rowCount - 1; row > 0; row--) {
        for (int col = 0; col < _colCount; col++) {
          final source = snapshot[row - 1][col];
          final target = _cells[row][col];
          target.value = source.value;
          target.colors = List<Color>.from(source.colors);
          target.locked = source.locked;
          target.lockOrder = source.lockOrder;
        }
      }
      for (int col = 0; col < _colCount; col++) {
        final cell = _cells[0][col];
        cell.value = null;
        cell.locked = false;
        cell.lockOrder = null;
        cell.colors = List<Color>.filled(4, _baseColor);
      }
      _applyColoring(updateColors: false);
    });
    unawaited(_saveState());
  }

  int _digitColumnIndex(int col) => col % 3;

  bool _cellHasColor(CellData cell) {
    return cell.colors.any((color) => !_isBaseColor(color));
  }

  bool _cellHasUniformColor(CellData cell) {
    if (cell.colors.isEmpty) return false;
    final first = cell.colors.first;
    for (final color in cell.colors) {
      if (color.value != first.value) return false;
    }
    return !_isBaseColor(first);
  }

  bool _hasDuplicateLockFilter(int columnIndex, String signature) {
    for (int row = 0; row < _rowCount; row++) {
      for (int col = 0; col < _colCount; col++) {
        final cell = _cells[row][col];
        if (!cell.locked) continue;
        if (_digitColumnIndex(col) != columnIndex) continue;
        final existingSignature = GameLogic.lockFilterSignatureForCell(
          cell,
          hitColor: _hitColor,
          missColor: _missColor,
        );
        if (existingSignature == null) continue;
        if (existingSignature == signature) return true;
      }
    }
    return false;
  }

  String _digitColumnLabel(int columnIndex) {
    const labels = ['百位', '十位', '个位'];
    if (columnIndex < 0 || columnIndex >= labels.length) {
      return '该位';
    }
    return labels[columnIndex];
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  Future<bool> _confirmDuplicateLock(int columnIndex) async {
    if (!mounted) return false;
    final label = _digitColumnLabel(columnIndex);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重复筛选提示'),
          content: Text('$label已存在筛选范围相同的锁定数字，是否继续锁定？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showLockColorMismatchDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('无法锁定'),
          content: const Text('当前数字颜色不是纯色，请先统一颜色后再锁定。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  void _showCombinationDialog(String title, List<String> combinations) {
    final sorted = List<String>.from(combinations)..sort();
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text('$title（${sorted.length}组）'),
          content: SizedBox(
            width: 320,
            child: sorted.isEmpty
                ? Text(
                    '暂无符合组合',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: SizedBox(
                      height: 200,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          sorted.join(' '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  int _lockedCountForColumn(int columnIndex) {
    var count = 0;
    for (int row = 0; row < _rowCount; row++) {
      for (int col = 0; col < _colCount; col++) {
        final cell = _cells[row][col];
        if (!cell.locked) continue;
        if (_digitColumnIndex(col) != columnIndex) continue;
        count++;
      }
    }
    return count;
  }

  void _normalizeLockOrders() {
    var maxOrder = -1;
    for (int row = 0; row < _rowCount; row++) {
      for (int col = 0; col < _colCount; col++) {
        final order = _cells[row][col].lockOrder;
        if (order != null && order > maxOrder) {
          maxOrder = order;
        }
      }
    }
    var nextOrder = maxOrder + 1;
    for (int row = 0; row < _rowCount; row++) {
      for (int col = 0; col < _colCount; col++) {
        final cell = _cells[row][col];
        if (cell.locked && cell.lockOrder == null) {
          cell.lockOrder = nextOrder;
          nextOrder++;
        }
      }
    }
    _lockSequence = nextOrder;
  }

  void _setLeftHalf(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    cell.colors[0] = color;
    cell.colors[2] = color;
  }

  void _setRightHalf(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    cell.colors[1] = color;
    cell.colors[3] = color;
  }

  void _setTopHalf(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    cell.colors[0] = color;
    cell.colors[1] = color;
  }

  void _setBottomHalf(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    cell.colors[2] = color;
    cell.colors[3] = color;
  }

  void _setTopLeft(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    cell.colors[0] = color;
  }

  void _setTopRight(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    cell.colors[1] = color;
  }

  void _setBottomLeft(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    cell.colors[2] = color;
  }

  void _setBottomRight(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    cell.colors[3] = color;
  }

  void _setFullCell(int row, int col, Color color) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    for (int index = 0; index < cell.colors.length; index++) {
      cell.colors[index] = color;
    }
  }

  bool _isBaseColor(Color color) => color.value == _baseColor.value;

  bool _isHalfBase(CellData cell, int indexA, int indexB) {
    return _isBaseColor(cell.colors[indexA]) &&
        _isBaseColor(cell.colors[indexB]);
  }

  Color? _halfColor(CellData cell, int indexA, int indexB) {
    final colorA = cell.colors[indexA];
    if (!_isBaseColor(colorA)) return colorA;
    final colorB = cell.colors[indexB];
    if (!_isBaseColor(colorB)) return colorB;
    return null;
  }

  void _fillLeftHalfFromRight(int row, int col) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    if (!_isHalfBase(cell, 0, 2)) return;
    final color = _halfColor(cell, 1, 3);
    if (color == null) return;
    _setLeftHalf(row, col, color);
  }

  void _fillRightHalfFromLeft(int row, int col) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    if (!_isHalfBase(cell, 1, 3)) return;
    final color = _halfColor(cell, 0, 2);
    if (color == null) return;
    _setRightHalf(row, col, color);
  }

  void _fillTopHalfFromBottom(int row, int col) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    if (!_isHalfBase(cell, 0, 1)) return;
    final color = _halfColor(cell, 2, 3);
    if (color == null) return;
    _setTopHalf(row, col, color);
  }

  void _fillBottomHalfFromTop(int row, int col) {
    final cell = _cells[row][col];
    if (cell.locked) return;
    if (!_isHalfBase(cell, 2, 3)) return;
    final color = _halfColor(cell, 0, 1);
    if (color == null) return;
    _setBottomHalf(row, col, color);
  }

  void _fillHorizontalEdges(int step) {
    final leftLimit = min(step, _colCount);
    for (int row = 0; row < _rowCount; row++) {
      for (int col = 0; col < leftLimit; col++) {
        _fillLeftHalfFromRight(row, col);
      }
    }
    final rightStart = max(0, _colCount - step);
    for (int row = 0; row < _rowCount; row++) {
      for (int col = rightStart; col < _colCount; col++) {
        _fillRightHalfFromLeft(row, col);
      }
    }
  }

  void _fillVerticalEdges(int step) {
    final topLimit = min(step, _rowCount);
    for (int row = 0; row < topLimit; row++) {
      for (int col = 0; col < _colCount; col++) {
        _fillTopHalfFromBottom(row, col);
      }
    }
    final bottomStart = max(0, _rowCount - step);
    for (int row = bottomStart; row < _rowCount; row++) {
      for (int col = 0; col < _colCount; col++) {
        _fillBottomHalfFromTop(row, col);
      }
    }
  }

  void _setDiagonalDownRightCluster(int row, int col, Color color) {
    _setBottomRight(row, col, color);
    _setBottomLeft(row, col + 1, color);
    _setTopRight(row + 1, col, color);
    _setTopLeft(row + 1, col + 1, color);
  }

  void _setDiagonalDownLeftCluster(int row, int col, Color color) {
    _setBottomLeft(row, col, color);
    _setBottomRight(row, col - 1, color);
    _setTopLeft(row + 1, col, color);
    _setTopRight(row + 1, col - 1, color);
  }

  Future<bool> _toggleCellLock(int row, int col, bool shouldLock) async {
    final cell = _cells[row][col];
    if (shouldLock == cell.locked) {
      return true;
    }
    if (shouldLock) {
      if (cell.value == null) {
        _showSnack('请先填写数字再锁定');
        return false;
      }
      if (!_cellHasColor(cell)) {
        _showSnack('请先染色（自动或手动）才能锁定');
        return false;
      }
      if (!_cellHasUniformColor(cell)) {
        await _showLockColorMismatchDialog();
        return false;
      }
      final columnIndex = _digitColumnIndex(col);
      final lockedCount = _lockedCountForColumn(columnIndex);
      if (lockedCount >= 4) {
        _showSnack('该位最多锁定4个数字');
        return false;
      }
      final signature = GameLogic.lockFilterSignatureForCell(
        cell,
        hitColor: _hitColor,
        missColor: _missColor,
      );
      if (signature != null &&
          _hasDuplicateLockFilter(columnIndex, signature)) {
        final shouldContinue = await _confirmDuplicateLock(columnIndex);
        if (!shouldContinue) return false;
      }
      setState(() {
        cell.locked = true;
        cell.lockOrder = _lockSequence++;
      });
    } else {
      setState(() {
        cell.locked = false;
        cell.lockOrder = null;
      });
    }
    unawaited(_saveState());
    return true;
  }

  void _clearAllLocks() {
    setState(() {
      for (final row in _cells) {
        for (final cell in row) {
          cell.locked = false;
          cell.lockOrder = null;
        }
      }
      _lockSequence = 0;
      _applyColoring();
    });
    unawaited(_saveState());
  }

  void _updateCustomPattern(int row, RowPattern pattern) {
    setState(() {
      _customRowPatterns[row] = pattern;
    });
    unawaited(_saveState());
  }

  void _clearCustomNumbers() {
    setState(() {
      for (final row in _customCells) {
        for (final cell in row) {
          cell.value = null;
          cell.colors = List<Color>.filled(4, _baseColor);
          cell.locked = false;
          cell.lockOrder = null;
        }
      }
    });
    unawaited(_saveState());
  }

  void _importCustomNumbers() {
    final numbers = <List<int>>[];
    final groupCount = (_colCount / 3).floor();
    for (int row = _rowCount - 1; row >= 0; row--) {
      for (int group = groupCount - 1; group >= 0; group--) {
        final startCol = group * 3;
        final digits = <int>[];
        var complete = true;
        for (int offset = 0; offset < 3; offset++) {
          final value = _cells[row][startCol + offset].value;
          if (value == null) {
            complete = false;
            break;
          }
          digits.add(value);
        }
        if (complete) {
          numbers.add(digits);
          if (numbers.length >= _customRowCount) {
            break;
          }
        }
      }
      if (numbers.length >= _customRowCount) {
        break;
      }
    }

    if (numbers.isEmpty) {
      _showSnack('暂无可导入的完整三位数');
      return;
    }

    setState(() {
      for (final row in _customCells) {
        for (final cell in row) {
          cell.value = null;
          cell.colors = List<Color>.filled(4, _baseColor);
          cell.locked = false;
          cell.lockOrder = null;
        }
      }
      for (int index = 0; index < numbers.length; index++) {
        final digits = numbers[index];
        for (int col = 0; col < _customColCount; col++) {
          final cell = _customCells[index][col];
          cell.value = digits[col];
          cell.colors = List<Color>.filled(4, _baseColor);
          cell.locked = false;
          cell.lockOrder = null;
        }
      }
    });
    unawaited(_saveState());
  }

  void _calculateCustom() {
    final results = GameLogic.calculateCustomCombinations(
      customCells: _customCells,
      customRowPatterns: _customRowPatterns,
      hitColor: _hitColor,
      missColor: _missColor,
    );
    _showCombinationDialog('自定义计算结果', results.toList());
  }

  void _calculateTotal() {
    final customResults = GameLogic.calculateCustomCombinations(
      customCells: _customCells,
      customRowPatterns: _customRowPatterns,
      hitColor: _hitColor,
      missColor: _missColor,
    );
    final lockState = _calculationPanelKey.currentState;
    final lockResults = lockState?.buildFilteredCombinations();
    if (lockState != null && lockResults == null) {
      _showSnack('012路需填写3个数字且数字之和为3');
      return;
    }
    final lockSet = (lockResults ?? _buildBaseCombinations()).toSet();
    final results = lockSet.intersection(customResults);
    _showCombinationDialog('总计算结果', results.toList());
  }

  Future<void> _editCell(int row, int col) async {
    final cell = _cells[row][col];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.55,
          child: EditCellDialog(
            cell: cell,
            row: row,
            col: col,
            title: '编辑自定义格子',
            hitColor: _hitColor,
            missColor: _missColor,
            baseColor: _baseColor,
            onValueChanged: (nextValue) {
              setState(() => cell.value = nextValue);
              unawaited(_saveState());
            },
            onColorChanged: (nextColor) {
              final nextColors = List<Color>.filled(4, nextColor);
              setState(() => cell.colors = List<Color>.from(nextColors));
              unawaited(_saveState());
            },
            onToggleLock: (shouldLock) => _toggleCellLock(row, col, shouldLock),
          ),
        );
      },
    );
  }

  Future<void> _editCustomCell(int row, int col) async {
    final cell = _customCells[row][col];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.55,
          child: EditCellDialog(
            cell: cell,
            row: row,
            col: col,
            hitColor: _hitColor,
            missColor: _missColor,
            baseColor: _baseColor,
            showLockToggle: false,
            onValueChanged: (nextValue) {
              setState(() => cell.value = nextValue);
              unawaited(_saveState());
            },
            onColorChanged: (nextColor) {
              final nextColors = List<Color>.filled(4, nextColor);
              setState(() => cell.colors = List<Color>.from(nextColors));
              unawaited(_saveState());
            },
          ),
        );
      },
    );
  }

  int? _sumRowGroup(int row, int startCol) {
    var sum = 0;
    for (int offset = 0; offset < 3; offset++) {
      final value = _cells[row][startCol + offset].value;
      if (value == null) return null;
      sum += value;
    }
    return sum;
  }

  List<List<String>> _buildRowSummaries() {
    final summaries = <List<String>>[];
    for (int row = 0; row < _rowCount; row++) {
      final first = _sumRowGroup(row, 0);
      final second = _sumRowGroup(row, 3);
      summaries.add([
        first?.toString() ?? '',
        second?.toString() ?? '',
      ]);
    }
    return summaries;
  }

  double _gridTotalGap(int count, {Set<int> gapOverrides = const {}}) {
    var gap = 0.0;
    for (int i = 0; i < count - 1; i++) {
      final isMajor = (i + 1) % 3 == 0;
      gap += gapOverrides.contains(i)
          ? _minorGap
          : (isMajor ? _majorGap : _minorGap);
    }
    return gap;
  }

  Widget _buildGridSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isCompact = maxWidth < 520;
        final padding = isCompact ? 8.0 : 12.0;
        final cardWidth = isCompact ? maxWidth : min(maxWidth, 520.0);
        final totalRowGap =
            _gridTotalGap(_rowCount, gapOverrides: _rowGapOverrides);
        final totalColGap = _gridTotalGap(_colCount);
        final gridWidth = max(0.0, cardWidth - padding * 2);
        final summaryOuterGap = _summaryCount > 0 ? _summaryGap : 0.0;
        final summaryInnerGap =
            _summaryCount > 1 ? _summaryItemGap * (_summaryCount - 1) : 0.0;
        final widthBudget = max(
          0.0,
          gridWidth - totalColGap - summaryOuterGap - summaryInnerGap,
        );
        final widthBasedCellSize = _summaryCount > 0
            ? widthBudget / (_colCount + _summaryCount * _summaryScale)
            : widthBudget / _colCount;
        final cellSize = isCompact
            ? max(0.0, widthBasedCellSize)
            : 0.0;
        final gridHeight = isCompact
            ? max(0.0, cellSize * _rowCount + totalRowGap)
            : cardWidth - padding * 2;
        final cardHeight =
            isCompact ? gridHeight + padding * 2 : cardWidth;
        final rowSummaries = _buildRowSummaries();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: NumberGrid(
                      cells: _cells,
                      minorGap: _minorGap,
                      majorGap: _majorGap,
                      cellRadius: _cellRadius,
                      rowGapOverrides: _rowGapOverrides,
                      rowSummaries: rowSummaries,
                      summaryScale: _summaryScale,
                      summaryGap: _summaryGap,
                      summaryItemGap: _summaryItemGap,
                      showBall: true,
                      diffMarkers: _diffMarkers,
                      showFixedSelectors: _mode == CompareMode.fixed,
                      selectedRow: _fixedRow,
                      selectedCol: _fixedCol,
                      onRowSelect:
                          _mode == CompareMode.fixed ? _selectFixedRow : null,
                      onColSelect:
                          _mode == CompareMode.fixed ? _selectFixedCol : null,
                      onCellTap: _editCell,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _buildBaseCombinations() {
    return GameLogic.calculateBaseCombinations(
      cells: _cells,
      hitColor: _hitColor,
      missColor: _missColor,
    );
  }

  Widget _buildConfigPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final horizontalPadding = isCompact ? 12.0 : 20.0;
        final verticalPadding = isCompact ? 16.0 : 20.0;
        final contentMaxWidth =
            max(0.0, constraints.maxWidth - horizontalPadding * 2);
        final isWide = contentMaxWidth >= 900;
        final isAndroid = Theme.of(context).platform == TargetPlatform.android;
        final sectionGap = isAndroid ? 16.0 : 24.0;
        final gridSection = _buildGridSection();
        final configSection = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GameConfigPanel(
            threshold: _threshold,
            mode: _mode,
            cross3Compare: _cross3Compare,
            cells: _cells,
            baseColor: _baseColor,
            onThresholdChanged: _updateThreshold,
            onModeChanged: _updateMode,
            onToggleCross3: _toggleCross3,
            onRandomize: _randomizeAll,
            onShiftUp: _shiftUpAll,
            onShiftDown: _shiftDownAll,
            onClearLocks: _clearAllLocks,
            onRecolor: _recolor,
          ),
        );
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: gridSection),
                    const SizedBox(width: 24),
                    configSection,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    gridSection,
                    SizedBox(height: sectionGap),
                    configSection,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildLockCalculationPanel() {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '锁定展示计算',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            CalculationPanel(
              key: _calculationPanelKey,
              baseCombinationsBuilder: _buildBaseCombinations,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomCalculationPanel() {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '自定义计算',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildCustomGrid(),
            const SizedBox(height: 16),
            _buildCustomActions(),
          ],
        ),
      ),
    );
  }

  Widget _patternOptionButton({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final borderColor = selected ? kSelectionColor : Colors.black26;
    final backgroundColor =
        selected ? kSelectionFillColor : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w600),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCustomRowOptions(int row) {
    final selected = _customRowPatterns[row];
    final options = RowPattern.values;
    final children = <Widget>[];
    for (int index = 0; index < options.length; index++) {
      final pattern = options[index];
      children.add(
        Expanded(
          child: _patternOptionButton(
            selected: selected == pattern,
            onTap: () => _updateCustomPattern(row, pattern),
            child: Text(
              pattern.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      );
      if (index != options.length - 1) {
        children.add(const SizedBox(width: 4));
      }
    }
    return Row(children: children);
  }

  Widget _buildCustomGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const rowGap = 6.0;
        const optionGap = 12.0;
        const minOptionWidth = 170.0;
        const minCellSize = 24.0;
        const maxCellSize = 36.0;
        final availableWidth = constraints.maxWidth;
        final cellSize = ((availableWidth -
                    minOptionWidth -
                    optionGap -
                    _customCellGap * (_customColCount - 1)) /
                _customColCount)
            .clamp(minCellSize, maxCellSize)
            .toDouble();
        final gridWidth =
            cellSize * _customColCount + _customCellGap * (_customColCount - 1);
        return Column(
          children: List.generate(
            _customRowCount,
            (row) {
              final rowCells = <Widget>[];
              for (int col = 0; col < _customColCount; col++) {
                rowCells.add(
                  SizedBox(
                    width: cellSize,
                    height: cellSize,
                    child: NumberCell(
                      cell: _customCells[row][col],
                      radius: _customCellRadius,
                      onTap: () => _editCustomCell(row, col),
                    ),
                  ),
                );
                if (col != _customColCount - 1) {
                  rowCells.add(SizedBox(width: _customCellGap));
                }
              }
              return Padding(
                padding: EdgeInsets.only(
                  bottom: row == _customRowCount - 1 ? 0 : rowGap,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: gridWidth,
                      child: Row(children: rowCells),
                    ),
                    const SizedBox(width: optionGap),
                    Expanded(child: _buildCustomRowOptions(row)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCustomActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearCustomNumbers,
                icon: const Icon(Icons.cleaning_services, size: 16),
                label: const Text('清空数字'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importCustomNumbers,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('导入数字'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _calculateCustom,
                icon: const Icon(Icons.calculate),
                label: const Text('计算'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _calculateTotal,
                icon: const Icon(Icons.functions),
                label: const Text('总计算'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalculationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          final lockPanel = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildLockCalculationPanel(),
          );
          final customPanel = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _buildCustomCalculationPanel(),
          );
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: lockPanel,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: customPanel,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: lockPanel,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.topCenter,
                child: customPanel,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF5F3E7),
                  Color(0xFFE7F3F0),
                  Color(0xFFF7EEE8),
                ],
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDE68A).withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBBF7D0).withOpacity(0.55),
              ),
            ),
          ),
          SafeArea(
            child: IndexedStack(
              index: _pageIndex,
              children: [
                _buildConfigPage(),
                _buildCalculationPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 60,
        selectedIndex: _pageIndex,
        onDestinationSelected: (index) {
          setState(() {
            _pageIndex = index;
          });
        },
        backgroundColor: Colors.white.withOpacity(0.92),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: '配置',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate),
            label: '计算',
          ),
        ],
      ),
    );
  }
}
