import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/distance_filter.dart';
import '../utils/color_utils.dart';

class CalculationPanel extends StatefulWidget {
  const CalculationPanel({
    super.key,
    required this.baseCombinationsBuilder,
    required this.hitColor,
    required this.missColor,
    required this.baseColor,
    this.onCustomCalculate,
    this.onTotalCalculate,
    this.onDistanceFiltersChanged,
  });

  final List<String> Function() baseCombinationsBuilder;
  final Color hitColor;
  final Color missColor;
  final Color baseColor;
  final VoidCallback? onCustomCalculate;
  final VoidCallback? onTotalCalculate;
  final ValueChanged<List<DistanceFilter>>? onDistanceFiltersChanged;

  @override
  State<CalculationPanel> createState() => CalculationPanelState();
}

enum _SizePattern {
  big3,
  small1big2,
  small2big1,
  small3,
}

enum _ParityPattern {
  odd3,
  odd1even2,
  odd2even1,
  even3,
}

enum _ShapePattern {
  concave,
  convex,
  ascending,
  descending,
  leaning,
}

enum _ConsecutivePattern {
  two,
  three,
  none,
}

class _RouteRequirement {
  final int route0;
  final int route1;
  final int route2;

  const _RouteRequirement({
    required this.route0,
    required this.route1,
    required this.route2,
  });
}

class _Option<T> {
  final T value;
  final String label;

  const _Option(this.value, this.label);
}

class CalculationPanelState extends State<CalculationPanel> {
  static const String _storageKey = 'calculation_panel_config_v1';

  final Map<int, Set<int>> _digitCountSelections = {};
  final Set<int> _mod3Remainders = {};
  final Set<int> _sumTailDigits = {};
  final Set<_SizePattern> _sizePatterns = {};
  final Set<_ParityPattern> _parityPatterns = {};
  final Set<int> _spanDiffs = {};
  final Set<_ShapePattern> _shapePatterns = {};
  final Set<_ConsecutivePattern> _consecutivePatterns = {};
  final List<Set<int>> _routeFilters =
      List.generate(3, (_) => <int>{});
  final List<DistanceFilter> _distanceFilters =
      List.filled(3, DistanceFilter.none);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleSelection<T>(Set<T> target, T value) {
    setState(() {
      if (target.contains(value)) {
        target.remove(value);
      } else {
        target.add(value);
      }
    });
    unawaited(_saveConfig());
  }

  void _toggleDigit(int digit) {
    setState(() {
      if (_digitCountSelections.containsKey(digit)) {
        _digitCountSelections.remove(digit);
      } else {
        _digitCountSelections[digit] = {1};
      }
    });
    unawaited(_saveConfig());
  }

  Future<void> _editDigitCounts(int digit) async {
    final current = _digitCountSelections[digit] ?? {1};
    final result = await _showCountPicker(
      title: '数字$digit出现次数',
      options: const [1, 2, 3],
      initial: current,
    );
    if (result == null) return;
    setState(() {
      if (result.isEmpty) {
        _digitCountSelections.remove(digit);
      } else {
        _digitCountSelections[digit] = result;
      }
    });
    unawaited(_saveConfig());
  }

  Future<void> _editRouteCounts(int index) async {
    final result = await _showCountPicker(
      title: '${index}路筛选',
      options: const [0, 1, 2, 3],
      initial: _routeFilters[index],
    );
    if (result == null) return;
    setState(() {
      _routeFilters[index]
        ..clear()
        ..addAll(result);
    });
    unawaited(_saveConfig());
  }

  List<DistanceFilter> get distanceFilters =>
      List<DistanceFilter>.from(_distanceFilters);

  void toggleDistanceFilter(int index) => _toggleDistanceFilter(index);

  void _notifyDistanceFilters() {
    widget.onDistanceFiltersChanged
        ?.call(List<DistanceFilter>.from(_distanceFilters));
  }

