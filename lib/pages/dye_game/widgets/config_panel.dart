import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/cell_data.dart';
import '../../../models/compare_mode.dart';
import '../../../utils/color_utils.dart';

class GameConfigPanel extends StatelessWidget {
  const GameConfigPanel({
    super.key,
    required this.threshold,
    required this.mode,
    required this.cross3Compare,
    required this.cells,
    required this.baseColor,
    required this.onThresholdChanged,
    required this.onModeChanged,
    required this.onToggleCross3,
    required this.onRandomize,
    required this.onShiftUp,
    required this.onClearLocks,
    required this.onRecolor,
  });

  final int threshold;
  final CompareMode mode;
  final bool cross3Compare;
  final List<List<CellData>> cells;
  final Color baseColor;
  final ValueChanged<int> onThresholdChanged;
  final ValueChanged<CompareMode> onModeChanged;
  final VoidCallback onToggleCross3;
  final VoidCallback onRandomize;
  final VoidCallback onShiftUp;
  final VoidCallback onClearLocks;
  final VoidCallback onRecolor;

  int _digitColumnIndex(int col) => col % 3;

  List<_LockedCellEntry> _lockedEntriesForColumn(int columnIndex) {
    final entries = <_LockedCellEntry>[];
    for (int row = 0; row < cells.length; row++) {
      for (int col = 0; col < cells[row].length; col++) {
        final cell = cells[row][col];
        if (!cell.locked) continue;
        if (_digitColumnIndex(col) != columnIndex) continue;
        entries.add(
          _LockedCellEntry(
            row: row,
            col: col,
            value: cell.value,
            colors: List<Color>.from(cell.colors),
            order: cell.lockOrder ?? 0,
          ),
        );
      }
    }
    entries.sort((a, b) => a.order.compareTo(b.order));
    return entries;
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
    final borderRadius = BorderRadius.circular(10);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
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
      selected: this.mode == mode,
      onTap: () => onModeChanged(mode),
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

  Widget _buildLockDisplayGrid(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ['百位', '十位', '个位'];
    final entriesByColumn = List.generate(
      labels.length,
      (index) => _lockedEntriesForColumn(index),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        final halfGap = gap / 2;
        final maxWidth = constraints.maxWidth;
        final columnCount = labels.length;
        final availableWidth = maxWidth - gap * columnCount;
        final double cellSize = min<double>(
          36.0,
          availableWidth > 0 ? availableWidth / columnCount : 0.0,
        );
        final labelStyle = theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 10,
          color: Colors.black54,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                labels.length,
                (index) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: halfGap),
                  child: SizedBox(
                    width: cellSize,
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (int row = 0; row < 4; row++)
              Padding(
                padding: EdgeInsets.only(bottom: row == 3 ? 0 : 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    labels.length,
                    (col) {
                      final entries = entriesByColumn[col];
                      final entry = row < entries.length ? entries[row] : null;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: halfGap),
                        child: SizedBox(
                          width: cellSize,
                          height: cellSize,
                          child: _LockDisplayCell(
                            value: entry?.value,
                            colors: entry?.colors,
                            baseColor: baseColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: threshold.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: threshold.toString(),
                    onChanged: (value) {
                      onThresholdChanged(value.round());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onRecolor,
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
                      threshold.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
                      mode: CompareMode.fixed,
                      icon: Icons.push_pin,
                      label: '固定比较',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _toggleOptionButton(
                      selected: cross3Compare,
                      onTap: onToggleCross3,
                      icon: Icons.filter_3,
                      label: '跨3比较',
                    ),
                    const SizedBox(width: 8),
                    _compareModeButton(
                      mode: CompareMode.diagonalDownLeft,
                      icon: Icons.south_west,
                      label: '斜左下',
                    ),
                    const SizedBox(width: 8),
                    _compareModeButton(
                      mode: CompareMode.diagonalDownRight,
                      icon: Icons.south_east,
                      label: '斜右下',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _buildLockDisplayGrid(context),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onRandomize,
                        icon: const Icon(Icons.casino, size: 16),
                        label: const Text('全体随机'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onShiftUp,
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        label: const Text('上移一行'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onClearLocks,
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('清空锁定'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedCellEntry {
  final int row;
  final int col;
  final int? value;
  final List<Color> colors;
  final int order;

  const _LockedCellEntry({
    required this.row,
    required this.col,
    required this.value,
    required this.colors,
    required this.order,
  });
}

class _LockDisplayCell extends StatelessWidget {
  const _LockDisplayCell({
    required this.value,
    required this.colors,
    required this.baseColor,
  });

  final int? value;
  final List<Color>? colors;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColors =
        colors ?? List<Color>.filled(4, baseColor, growable: false);
    final textColor = bestTextColor(effectiveColors);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: Container(color: effectiveColors[0])),
                        Expanded(child: Container(color: effectiveColors[1])),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: Container(color: effectiveColors[2])),
                        Expanded(child: Container(color: effectiveColors[3])),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fontSize = constraints.maxWidth * 0.42;
                    return Center(
                      child: Text(
                        value?.toString() ?? '',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.25),
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
