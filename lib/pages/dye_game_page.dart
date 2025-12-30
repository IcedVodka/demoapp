import 'dart:math';

import 'package:flutter/material.dart';

import '../models/cell_data.dart';
import '../models/color_option.dart';
import '../models/compare_mode.dart';
import '../utils/color_utils.dart';
import '../widgets/number_grid.dart';

class DyeGamePage extends StatefulWidget {
  const DyeGamePage({super.key});

  @override
  State<DyeGamePage> createState() => _DyeGamePageState();
}

class _DyeGamePageState extends State<DyeGamePage> {
  static const int _gridSize = 6;
  static const double _minorGap = 6;
  static const double _majorGap = 14;
  static const double _cellRadius = 12;
  static const Color _baseColor = kBaseCellColor;
  Color _hitColor = const Color(0xFFE53935);
  Color _missColor = const Color(0xFF1E88E5);

  final List<List<CellData>> _cells = List.generate(
    _gridSize,
    (_) => List.generate(
      _gridSize,
      (_) => CellData(
        value: 0,
        colors: List<Color>.filled(4, _baseColor),
      ),
    ),
  );

  CompareMode _mode = CompareMode.horizontal;
  int _threshold = 2;

  void _applyColoring() {
    setState(() {
      for (int row = 0; row < _gridSize; row++) {
        for (int col = 0; col < _gridSize; col++) {
          final cell = _cells[row][col];
          if (cell.locked) continue;
          cell.colors = List<Color>.filled(4, _baseColor);
        }
      }
      switch (_mode) {
        case CompareMode.horizontal:
          for (int row = 0; row < _gridSize; row++) {
            for (int col = 0; col < _gridSize - 1; col++) {
              final color = _pairColor(
                _cells[row][col].value,
                _cells[row][col + 1].value,
              );
              _setRightHalf(row, col, color);
              _setLeftHalf(row, col + 1, color);
            }
          }
          break;
        case CompareMode.vertical:
          for (int row = 0; row < _gridSize - 1; row++) {
            for (int col = 0; col < _gridSize; col++) {
              final color = _pairColor(
                _cells[row][col].value,
                _cells[row + 1][col].value,
              );
              _setBottomHalf(row, col, color);
              _setTopHalf(row + 1, col, color);
            }
          }
          break;
        case CompareMode.diagonalDownRight:
          for (int row = 0; row < _gridSize - 1; row++) {
            for (int col = 0; col < _gridSize - 1; col++) {
              final color = _pairColor(
                _cells[row][col].value,
                _cells[row + 1][col + 1].value,
              );
              _setBottomRight(row, col, color);
              _setTopLeft(row + 1, col + 1, color);
            }
          }
          break;
        case CompareMode.diagonalDownLeft:
          for (int row = 0; row < _gridSize - 1; row++) {
            for (int col = 1; col < _gridSize; col++) {
              final color = _pairColor(
                _cells[row][col].value,
                _cells[row + 1][col - 1].value,
              );
              _setBottomLeft(row, col, color);
              _setTopRight(row + 1, col - 1, color);
            }
          }
          break;
      }
    });
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
  }

  void _clearAll() {
    setState(() {
      for (final row in _cells) {
        for (final cell in row) {
          if (cell.locked) continue;
          cell.value = 0;
          cell.colors = List<Color>.filled(4, _baseColor);
        }
      }
    });
  }

  Color _pairColor(int a, int b) {
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

  Future<void> _editCell(int row, int col) async {
    final cell = _cells[row][col];
    int value = cell.value;
    bool locked = cell.locked;
    final colors = List<Color>.from(cell.colors);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('编辑格子（${row + 1}, ${col + 1}）'),
          content: StatefulBuilder(
            builder: (context, setInnerState) {
              Future<void> pickColor(int index) async {
                final picked = await _showColorPicker(
                  context,
                  colors[index],
                );
                if (picked != null) {
                  setInnerState(() => colors[index] = picked);
                }
              }

              return SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('数字'),
                          const SizedBox(width: 12),
                          DropdownButton<int>(
                            value: value,
                            items: List.generate(
                              10,
                              (index) => DropdownMenuItem(
                                value: index,
                                child: Text(index.toString()),
                              ),
                            ),
                            onChanged: (newValue) {
                              if (newValue == null) return;
                              setInnerState(() => value = newValue);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('四分颜色'),
                      const SizedBox(height: 8),
                      _colorRow('左上', colors[0], () => pickColor(0)),
                      const SizedBox(height: 8),
                      _colorRow('右上', colors[1], () => pickColor(1)),
                      const SizedBox(height: 8),
                      _colorRow('左下', colors[2], () => pickColor(2)),
                      const SizedBox(height: 8),
                      _colorRow('右下', colors[3], () => pickColor(3)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: locked,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('锁定此格'),
                        subtitle: const Text('锁定后不参与染色与批量操作'),
                        onChanged: (newValue) {
                          setInnerState(() => locked = newValue);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      setState(() {
        cell.value = value;
        cell.locked = locked;
        cell.colors = colors;
      });
    }
  }

  Future<Color?> _showColorPicker(BuildContext context, Color current) {
    return showModalBottomSheet<Color>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kColorOptions.map((option) {
                final selected = option.color.value == current.value;
                return InkWell(
                  onTap: () => Navigator.pop(context, option.color),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? Colors.black87 : Colors.black12,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: option.color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickThresholdColor({required bool isHit}) async {
    final current = isHit ? _hitColor : _missColor;
    final picked = await _showColorPicker(context, current);
    if (picked == null) return;
    setState(() {
      if (isHit) {
        _hitColor = picked;
      } else {
        _missColor = picked;
      }
    });
  }

  Widget _colorRow(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 46, child: Text(label)),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(colorName(color))),
          ],
        ),
      ),
    );
  }

  Widget _thresholdColorPicker(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: textStyle),
            const SizedBox(height: 6),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSection(double maxWidth) {
    final theme = Theme.of(context);
    final size = min(maxWidth, 520.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '数字栏',
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
              '配置栏',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CompareMode>(
                    value: _mode,
                    isExpanded: true,
                    items: CompareMode.values
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(mode.label),
                          ),
                        )
                        .toList(),
                    onChanged: (mode) {
                      if (mode == null) return;
                      setState(() => _mode = mode);
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2A9D8F)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _clearAll,
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('全体清0'),
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
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('染色阈值', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thresholdColorPicker(
                  '≤阈值',
                  _hitColor,
                  () => _pickThresholdColor(isHit: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Slider(
                        value: _threshold.toDouble(),
                        min: 0,
                        max: 5,
                        divisions: 5,
                        label: _threshold.toString(),
                        onChanged: (value) {
                          setState(() => _threshold = value.round());
                        },
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _thresholdColorPicker(
                  '>阈值',
                  _missColor,
                  () => _pickThresholdColor(isHit: false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: _applyColoring,
                icon: const Icon(Icons.brush),
                label: const Text('开始染色'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hitColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
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