  void _toggleDistanceFilter(int index) {
    setState(() {
      final current = _distanceFilters[index];
      final next = DistanceFilter
          .values[(current.index + 1) % DistanceFilter.values.length];
      _distanceFilters[index] = next;
    });
    unawaited(_saveConfig());
    _notifyDistanceFilters();
  }

  Future<Set<int>?> _showCountPicker({
    required String title,
    required List<int> options,
    required Set<int> initial,
  }) {
    final selected = Set<int>.from(initial);
    return showDialog<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map(
                      (value) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(value),
                        title: Text('出现$value次'),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selected.add(value);
                            } else {
                              selected.remove(value);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Set<int> _intSetFrom(dynamic data) {
    if (data is! List) return {};
    final result = <int>{};
    for (final item in data) {
      if (item is num) {
        result.add(item.toInt());
      }
    }
    return result;
  }

  Map<int, Set<int>> _digitCountsFrom(dynamic data) {
    final result = <int, Set<int>>{};
    if (data is! List) return result;
    for (final entry in data) {
      if (entry is! Map) continue;
      final digitValue = entry['digit'];
      final countsValue = entry['counts'];
      if (digitValue is! num) continue;
      final digit = digitValue.toInt();
      if (digit < 0 || digit > 9) continue;
      final counts = _intSetFrom(countsValue);
      if (counts.isEmpty) continue;
      result[digit] = counts;
    }
    return result;
  }

  List<Set<int>> _routeFiltersFrom(dynamic data) {
    final result = List.generate(3, (_) => <int>{});
    if (data is! List) return result;
    for (int index = 0; index < result.length; index++) {
      if (index >= data.length) break;
      result[index] = _intSetFrom(data[index]);
    }
    return result;
  }

  List<DistanceFilter> _distanceFiltersFrom(dynamic data) {
    final result = List<DistanceFilter>.filled(
      3,
      DistanceFilter.none,
    );
    if (data is! List) return result;
    for (int index = 0; index < result.length; index++) {
      if (index >= data.length) break;
      final name = data[index];
      if (name is! String) continue;
      final match = DistanceFilter.values.firstWhere(
        (value) => value.name == name,
        orElse: () => result[index],
      );
      result[index] = match;
    }
    return result;
  }

  Set<T> _enumSetFromNames<T extends Enum>(List<T> values, dynamic data) {
    if (data is! List) return {};
    final result = <T>{};
    for (final item in data) {
      if (item is! String) continue;
      for (final value in values) {
        if (value.name == item) {
          result.add(value);
          break;
        }
      }
    }
    return result;
  }

  List<int> _sortedInts(Set<int> values) {
    final list = values.toList();
    list.sort();
    return list;
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;

    final digitCounts = _digitCountsFrom(decoded['digitCounts']);
    final mustHave = _intSetFrom(decoded['mustHave']);
    if (digitCounts.isEmpty && mustHave.isNotEmpty) {
      for (final digit in mustHave) {
        digitCounts[digit] = {1};
      }
    }
    final mod3 = _intSetFrom(decoded['mod3']);
    final sumTail = _intSetFrom(decoded['sumTail']);
    final span = _intSetFrom(decoded['span']);
    final size = _enumSetFromNames(_SizePattern.values, decoded['size']);
    final parity = _enumSetFromNames(_ParityPattern.values, decoded['parity']);
    final shape = _enumSetFromNames(_ShapePattern.values, decoded['shape']);
    final consecutive =
        _enumSetFromNames(_ConsecutivePattern.values, decoded['consecutive']);
    final routeFilters = _routeFiltersFrom(decoded['routeFilters']);
    if (routeFilters.every((set) => set.isEmpty)) {
      final legacyValues = [
        decoded['route0'],
        decoded['route1'],
        decoded['route2'],
      ];
      for (int index = 0; index < legacyValues.length; index++) {
        final value = legacyValues[index];
        if (value is num) {
          final count = value.toInt().clamp(0, 3);
          routeFilters[index].add(count);
        }
      }
    }
    final distanceFilters = _distanceFiltersFrom(decoded['distanceFilters']);

    if (!mounted) return;
    setState(() {
      _digitCountSelections
        ..clear()
        ..addAll(digitCounts);
      _mod3Remainders
        ..clear()
        ..addAll(mod3);
      _sumTailDigits
        ..clear()
        ..addAll(sumTail);
      _spanDiffs
        ..clear()
        ..addAll(span);
      _sizePatterns
        ..clear()
        ..addAll(size);
      _parityPatterns
        ..clear()
        ..addAll(parity);
      _shapePatterns
        ..clear()
        ..addAll(shape);
      _consecutivePatterns
        ..clear()
        ..addAll(consecutive);
      for (int index = 0; index < _routeFilters.length; index++) {
        _routeFilters[index]
          ..clear()
          ..addAll(routeFilters[index]);
      }
      for (int index = 0; index < _distanceFilters.length; index++) {
        _distanceFilters[index] = distanceFilters[index];
      }
    });
    _notifyDistanceFilters();
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'mustHave': _sortedInts(_digitCountSelections.keys.toSet()),
      'digitCounts': _digitCountSelections.entries
          .map(
            (entry) => {
              'digit': entry.key,
              'counts': _sortedInts(entry.value),
            },
          )
          .toList(),
      'mod3': _sortedInts(_mod3Remainders),
      'sumTail': _sortedInts(_sumTailDigits),
      'size': _sizePatterns.map((value) => value.name).toList(),
      'parity': _parityPatterns.map((value) => value.name).toList(),
      'span': _sortedInts(_spanDiffs),
      'shape': _shapePatterns.map((value) => value.name).toList(),
      'consecutive':
          _consecutivePatterns.map((value) => value.name).toList(),
      'routeFilters': _routeFilters.map(_sortedInts).toList(),
      'distanceFilters':
          _distanceFilters.map((value) => value.name).toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  void _clearAllFilters() {
    setState(() {
      _digitCountSelections.clear();
      _mod3Remainders.clear();
      _sumTailDigits.clear();
      _sizePatterns.clear();
      _parityPatterns.clear();
      _spanDiffs.clear();
      _shapePatterns.clear();
      _consecutivePatterns.clear();
      for (final filter in _routeFilters) {
        filter.clear();
      }
      for (int index = 0; index < _distanceFilters.length; index++) {
        _distanceFilters[index] = DistanceFilter.none;
      }
    });
    unawaited(_saveConfig());
    _notifyDistanceFilters();
  }

  void _showResultDialog(List<String> combinations) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text('计算结果（${combinations.length}组）'),
          content: SizedBox(
            width: 320,
            child: combinations.isEmpty
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
                          combinations.join(' '),
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

  List<String> buildFilteredCombinations() {
    final baseCombinations = widget.baseCombinationsBuilder();
    if (_noFiltersSelected()) {
      return baseCombinations;
    }

    final results = <String>[];
    for (final combination in baseCombinations) {
      final digits = _digitsFrom(combination);
      if (!_matchesFilters(digits)) continue;
      results.add(combination);
    }
    return results;
  }

  void _onCalculate() {
    final results = buildFilteredCombinations();
    _showResultDialog(results);
  }

  bool _noFiltersSelected() {
    final hasRouteFilter =
        _routeFilters.any((filter) => filter.isNotEmpty);
    final hasDistanceFilter =
        _distanceFilters.any((filter) => filter != DistanceFilter.none);
    return _digitCountSelections.isEmpty &&
        _mod3Remainders.isEmpty &&
        _sumTailDigits.isEmpty &&
        _sizePatterns.isEmpty &&
        _parityPatterns.isEmpty &&
        _spanDiffs.isEmpty &&
        _shapePatterns.isEmpty &&
        _consecutivePatterns.isEmpty &&
        !hasRouteFilter &&
        !hasDistanceFilter;
  }

  List<int> _digitsFrom(String combination) {
    if (combination.length != 3) return const [0, 0, 0];
    return [
      combination.codeUnitAt(0) - 48,
      combination.codeUnitAt(1) - 48,
      combination.codeUnitAt(2) - 48,
    ];
  }

  List<int> _digitCountsFor(List<int> digits) {
    final counts = List<int>.filled(10, 0);
    for (final digit in digits) {
      if (digit >= 0 && digit < counts.length) {
        counts[digit]++;
      }
    }
    return counts;
  }

  int _digitDiff(int a, int b) {
    final diff = (a - b).abs();
    return min(diff, 10 - diff);
  }

  bool _matchesDistanceFilter(DistanceFilter filter, int diff) {
    switch (filter) {
      case DistanceFilter.none:
        return true;
      case DistanceFilter.red:
        return diff <= 3;
      case DistanceFilter.blue:
        return diff > 3;
    }
  }

  String _countsLabel(Set<int> counts) {
    if (counts.isEmpty) return '不限';
    final sorted = counts.toList()..sort();
    return sorted.join(',');
  }

  String _digitCountLabel(int digit, Set<int> counts) {
    if (counts.isEmpty) return '$digit：不限';
    final sorted = counts.toList()..sort();
    return '$digit：${sorted.join('，')}次';
  }

  List<Widget> _withSpacing(List<Widget> children, double spacing) {
    final spaced = <Widget>[];
    for (int index = 0; index < children.length; index++) {
      spaced.add(children[index]);
      if (index != children.length - 1) {
        spaced.add(SizedBox(width: spacing));
      }
    }
    return spaced;
  }

  Widget _scrollRow(List<Widget> children, {double spacing = 8}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: _withSpacing(children, spacing)),
    );
  }

  bool _matchesFilters(List<int> digits) {
    if (_digitCountSelections.isNotEmpty) {
      final counts = _digitCountsFor(digits);
      for (final entry in _digitCountSelections.entries) {
        final digit = entry.key;
        final allowed = entry.value;
        if (allowed.isEmpty) continue;
        if (!allowed.contains(counts[digit])) {
          return false;
        }
      }
    }

    if (_mod3Remainders.isNotEmpty) {
      final value = digits[0] * 100 + digits[1] * 10 + digits[2];
      if (!_mod3Remainders.contains(value % 3)) {
        return false;
      }
    }

    if (_sumTailDigits.isNotEmpty) {
      final sumTail = (digits[0] + digits[1] + digits[2]) % 10;
      if (!_sumTailDigits.contains(sumTail)) {
        return false;
      }
    }

    if (_sizePatterns.isNotEmpty) {
      final pattern = _sizePatternFor(digits);
      if (!_sizePatterns.contains(pattern)) {
        return false;
      }
    }

    final routeCounts = _routeCountsFor(digits);
    if (_routeFilters[0].isNotEmpty &&
        !_routeFilters[0].contains(routeCounts.route0)) {
      return false;
    }
    if (_routeFilters[1].isNotEmpty &&
        !_routeFilters[1].contains(routeCounts.route1)) {
      return false;
    }
    if (_routeFilters[2].isNotEmpty &&
        !_routeFilters[2].contains(routeCounts.route2)) {
      return false;
    }

    if (_parityPatterns.isNotEmpty) {
      final pattern = _parityPatternFor(digits);
      if (!_parityPatterns.contains(pattern)) {
        return false;
      }
    }

    if (_spanDiffs.isNotEmpty) {
      final diff = _spanDiffFor(digits);
      if (!_spanDiffs.contains(diff)) {
        return false;
      }
    }

    if (_shapePatterns.isNotEmpty) {
      final matched = _shapePatternsFor(digits);
      if (matched.intersection(_shapePatterns).isEmpty) {
        return false;
      }
    }

    if (_consecutivePatterns.isNotEmpty) {
      final pattern = _consecutivePatternFor(digits);
      if (!_consecutivePatterns.contains(pattern)) {
        return false;
      }
    }

    final diff01 = _digitDiff(digits[0], digits[1]);
    final diff12 = _digitDiff(digits[1], digits[2]);
    final diff20 = _digitDiff(digits[2], digits[0]);
    if (!_matchesDistanceFilter(_distanceFilters[0], diff01)) {
      return false;
    }
    if (!_matchesDistanceFilter(_distanceFilters[1], diff12)) {
      return false;
    }
    if (!_matchesDistanceFilter(_distanceFilters[2], diff20)) {
      return false;
    }

    return true;
  }

  _SizePattern _sizePatternFor(List<int> digits) {
    final smallCount = digits.where((digit) => digit <= 4).length;
    switch (smallCount) {
      case 0:
        return _SizePattern.big3;
      case 1:
        return _SizePattern.small1big2;
      case 2:
        return _SizePattern.small2big1;
      default:
        return _SizePattern.small3;
    }
  }

  _ParityPattern _parityPatternFor(List<int> digits) {
    final oddCount = digits.where((digit) => digit.isOdd).length;
    switch (oddCount) {
      case 0:
        return _ParityPattern.even3;
      case 1:
        return _ParityPattern.odd1even2;
      case 2:
        return _ParityPattern.odd2even1;
      default:
        return _ParityPattern.odd3;
    }
  }

  _RouteRequirement _routeCountsFor(List<int> digits) {
    var route0 = 0;
    var route1 = 0;
    var route2 = 0;
    for (final digit in digits) {
      switch (digit % 3) {
        case 0:
          route0++;
          break;
        case 1:
          route1++;
          break;
        case 2:
          route2++;
          break;
      }
    }
    return _RouteRequirement(route0: route0, route1: route1, route2: route2);
  }

  int _spanDiffFor(List<int> digits) {
    var minValue = digits.first;
    var maxValue = digits.first;
    for (final digit in digits.skip(1)) {
      if (digit < minValue) {
        minValue = digit;
      } else if (digit > maxValue) {
        maxValue = digit;
      }
    }
    return maxValue - minValue;
  }

  Set<_ShapePattern> _shapePatternsFor(List<int> digits) {
    final patterns = <_ShapePattern>{};
    final a = digits[0];
    final b = digits[1];
    final c = digits[2];
    if (a == b || b == c) {
      patterns.add(_ShapePattern.leaning);
    }
    if (a < b && b < c) {
      patterns.add(_ShapePattern.ascending);
    }
    if (a > b && b > c) {
      patterns.add(_ShapePattern.descending);
    }
    if (a > b && b < c) {
      patterns.add(_ShapePattern.concave);
    }
    if (a < b && b > c) {
      patterns.add(_ShapePattern.convex);
    }
    return patterns;
  }

  _ConsecutivePattern _consecutivePatternFor(List<int> digits) {
    final values = digits.toSet().toList()..sort();
    var hasTwo = false;
    for (int index = 0; index < values.length; index++) {
      final value = values[index];
      if (values.contains(value + 1)) {
        hasTwo = true;
        if (values.contains(value + 2)) {
          return _ConsecutivePattern.three;
        }
      }
    }
    if (hasTwo) return _ConsecutivePattern.two;
    return _ConsecutivePattern.none;
  }

  Widget _toggleChip({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    final borderColor = selected ? kSelectionColor : Colors.black26;
    final backgroundColor =
        selected ? kSelectionFillColor : Colors.transparent;
    final textColor = selected ? kSelectionColor : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const divider = Divider(height: 20, color: Colors.black12);
    const sizeOptions = [
      _Option(_SizePattern.small3, '3小'),
      _Option(_SizePattern.small2big1, '2小'),
      _Option(_SizePattern.small1big2, '1小'),
      _Option(_SizePattern.big3, '0小'),
    ];
    const parityOptions = [
      _Option(_ParityPattern.odd3, '3奇'),
      _Option(_ParityPattern.odd2even1, '2奇'),
      _Option(_ParityPattern.odd1even2, '1奇'),
      _Option(_ParityPattern.even3, '0奇'),
    ];
    const shapeOptions = [
      _Option(_ShapePattern.concave, '凹型'),
      _Option(_ShapePattern.convex, '凸型'),
      _Option(_ShapePattern.ascending, '上升'),
      _Option(_ShapePattern.descending, '下降'),
      _Option(_ShapePattern.leaning, '偏型'),
    ];
    const consecutiveOptions = [
      _Option(_ConsecutivePattern.none, '0'),
      _Option(_ConsecutivePattern.two, '2'),
      _Option(_ConsecutivePattern.three, '3'),
    ];
    final selectedDigits = _digitCountSelections.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('清空配置'),
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
              child: ElevatedButton.icon(
                onPressed: _onCalculate,
                icon: const Icon(Icons.calculate),
                label: const Text('锁定计算'),
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onCustomCalculate,
                icon: const Icon(Icons.calculate_outlined, size: 16),
                label: const Text('自定义计算'),
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
              child: ElevatedButton.icon(
                onPressed: widget.onTotalCalculate,
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
        const SizedBox(height: 12),
        _section(
          title: '必选',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _scrollRow(
                List.generate(
                  10,
                  (index) => _toggleChip(
                    selected: _digitCountSelections.containsKey(index),
                    label: index.toString(),
                    onTap: () => _toggleDigit(index),
                  ),
                ),
              ),
              if (selectedDigits.isNotEmpty) ...[
                const SizedBox(height: 8),
                _scrollRow(
                  selectedDigits
                      .map(
                        (digit) => _toggleChip(
                          selected: true,
                          label: _digitCountLabel(
                            digit,
                            _digitCountSelections[digit] ?? const <int>{},
                          ),
                          onTap: () => _editDigitCounts(digit),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        divider,
        _section(
          title: '除3余数',
          child: _scrollRow(
            List.generate(
              3,
              (index) => _toggleChip(
                selected: _mod3Remainders.contains(index),
                label: index.toString(),
                onTap: () => _toggleSelection(_mod3Remainders, index),
              ),
            ),
          ),
        ),
        divider,
        _section(
          title: '合尾',
          child: _scrollRow(
            List.generate(
              10,
              (index) => _toggleChip(
                selected: _sumTailDigits.contains(index),
                label: index.toString(),
                onTap: () => _toggleSelection(_sumTailDigits, index),
              ),
            ),
          ),
        ),
        divider,
        _section(
          title: '小大',
          child: _scrollRow(
            sizeOptions
                .map(
                  (option) => _toggleChip(
                    selected: _sizePatterns.contains(option.value),
                    label: option.label,
                    onTap: () => _toggleSelection(_sizePatterns, option.value),
                  ),
                )
                .toList(),
          ),
        ),
        divider,
        _section(
          title: '012路',
          child: _scrollRow(
            List.generate(
              3,
              (index) => _toggleChip(
                selected: _routeFilters[index].isNotEmpty,
                label: '$index路:${_countsLabel(_routeFilters[index])}',
                onTap: () => _editRouteCounts(index),
              ),
            ),
          ),
        ),
        divider,
        _section(
          title: '奇偶',
          child: _scrollRow(
            parityOptions
                .map(
                  (option) => _toggleChip(
                    selected: _parityPatterns.contains(option.value),
                    label: option.label,
                    onTap: () => _toggleSelection(_parityPatterns, option.value),
                  ),
                )
                .toList(),
          ),
        ),
        divider,
        _section(
          title: '跨差',
          child: _scrollRow(
            List.generate(
              10,
              (index) => _toggleChip(
                selected: _spanDiffs.contains(index),
                label: index.toString(),
                onTap: () => _toggleSelection(_spanDiffs, index),
              ),
            ),
          ),
        ),
        divider,
        _section(
          title: '凹凸型',
          child: _scrollRow(
            shapeOptions
                .map(
                  (option) => _toggleChip(
                    selected: _shapePatterns.contains(option.value),
                    label: option.label,
                    onTap: () =>
                        _toggleSelection(_shapePatterns, option.value),
                  ),
                )
                .toList(),
          ),
        ),
        divider,
        _section(
          title: '连数',
          child: _scrollRow(
            consecutiveOptions
                .map(
                  (option) => _toggleChip(
                    selected: _consecutivePatterns.contains(option.value),
                    label: option.label,
                    onTap: () =>
                        _toggleSelection(_consecutivePatterns, option.value),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
