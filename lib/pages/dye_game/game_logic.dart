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
    required List<List<CellData>> cells,
    required List<List<RowPattern>> groupPatterns,
  }) {
    Set<String>? merged;
    var hasGroup = false;
    final groupCount =
        groupPatterns.isNotEmpty ? groupPatterns.first.length : 0;
    for (int row = 0; row < cells.length; row++) {
      final rowCells = cells[row];
      final patterns =
          row < groupPatterns.length ? groupPatterns[row] : const <RowPattern>[];
      for (int group = 0; group < groupCount; group++) {
        final pattern =
            group < patterns.length ? patterns[group] : RowPattern.none;
        if (pattern.isNone) continue;
        final digits = _groupDigits(rowCells, group * 3, 3);
        if (digits == null) continue;
        hasGroup = true;
        final assignments = _assignmentsForRedCount(pattern.redCount);
        if (assignments.isEmpty) return <String>{};
        final groupResults = <String>{};
        for (final assignment in assignments) {
          groupResults.addAll(_combinationsForAssignment(digits, assignment));
        }
        if (merged == null) {
          merged = groupResults;
        } else {
          merged = merged.intersection(groupResults);
        }
        if (merged.isEmpty) return <String>{};
      }
    }
    if (!hasGroup) {
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

  static List<int>? _groupDigits(
    List<CellData> cells,
    int startCol,
    int length,
  ) {
    if (startCol + length > cells.length) return null;
    final digits = <int>[];
    for (int offset = 0; offset < length; offset++) {
      final value = cells[startCol + offset].value;
      if (value == null) return null;
      digits.add(value);
    }
    return digits;
  }

  static List<List<bool>> _assignmentsForRedCount(int redCount) {
    if (redCount < 0 || redCount > 3) return [];
    final assignments = <List<bool>>[];
    final totalMasks = 1 << 3;
    for (int mask = 0; mask < totalMasks; mask++) {
      if (bitCount(mask) != redCount) continue;
      assignments.add([
        (mask & 1) != 0,
        (mask & 2) != 0,
        (mask & 4) != 0,
      ]);
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
