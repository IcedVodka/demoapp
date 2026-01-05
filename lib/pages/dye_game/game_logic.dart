import 'dart:math';
import 'dart:ui';

import '../../models/cell_data.dart';
import 'game_models.dart';

class GameLogic {
  static int digitDiff(int a, int b) {
    final diff = (a - b).abs();
    return min(diff, 10 - diff);
  }

  static Color? pairColor({
    required int? a,
    required int? b,
    required int threshold,
    required Color hitColor,
    required Color missColor,
  }) {
    if (a == null || b == null) return null;
    final diff = digitDiff(a, b);
    return diff <= threshold ? hitColor : missColor;
  }

  static int bitCount(int value) {
    var count = 0;
    var current = value;
    while (current > 0) {
      count += current & 1;
      current >>= 1;
    }
    return count;
  }

  static List<String> calculateBaseCombinations({
    required List<List<CellData>> cells,
    required Color hitColor,
    required Color missColor,
  }) {
    final allowedDigits = List.generate(
      3,
      (_) => <int>{0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
    );
    for (int row = 0; row < cells.length; row++) {
      final rowCells = cells[row];
      for (int col = 0; col < rowCells.length; col++) {
        final cell = rowCells[col];
        if (!cell.locked) continue;
        final value = cell.value;
        if (value == null) continue;
        final hasRed = _cellHasTargetColor(cell, hitColor);
        final hasBlue = _cellHasTargetColor(cell, missColor);
        if (!hasRed && !hasBlue) continue;
        final columnIndex = _digitColumnIndex(col);
        final toRemove = <int>{};
        for (int candidate = 0; candidate < 10; candidate++) {
          final distance = digitDiff(value, candidate);
          if (hasRed && (distance == 4 || distance == 5)) {
            toRemove.add(candidate);
          }
          if (hasBlue && (distance == 0 || distance == 1)) {
            toRemove.add(candidate);
          }
        }
        allowedDigits[columnIndex].removeAll(toRemove);
      }
    }
    return _buildCombinationsFromAllowed(allowedDigits);
  }

  static Set<String> calculateCustomCombinations({
    required List<List<CellData>> customCells,
    required List<RowPattern> customRowPatterns,
    required Color hitColor,
    required Color missColor,
  }) {
    Set<String>? merged;
    var hasRow = false;
    for (int row = 0; row < customCells.length; row++) {
      final digits = _customRowDigits(customCells[row]);
      if (digits == null) continue;
      hasRow = true;
      final pattern = row < customRowPatterns.length
          ? customRowPatterns[row]
          : RowPattern.red2blue1;
      final assignments = _rowColorAssignments(
        cells: customCells[row],
        pattern: pattern,
        hitColor: hitColor,
        missColor: missColor,
      );
      if (assignments.isEmpty) return <String>{};
      final rowResults = <String>{};
      for (final assignment in assignments) {
        rowResults.addAll(_combinationsForAssignment(digits, assignment));
      }
      if (merged == null) {
        merged = rowResults;
      } else {
        merged = merged.intersection(rowResults);
      }
      if (merged.isEmpty) return <String>{};
    }
    if (!hasRow) {
      return _allCombinationsSet();
    }
    return merged ?? <String>{};
  }

  static String? lockFilterSignatureForCell(
    CellData cell, {
    required Color hitColor,
    required Color missColor,
  }) {
    final value = cell.value;
    if (value == null) return null;
    final hasRed = _cellHasTargetColor(cell, hitColor);
    final hasBlue = _cellHasTargetColor(cell, missColor);
    if (!hasRed && !hasBlue) return null;
    final toRemove = <int>{};
    for (int candidate = 0; candidate < 10; candidate++) {
      final distance = digitDiff(value, candidate);
      if (hasRed && (distance == 4 || distance == 5)) {
        toRemove.add(candidate);
      }
      if (hasBlue && (distance == 0 || distance == 1)) {
        toRemove.add(candidate);
      }
    }
    final sorted = toRemove.toList()..sort();
    return sorted.join(',');
  }

  static bool _cellHasTargetColor(CellData cell, Color target) {
    return cell.colors.any((color) => color.value == target.value);
  }

  static int _digitColumnIndex(int col) => col % 3;

  static List<String> _buildCombinationsFromAllowed(
    List<Set<int>> allowedDigits,
  ) {
    final hundreds = allowedDigits[0].toList()..sort();
    final tens = allowedDigits[1].toList()..sort();
    final ones = allowedDigits[2].toList()..sort();
    final combinations = <String>[];
    for (final h in hundreds) {
      for (final t in tens) {
        for (final o in ones) {
          combinations.add('$h$t$o');
        }
      }
    }
    return combinations;
  }

  static List<int>? _customRowDigits(List<CellData> cells) {
    final digits = <int>[];
    for (final cell in cells) {
      final value = cell.value;
      if (value == null) return null;
      digits.add(value);
    }
    return digits;
  }

  static List<int> _customFixedColors({
    required List<CellData> cells,
    required Color hitColor,
    required Color missColor,
  }) {
    final colors = <int>[];
    for (final cell in cells) {
      final hasRed = _cellHasTargetColor(cell, hitColor);
      final hasBlue = _cellHasTargetColor(cell, missColor);
      if (hasRed) {
        colors.add(1);
      } else if (hasBlue) {
        colors.add(-1);
      } else {
        colors.add(0);
      }
    }
    return colors;
  }

  static List<List<bool>> _rowColorAssignments({
    required List<CellData> cells,
    required RowPattern pattern,
    required Color hitColor,
    required Color missColor,
  }) {
    final fixedColors = _customFixedColors(
      cells: cells,
      hitColor: hitColor,
      missColor: missColor,
    );
    final requiredRed = pattern.redCount;
    final requiredBlue = pattern.blueCount;
    final fixedRed = fixedColors.where((value) => value == 1).length;
    final fixedBlue = fixedColors.where((value) => value == -1).length;
    if (fixedRed > requiredRed || fixedBlue > requiredBlue) {
      return [];
    }
    final unknownIndices = <int>[];
    for (int index = 0; index < fixedColors.length; index++) {
      if (fixedColors[index] == 0) {
        unknownIndices.add(index);
      }
    }
    final remainingRed = requiredRed - fixedRed;
    if (remainingRed < 0 || remainingRed > unknownIndices.length) {
      return [];
    }
    final base = List<bool>.filled(cells.length, false);
    for (int index = 0; index < fixedColors.length; index++) {
      if (fixedColors[index] == 1) {
        base[index] = true;
      }
    }
    final assignments = <List<bool>>[];
    final totalMasks = 1 << unknownIndices.length;
    for (int mask = 0; mask < totalMasks; mask++) {
      if (bitCount(mask) != remainingRed) continue;
      final assignment = List<bool>.from(base);
      for (int bit = 0; bit < unknownIndices.length; bit++) {
        final index = unknownIndices[bit];
        assignment[index] = (mask & (1 << bit)) != 0;
      }
      assignments.add(assignment);
    }
    return assignments;
  }

  static Set<String> _combinationsForAssignment(
    List<int> digits,
    List<bool> isRed,
  ) {
    final allowedDigits = List.generate(
      3,
      (_) => <int>{0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
    );
    for (int index = 0; index < digits.length; index++) {
      final value = digits[index];
      final hasRed = isRed[index];
      final hasBlue = !isRed[index];
      allowedDigits[index].removeWhere((candidate) {
        final distance = digitDiff(value, candidate);
        if (hasRed && (distance == 4 || distance == 5)) {
          return true;
        }
        if (hasBlue && (distance == 0 || distance == 1)) {
          return true;
        }
        return false;
      });
    }
    return _buildCombinationsFromAllowed(allowedDigits).toSet();
  }

  static Set<String> _allCombinationsSet() {
    final combinations = <String>{};
    for (int h = 0; h < 10; h++) {
      for (int t = 0; t < 10; t++) {
        for (int o = 0; o < 10; o++) {
          combinations.add('$h$t$o');
        }
      }
    }
    return combinations;
  }
}
