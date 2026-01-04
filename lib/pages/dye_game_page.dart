import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cell_data.dart';
import '../models/compare_mode.dart';
import '../models/diff_marker.dart';
import '../utils/color_utils.dart';
import '../widgets/number_grid.dart';

class DyeGamePage extends StatefulWidget {
  const DyeGamePage({super.key});

  @override
  State<DyeGamePage> createState() => _DyeGamePageState();
}

class _DyeGamePageState extends State<DyeGamePage> {
  static const int _rowCount = 9;
  static const int _colCount = 6;
  static const double _minorGap = 0;
  static const double _majorGap = 14;
  static const double _cellRadius = 0;
  static const Color _baseColor = kBaseCellColor;
  static const String _storageKey = 'dye_game_state_v2';
  Color _hitColor = const Color(0xFFE53935);
  Color _missColor = const Color(0xFF1E88E5);

  final List<List<CellData>> _cells = List.generate(
    _rowCount,
    (_) => List.generate(
      _colCount,
      (_) => CellData(
        value: null,
        colors: List<Color>.filled(4, _baseColor),
      ),
    ),
  );

  CompareMode _mode = CompareMode.horizontal;
  int _threshold = 2;
  bool _cross3Compare = false;
  int? _fixedRow;
  int? _fixedCol;
  List<DiffMarker> _diffMarkers = const [];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    final cellsData = decoded['cells'];
    if (cellsData is! List || cellsData.length < _rowCount) return;

    final parsed = <List<CellData>>[];
    for (int rowIndex = 0; rowIndex < _rowCount; rowIndex++) {
      final rowData = cellsData[rowIndex];
      if (rowData is! List || rowData.length < _colCount) return;
      final row = <CellData>[];
      for (int colIndex = 0; colIndex < _colCount; colIndex++) {
        final cellData = rowData[colIndex];
        if (cellData is! Map<String, dynamic>) return;
        final colorsData = cellData['colors'];
        if (colorsData is! List || colorsData.length != 4) return;
        final colors = <Color>[];
        for (final colorValue in colorsData) {
          if (colorValue is num) {
            colors.add(Color(colorValue.toInt()));
          } else {
            colors.add(_baseColor);
          }
        }
        final value = cellData['value'];
        row.add(
          CellData(
            value: value is num ? value.toInt() : null,
            colors: colors,
            locked: cellData['locked'] == true,
          ),
        );
      }
      parsed.add(row);
    }

