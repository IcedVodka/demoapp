import 'dart:math';

import 'package:flutter/material.dart';

import '../models/cell_data.dart';
import '../models/diff_marker.dart';
import '../utils/color_utils.dart';
import 'number_cell.dart';

class SummaryCellData {
  final String label;
  final List<Color> colors;
  final VoidCallback? onTap;

  const SummaryCellData({
    required this.label,
    required this.colors,
    this.onTap,
  });
}

class NumberGrid extends StatelessWidget {
  const NumberGrid({
    super.key,
    required this.cells,
    required this.onCellTap,
    required this.minorGap,
    required this.majorGap,
    required this.cellRadius,
    this.rowGapOverrides = const {},
    this.leftSummaries,
    this.rightSummaries,
    this.summaryScale = 0.62,
    this.summaryGap = 8,
    this.showBall = false,
    this.diffMarkers = const [],
    this.showFixedSelectors = false,
    this.selectedRow,
    this.selectedCol,
    this.onRowSelect,
    this.onColSelect,
  });

  final List<List<CellData>> cells;
  final void Function(int row, int col) onCellTap;
  final double minorGap;
  final double majorGap;
  final double cellRadius;
  final Set<int> rowGapOverrides;
  final List<SummaryCellData>? leftSummaries;
  final List<SummaryCellData>? rightSummaries;
  final double summaryScale;
  final double summaryGap;
  final bool showBall;
  final List<DiffMarker> diffMarkers;
  final bool showFixedSelectors;
  final int? selectedRow;
  final int? selectedCol;
  final void Function(int row)? onRowSelect;
  final void Function(int col)? onColSelect;

  double _gapAfterIndex(int index, {required bool isRow}) {
    if (isRow && rowGapOverrides.contains(index)) {
      return minorGap;
    }
    return (index + 1) % 3 == 0 ? majorGap : minorGap;
  }

  double _gapBeforeIndex(int index, {required bool isRow}) {
    var gap = 0.0;
    for (int i = 0; i < index; i++) {
      gap += _gapAfterIndex(i, isRow: isRow);
    }
    return gap;
  }

