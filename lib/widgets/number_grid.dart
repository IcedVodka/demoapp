import 'package:flutter/material.dart';

import '../models/cell_data.dart';
import 'number_cell.dart';

class NumberGrid extends StatelessWidget {
  const NumberGrid({
    super.key,
    required this.cells,
    required this.onCellTap,
    required this.minorGap,
    required this.majorGap,
    required this.cellRadius,
  });

  final List<List<CellData>> cells;
  final void Function(int row, int col) onCellTap;
  final double minorGap;
  final double majorGap;
  final double cellRadius;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int row = 0; row < cells.length; row++) {
      final rowChildren = <Widget>[];
      for (int col = 0; col < cells[row].length; col++) {
        rowChildren.add(
          Expanded(
            child: NumberCell(
              cell: cells[row][col],
              radius: cellRadius,
              onTap: () => onCellTap(row, col),
            ),
          ),
        );
        if (col != cells[row].length - 1) {
          rowChildren.add(
            SizedBox(width: col == 2 ? majorGap : minorGap),
          );
        }
      }
      rows.add(Expanded(child: Row(children: rowChildren)));
      if (row != cells.length - 1) {
        rows.add(SizedBox(height: row == 2 ? majorGap : minorGap));
      }
    }
    return Column(children: rows);
  }
}