    if (!mounted) return;
    setState(() {
      final modeName = decoded['mode'];
      if (modeName is String) {
        _mode = CompareMode.values.firstWhere(
          (mode) => mode.name == modeName,
          orElse: () => _mode,
        );
      }
      final thresholdValue = decoded['threshold'];
      if (thresholdValue is num) {
        _threshold = thresholdValue.round().clamp(0, 5).toInt();
      }
      final cross3Value = decoded['cross3Compare'];
      if (cross3Value is bool) {
        _cross3Compare = cross3Value;
      } else {
        _cross3Compare = false;
      }
      final fixedRowValue = decoded['fixedRow'];
      if (fixedRowValue is num) {
        final rowIndex = fixedRowValue.toInt();
        _fixedRow =
            rowIndex >= 0 && rowIndex < _rowCount ? rowIndex : null;
      } else {
        _fixedRow = null;
      }
      final fixedColValue = decoded['fixedCol'];
      if (fixedColValue is num) {
        final colIndex = fixedColValue.toInt();
        _fixedCol =
            colIndex >= 0 && colIndex < _colCount ? colIndex : null;
      } else {
        _fixedCol = null;
      }
      if (_fixedRow != null && _fixedCol != null) {
        _fixedCol = null;
      }
      for (int row = 0; row < _rowCount; row++) {
        for (int col = 0; col < _colCount; col++) {
          final source = parsed[row][col];
          final target = _cells[row][col];
          target.value = source.value;
          target.colors = List<Color>.from(source.colors);
          target.locked = source.locked;
        }
      }
      _applyColoring(updateColors: false);
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'mode': _mode.name,
      'threshold': _threshold,
      'cross3Compare': _cross3Compare,
      'fixedRow': _fixedRow,
      'fixedCol': _fixedCol,
      'cells': _cells
          .map(
            (row) => row
                .map(
                  (cell) => {
                    'value': cell.value,
                    'locked': cell.locked,
                    'colors': cell.colors.map((color) => color.value).toList(),
                  },
                )
                .toList(),
          )
          .toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(data));
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
            final color = _pairColor(a, b);
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
                value: _digitDiff(a!, b!),
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
            final color = _pairColor(a, b);
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
                value: _digitDiff(a!, b!),
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
            final color = _pairColor(a, b);
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
                value: _digitDiff(a!, b!),
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
            final color = _pairColor(a, b);
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
                value: _digitDiff(a!, b!),
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
              final color = _pairColor(a, b);
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
                  value: _digitDiff(a!, b!),
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
              final color = _pairColor(a, b);
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
                  value: _digitDiff(a!, b!),
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
        }
      }
      for (int col = 0; col < _colCount; col++) {
        final cell = _cells[_rowCount - 1][col];
        cell.value = null;
        cell.locked = false;
        cell.colors = List<Color>.filled(4, _baseColor);
      }
      _applyColoring(updateColors: false);
    });
    unawaited(_saveState());
  }

  Color? _pairColor(int? a, int? b) {
    if (a == null || b == null) return null;
    final diff = _digitDiff(a, b);
    return diff <= _threshold ? _hitColor : _missColor;
  }

  int _digitDiff(int a, int b) {
    final diff = (a - b).abs();
    return min(diff, 10 - diff);
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

  Future<void> _editCell(int row, int col) async {
    final cell = _cells[row][col];
    int? value = cell.value;
    bool locked = cell.locked;
    List<Color> colors = List<Color>.from(cell.colors);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text('编辑格子（${row + 1}, ${col + 1}）'),
          content: StatefulBuilder(
            builder: (context, setInnerState) {
              void updateValue(int? nextValue) {
                setInnerState(() => value = nextValue);
                setState(() => cell.value = nextValue);
                unawaited(_saveState());
              }

              void updateColors(Color nextColor) {
                final nextColors = List<Color>.filled(4, nextColor);
                setInnerState(() => colors = nextColors);
                setState(() => cell.colors = List<Color>.from(nextColors));
                unawaited(_saveState());
              }

              void updateLocked(bool nextValue) {
                setInnerState(() => locked = nextValue);
                setState(() => cell.locked = nextValue);
                unawaited(_saveState());
              }

              bool isColorSelected(Color color) {
                return colors.every((item) => item.value == color.value);
              }

              return SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('数字'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _optionButton(
                            selected: value == null,
                            onTap: () => updateValue(null),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: const Text('空'),
                          ),
                          ...List.generate(
                            10,
                            (index) => _optionButton(
                              selected: value == index,
                              onTap: () => updateValue(index),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(index.toString()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('颜色'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _optionButton(
                            selected: isColorSelected(_hitColor),
                            onTap: () => updateColors(_hitColor),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _colorIcon(_hitColor),
                                const SizedBox(width: 6),
                                const Text('红'),
                              ],
                            ),
                          ),
                          _optionButton(
                            selected: isColorSelected(_missColor),
                            onTap: () => updateColors(_missColor),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _colorIcon(_missColor),
                                const SizedBox(width: 6),
                                const Text('蓝'),
                              ],
                            ),
                          ),
                          _optionButton(
                            selected: isColorSelected(_baseColor),
                            onTap: () => updateColors(_baseColor),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _colorIcon(_baseColor, showClear: true),
                                const SizedBox(width: 6),
                                const Text('清空'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _optionButton(
                        selected: locked,
                        onTap: () => updateLocked(!locked),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              locked ? Icons.lock : Icons.lock_open,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(locked ? '已锁定' : '未锁定'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _optionButton({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
  }) {
    final borderColor =
        selected ? const Color(0xFF2A9D8F) : Colors.black26;
    final backgroundColor =
        selected ? const Color(0x142A9D8F) : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: padding,
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

  Widget _colorIcon(Color color, {bool showClear = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
          ),
        ),
        if (showClear)
          const Icon(
            Icons.close,
            size: 12,
            color: Colors.black54,
          ),
      ],
    );
  }

  Widget _iconOptionButton({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    final borderColor =
        selected ? const Color(0xFF2A9D8F) : Colors.black26;
    final textColor = selected ? const Color(0xFF2A9D8F) : Colors.black54;
    final backgroundColor =
        selected ? const Color(0x142A9D8F) : Colors.transparent;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compareModeButton({
    required CompareMode mode,
    required IconData icon,
    required String label,
  }) {
    return _iconOptionButton(
      selected: _mode == mode,
      onTap: () => _updateMode(mode),
      icon: icon,
      label: label,
    );
  }

  Widget _toggleOptionButton({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return _iconOptionButton(
      selected: selected,
      onTap: onTap,
      icon: icon,
      label: label,
    );
  }

  Widget _buildGridSection(double maxWidth) {
    final theme = Theme.of(context);
    final size = min(maxWidth, 520.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '数字',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: size,
            height: size,
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
                padding: const EdgeInsets.all(12),
                child: NumberGrid(
                  cells: _cells,
                  minorGap: _minorGap,
                  majorGap: _majorGap,
                  cellRadius: _cellRadius,
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
  }

  Widget _buildConfigPanel() {
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
              '配置',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                Row(
                  children: [
                    _compareModeButton(
                      mode: CompareMode.horizontal,
                      icon: Icons.swap_horiz,
                      label: '横向',
                    ),
                    const SizedBox(width: 8),
                    _compareModeButton(
                      mode: CompareMode.vertical,
                      icon: Icons.swap_vert,
                      label: '纵向',
                    ),
                    const SizedBox(width: 8),
                    _compareModeButton(
                      mode: CompareMode.diagonalDownRight,
                      icon: Icons.south_east,
                      label: '斜右下',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _compareModeButton(
                      mode: CompareMode.diagonalDownLeft,
                      icon: Icons.south_west,
                      label: '斜左下',
                    ),
                    const SizedBox(width: 8),
                    _toggleOptionButton(
                      selected: _cross3Compare,
                      onTap: _toggleCross3,
                      icon: Icons.filter_3,
                      label: '跨3比较',
                    ),
                    const SizedBox(width: 8),
                    _compareModeButton(
                      mode: CompareMode.fixed,
                      icon: Icons.push_pin,
                      label: '固定比较',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _randomizeAll,
                    icon: const Icon(Icons.casino, size: 16),
                    label: const Text('全体随机'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shiftUpAll,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('上移一行'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('染色阈值', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _threshold.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: _threshold.toString(),
                    onChanged: (value) {
                      _updateThreshold(value.round());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _recolor,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _threshold.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final gridSection = _buildGridSection(
                    constraints.maxWidth,
                  );
                  final configSection = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildConfigPanel(),
                  );
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: gridSection),
                        const SizedBox(width: 24),
                        configSection,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      gridSection,
                      const SizedBox(height: 24),
                      configSection,
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
