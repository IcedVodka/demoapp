import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/cell_data.dart';
import '../../models/compare_mode.dart';
import '../../utils/color_utils.dart';
import 'game_models.dart';

class GameStorage {
  static const String _storageKey = 'dye_game_state_v2';
  static const int _rowCount = 9;
  static const int _colCount = 6;
  static const int _customRowCount = 10;
  static const int _customColCount = 3;
  static const RowPattern _defaultRowPattern = RowPattern.red2blue1;

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    final cells = _parseCells(
      decoded['cells'],
      rows: _rowCount,
      cols: _colCount,
      baseColor: kBaseCellColor,
      includeLock: true,
      strictColors: true,
    );
    if (cells == null) return null;

    final customCells = _parseCells(
      decoded['customCells'],
      rows: _customRowCount,
      cols: _customColCount,
      baseColor: kBaseCellColor,
      includeLock: false,
      strictColors: false,
    );

    final customPatterns = _parsePatterns(decoded['customPatterns']);

    CompareMode? mode;
    final modeName = decoded['mode'];
    if (modeName is String) {
      mode = CompareMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => CompareMode.horizontal,
      );
    }

    int? threshold;
    final thresholdValue = decoded['threshold'];
    if (thresholdValue is num) {
      threshold = thresholdValue.round().clamp(0, 5).toInt();
    }

    final cross3Value = decoded['cross3Compare'];
    final cross3Compare = cross3Value is bool ? cross3Value : false;

    int? fixedRow;
    final fixedRowValue = decoded['fixedRow'];
    if (fixedRowValue is num) {
      final rowIndex = fixedRowValue.toInt();
      fixedRow = rowIndex >= 0 && rowIndex < _rowCount ? rowIndex : null;
    }

    int? fixedCol;
    final fixedColValue = decoded['fixedCol'];
    if (fixedColValue is num) {
      final colIndex = fixedColValue.toInt();
      fixedCol = colIndex >= 0 && colIndex < _colCount ? colIndex : null;
    }

    return {
      'cells': cells,
      'customCells': customCells,
      'customPatterns': customPatterns,
      'mode': mode,
      'threshold': threshold,
      'cross3Compare': cross3Compare,
      'fixedRow': fixedRow,
      'fixedCol': fixedCol,
    };
  }

  static Future<void> save({
    required List<List<CellData>> cells,
    required List<List<CellData>> customCells,
    required List<RowPattern> customPatterns,
    required CompareMode mode,
    required int threshold,
    required bool cross3Compare,
    required int? fixedRow,
    required int? fixedCol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'mode': mode.name,
      'threshold': threshold,
      'cross3Compare': cross3Compare,
      'fixedRow': fixedRow,
      'fixedCol': fixedCol,
      'cells': cells
          .map(
            (row) => row
                .map(
                  (cell) => {
                    'value': cell.value,
                    'locked': cell.locked,
                    'lockOrder': cell.lockOrder,
                    'colors': cell.colors.map((color) => color.value).toList(),
                  },
                )
                .toList(),
          )
          .toList(),
      'customCells': customCells
          .map(
            (row) => row
                .map(
                  (cell) => {
                    'value': cell.value,
                    'colors': cell.colors.map((color) => color.value).toList(),
                  },
                )
                .toList(),
          )
          .toList(),
      'customPatterns':
          customPatterns.map((pattern) => pattern.name).toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  static List<List<CellData>>? _parseCells(
    dynamic data, {
    required int rows,
    required int cols,
    required Color baseColor,
    required bool includeLock,
    required bool strictColors,
  }) {
    if (data is! List || data.length < rows) return null;
    final parsed = <List<CellData>>[];
    for (int rowIndex = 0; rowIndex < rows; rowIndex++) {
      final rowData = data[rowIndex];
      if (rowData is! List || rowData.length < cols) return null;
      final row = <CellData>[];
      for (int colIndex = 0; colIndex < cols; colIndex++) {
        final cellData = rowData[colIndex];
        if (cellData is! Map<String, dynamic>) return null;
        final colorsData = cellData['colors'];
        final colors = <Color>[];
        if (colorsData is List && colorsData.length == 4) {
          for (final colorValue in colorsData) {
            if (colorValue is num) {
              colors.add(Color(colorValue.toInt()));
            } else if (!strictColors) {
              colors.add(baseColor);
            } else {
              return null;
            }
          }
        } else if (strictColors) {
          return null;
        } else {
          colors.addAll(List<Color>.filled(4, baseColor));
        }
        final value = cellData['value'];
        final lockOrderValue = cellData['lockOrder'];
        final lockOrder =
            lockOrderValue is num ? lockOrderValue.toInt() : null;
        row.add(
          CellData(
            value: value is num ? value.toInt() : null,
            colors: colors,
            locked: includeLock ? cellData['locked'] == true : false,
            lockOrder: includeLock ? lockOrder : null,
          ),
        );
      }
      parsed.add(row);
    }
    return parsed;
  }

  static List<RowPattern>? _parsePatterns(dynamic data) {
    if (data is! List) return null;
    final parsedPatterns = List<RowPattern>.filled(
      _customRowCount,
      _defaultRowPattern,
    );
    final count = min(data.length, _customRowCount);
    for (int index = 0; index < count; index++) {
      final name = data[index];
      if (name is String) {
        final match = RowPattern.values.firstWhere(
          (pattern) => pattern.name == name,
          orElse: () => parsedPatterns[index],
        );
        parsedPatterns[index] = match;
      }
    }
    return parsedPatterns;
  }
}