  double _totalGap(int count, {required bool isRow}) {
    var gap = 0.0;
    for (int i = 0; i < count - 1; i++) {
      gap += _gapAfterIndex(i, isRow: isRow);
    }
    return gap;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowCount = cells.length;
        if (rowCount == 0) {
          return const SizedBox.shrink();
        }
        final colCount = cells.first.length;
        if (colCount == 0) {
          return const SizedBox.shrink();
        }
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final extent = min(maxWidth, maxHeight);
        final selectorExtent = showFixedSelectors
            ? (extent * 0.045).clamp(12.0, 20.0)
            : 0.0;
        final selectorGap = showFixedSelectors
            ? (extent * 0.015).clamp(4.0, 8.0)
            : 0.0;
        final gridOffset =
            showFixedSelectors ? selectorExtent + selectorGap : 0.0;
        final availableWidth = maxWidth - gridOffset;
        final availableHeight = maxHeight - gridOffset;
        final totalRowGap = _totalGap(rowCount, isRow: true);
        final totalColGap = _totalGap(colCount, isRow: false);
        final leftSummarySource = leftSummaries;
        final rightSummarySource = rightSummaries;
        final leftSummaryEnabled =
            leftSummarySource != null && leftSummarySource.isNotEmpty;
        final rightSummaryEnabled =
            rightSummarySource != null && rightSummarySource.isNotEmpty;
        final summaryCount =
            (leftSummaryEnabled ? 1 : 0) + (rightSummaryEnabled ? 1 : 0);
        final summaryEnabled = summaryCount > 0;
        final summaryOuterGap = (leftSummaryEnabled ? summaryGap : 0.0) +
            (rightSummaryEnabled ? summaryGap : 0.0);
        final widthBudget = summaryEnabled
            ? max(0.0, availableWidth - totalColGap - summaryOuterGap)
            : max(0.0, availableWidth - totalColGap);
        final widthBasedCellSize = summaryEnabled
            ? widthBudget / (colCount + summaryCount * summaryScale)
            : widthBudget / colCount;
        final heightBudget = max(0.0, availableHeight - totalRowGap);
        final heightBasedCellSize = heightBudget / rowCount;
        final cellSize = min(widthBasedCellSize, heightBasedCellSize);
        final actualGridWidth = cellSize * colCount + totalColGap;
        final actualGridHeight = cellSize * rowCount + totalRowGap;
        final summaryCellSize =
            summaryEnabled ? cellSize * summaryScale : 0.0;
        final summaryWidth =
            summaryEnabled ? summaryCount * summaryCellSize : 0.0;
        final contentWidth =
            actualGridWidth + (summaryEnabled ? summaryOuterGap + summaryWidth : 0.0);
        final extraX = (availableWidth - contentWidth) / 2;
        final extraY = (availableHeight - actualGridHeight) / 2;
        final gridStartX = gridOffset +
            max(0.0, extraX) +
            (leftSummaryEnabled ? summaryCellSize + summaryGap : 0.0);
        final gridStartY = gridOffset + max(0.0, extraY);
        final leftSummaryStartX = gridOffset + max(0.0, extraX);
        final rightSummaryStartX =
            gridStartX + actualGridWidth + (rightSummaryEnabled ? summaryGap : 0.0);
        final markerFontSize = (cellSize * 0.22).clamp(9.0, 14.0);
        final markerBoxSize = (cellSize * 0.34).clamp(10.0, 18.0);
        final selectorColor = Theme.of(context).colorScheme.primary;

        double cellStartX(int col) {
          return gridStartX +
              col * cellSize +
              _gapBeforeIndex(col, isRow: false);
        }

        double cellStartY(int row) {
          return gridStartY +
              row * cellSize +
              _gapBeforeIndex(row, isRow: true);
        }

        double cellCenterX(int col) => cellStartX(col) + cellSize / 2;
        double cellCenterY(int row) => cellStartY(row) + cellSize / 2;

        Offset markerCenter(DiffMarker marker) {
          final rowA = marker.rowA;
          final rowB = marker.rowB;
          final colA = marker.colA;
          final colB = marker.colB;
          final rowDiff = (rowA - rowB).abs();
          final colDiff = (colA - colB).abs();
          if (showFixedSelectors && selectedCol != null && rowDiff == 0) {
            if (colA == selectedCol || colB == selectedCol) {
              final targetCol = colA == selectedCol ? colB : colA;
              final boundaryIndex =
                  targetCol < selectedCol! ? targetCol : targetCol - 1;
              final gapWidth =
                  _gapAfterIndex(boundaryIndex, isRow: false);
              final leftOfNext = cellStartX(boundaryIndex + 1);
              return Offset(leftOfNext - gapWidth / 2, cellCenterY(rowA));
            }
          }
          if (showFixedSelectors && selectedRow != null && colDiff == 0) {
            if (rowA == selectedRow || rowB == selectedRow) {
              final targetRow = rowA == selectedRow ? rowB : rowA;
              final boundaryIndex =
                  targetRow < selectedRow! ? targetRow : targetRow - 1;
              final gapHeight = _gapAfterIndex(boundaryIndex, isRow: true);
              final topOfNext = cellStartY(boundaryIndex + 1);
              return Offset(cellCenterX(colA), topOfNext - gapHeight / 2);
            }
          }
          if (rowDiff == 0 && (colDiff == 1 || colDiff == 3)) {
            final minCol = min(colA, colB);
            final boundaryIndex = minCol;
            final gapWidth = _gapAfterIndex(boundaryIndex, isRow: false);
            final leftOfNext = cellStartX(boundaryIndex + 1);
            return Offset(leftOfNext - gapWidth / 2, cellCenterY(rowA));
          }
          if (colDiff == 0 && (rowDiff == 1 || rowDiff == 3)) {
            final minRow = min(rowA, rowB);
            final boundaryIndex = minRow;
            final gapHeight = _gapAfterIndex(boundaryIndex, isRow: true);
            final topOfNext = cellStartY(boundaryIndex + 1);
            return Offset(cellCenterX(colA), topOfNext - gapHeight / 2);
          }
          final centerX = (cellCenterX(colA) + cellCenterX(colB)) / 2;
          final centerY = (cellCenterY(rowA) + cellCenterY(rowB)) / 2;
          return Offset(centerX, centerY);
        }
        const markerTextColor = Colors.black;

        final stackChildren = <Widget>[
          Positioned(
            left: gridStartX,
            top: gridStartY,
            child: SizedBox(
              width: actualGridWidth,
              height: actualGridHeight,
              child: _buildGrid(cellSize),
            ),
          ),
        ];

        if (showFixedSelectors) {
          final selectorLeft = leftSummaryEnabled
              ? leftSummaryStartX - selectorGap - selectorExtent
              : gridStartX - selectorGap - selectorExtent;
          final selectorTop = gridStartY - selectorGap - selectorExtent;
          Widget selectorBox({
            required bool selected,
            required VoidCallback? onTap,
          }) {
            final borderColor =
                selected ? selectorColor : Colors.black26;
            final fillColor = selected
                ? selectorColor.withOpacity(0.28)
                : Colors.transparent;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  width: selectorExtent,
                  height: selectorExtent,
                  decoration: BoxDecoration(
                    color: fillColor,
                    border: Border.all(color: borderColor),
                  ),
                ),
              ),
            );
          }

          for (int row = 0; row < rowCount; row++) {
            stackChildren.add(
              Positioned(
                left: selectorLeft,
                top: cellCenterY(row) - selectorExtent / 2,
                child: selectorBox(
                  selected: selectedRow == row,
                  onTap:
                      onRowSelect == null ? null : () => onRowSelect!(row),
                ),
              ),
            );
          }
          for (int col = 0; col < colCount; col++) {
            stackChildren.add(
              Positioned(
                top: selectorTop,
                left: cellCenterX(col) - selectorExtent / 2,
                child: selectorBox(
                  selected: selectedCol == col,
                  onTap:
                      onColSelect == null ? null : () => onColSelect!(col),
                ),
              ),
            );
          }
        }

        if (summaryEnabled) {
          for (int row = 0; row < rowCount; row++) {
            final top = cellStartY(row) + (cellSize - summaryCellSize) / 2;
            if (leftSummaryEnabled &&
                leftSummarySource != null &&
                row < leftSummarySource.length) {
              stackChildren.add(
                Positioned(
                  left: leftSummaryStartX,
                  top: top,
                  child: _SummaryCell(
                    data: leftSummarySource[row],
                    size: summaryCellSize,
                  ),
                ),
              );
            }
            if (rightSummaryEnabled &&
                rightSummarySource != null &&
                row < rightSummarySource.length) {
              stackChildren.add(
                Positioned(
                  left: rightSummaryStartX,
                  top: top,
                  child: _SummaryCell(
                    data: rightSummarySource[row],
                    size: summaryCellSize,
                  ),
                ),
              );
            }
          }
        }

        if (diffMarkers.isNotEmpty) {
          for (final marker in diffMarkers) {
            final center = markerCenter(marker);
            stackChildren.add(
              Positioned(
                left: center.dx - markerBoxSize / 2,
                top: center.dy - markerBoxSize / 2,
                child: IgnorePointer(
                  child: SizedBox(
                    width: markerBoxSize,
                    height: markerBoxSize,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        marker.value.toString(),
                        style: TextStyle(
                          fontSize: markerFontSize,
                          fontWeight: FontWeight.w600,
                          color: markerTextColor,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.25),
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return SizedBox(
          width: maxWidth,
          height: maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: stackChildren,
          ),
        );
      },
    );
  }

  Widget _buildGrid(double cellSize) {
    final rows = <Widget>[];
    for (int row = 0; row < cells.length; row++) {
      final rowChildren = <Widget>[];
      for (int col = 0; col < cells[row].length; col++) {
        rowChildren.add(
          SizedBox(
            width: cellSize,
            height: cellSize,
            child: NumberCell(
              cell: cells[row][col],
              radius: cellRadius,
              showBall: showBall,
              onTap: () => onCellTap(row, col),
            ),
          ),
        );
        if (col != cells[row].length - 1) {
          rowChildren.add(
            SizedBox(width: _gapAfterIndex(col, isRow: false)),
          );
        }
      }
      rows.add(
        SizedBox(
          height: cellSize,
          child: Row(children: rowChildren),
        ),
      );
      if (row != cells.length - 1) {
        rows.add(SizedBox(height: _gapAfterIndex(row, isRow: true)));
      }
    }
    return Column(children: rows);
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.data,
    required this.size,
  });

  final SummaryCellData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fontSize = size * 0.42;
    final colors =
        data.colors.length == 4 ? data.colors : List<Color>.filled(4, kBaseCellColor);
    final textColor = bestTextColor(colors);
    final borderRadius = BorderRadius.circular(8);
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.onTap,
          borderRadius: borderRadius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: Colors.black26),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  _Quadrants(colors: colors),
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        data.label,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Quadrants extends StatelessWidget {
  const _Quadrants({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _Quadrant(color: colors[0])),
              Expanded(child: _Quadrant(color: colors[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _Quadrant(color: colors[2])),
              Expanded(child: _Quadrant(color: colors[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _Quadrant extends StatelessWidget {
  const _Quadrant({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(color: color);
  }
}
