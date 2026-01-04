import 'dart:math';

import 'package:flutter/material.dart';

import '../models/cell_data.dart';
import '../models/diff_marker.dart';
import 'number_cell.dart';

class NumberGrid extends StatelessWidget {
  const NumberGrid({
    super.key,
    required this.cells,
    required this.onCellTap,
    required this.minorGap,
    required this.majorGap,
    required this.cellRadius,
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
  final List<DiffMarker> diffMarkers;
  final bool showFixedSelectors;
  final int? selectedRow;
  final int? selectedCol;
  final void Function(int row)? onRowSelect;
  final void Function(int col)? onColSelect;

  double _gapAfterIndex(int index) {
    return (index + 1) % 3 == 0 ? majorGap : minorGap;
  }

  double _gapBeforeIndex(int index) {
    var gap = 0.0;
    for (int i = 0; i < index; i++) {
      gap += _gapAfterIndex(i);
    }
    return gap;
  }

  double _totalGap(int count) {
    var gap = 0.0;
    for (int i = 0; i < count - 1; i++) {
      gap += _gapAfterIndex(i);
    }
    return gap;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = min(constraints.maxWidth, constraints.maxHeight);
        final selectorExtent = showFixedSelectors
            ? (extent * 0.045).clamp(12.0, 20.0)
            : 0.0;
        final selectorGap = showFixedSelectors
            ? (extent * 0.015).clamp(4.0, 8.0)
            : 0.0;
        final gridExtent = extent - selectorExtent - selectorGap;
        final totalGap = _totalGap(cells.length);
        final cellSize = (gridExtent - totalGap) / cells.length;
        final gridOffset = showFixedSelectors ? selectorExtent + selectorGap : 0.0;
        final markerFontSize = (cellSize * 0.22).clamp(9.0, 14.0);
        final markerBoxSize = (cellSize * 0.34).clamp(10.0, 18.0);
        final selectorColor = Theme.of(context).colorScheme.primary;

        double cellStartX(int col) {
          return gridOffset + col * cellSize + _gapBeforeIndex(col);
        }

        double cellStartY(int row) {
          return gridOffset + row * cellSize + _gapBeforeIndex(row);
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
              final gapWidth = _gapAfterIndex(boundaryIndex);
              final leftOfNext = cellStartX(boundaryIndex + 1);
              return Offset(leftOfNext - gapWidth / 2, cellCenterY(rowA));
            }
          }
          if (showFixedSelectors && selectedRow != null && colDiff == 0) {
            if (rowA == selectedRow || rowB == selectedRow) {
              final targetRow = rowA == selectedRow ? rowB : rowA;
              final boundaryIndex =
                  targetRow < selectedRow! ? targetRow : targetRow - 1;
              final gapHeight = _gapAfterIndex(boundaryIndex);
              final topOfNext = cellStartY(boundaryIndex + 1);
              return Offset(cellCenterX(colA), topOfNext - gapHeight / 2);
            }
          }
          if (rowDiff == 0 && (colDiff == 1 || colDiff == 3)) {
            final minCol = min(colA, colB);
            final boundaryIndex = minCol;
            final gapWidth = _gapAfterIndex(boundaryIndex);
            final leftOfNext = cellStartX(boundaryIndex + 1);
            return Offset(leftOfNext - gapWidth / 2, cellCenterY(rowA));
          }
          if (colDiff == 0 && (rowDiff == 1 || rowDiff == 3)) {
            final minRow = min(rowA, rowB);
            final boundaryIndex = minRow;
            final gapHeight = _gapAfterIndex(boundaryIndex);
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
            left: gridOffset,
            top: gridOffset,
            child: SizedBox(
              width: gridExtent,
              height: gridExtent,
              child: _buildGrid(cellSize),
            ),
          ),
        ];

        if (showFixedSelectors) {
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

          for (int row = 0; row < cells.length; row++) {
            stackChildren.add(
              Positioned(
                left: 0,
                top: cellCenterY(row) - selectorExtent / 2,
                child: selectorBox(
                  selected: selectedRow == row,
                  onTap:
                      onRowSelect == null ? null : () => onRowSelect!(row),
                ),
              ),
            );
          }
          for (int col = 0; col < cells.length; col++) {
            stackChildren.add(
              Positioned(
                top: 0,
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
                    child: Center(
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
          width: extent,
          height: extent,
          child: Stack(children: stackChildren),
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
              onTap: () => onCellTap(row, col),
            ),
          ),
        );
        if (col != cells[row].length - 1) {
          rowChildren.add(SizedBox(width: _gapAfterIndex(col)));
        }
      }
      rows.add(
        SizedBox(
          height: cellSize,
          child: Row(children: rowChildren),
        ),
      );
      if (row != cells.length - 1) {
        rows.add(SizedBox(height: _gapAfterIndex(row)));
      }
    }
    return Column(children: rows);
  }
}
