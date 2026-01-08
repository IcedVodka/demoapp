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

class _Option<T> {
  final T value;
  final String label;

  const _Option(this.value, this.label);
}

class _DanGroup {
  final Set<int> digits;
  final Set<int> counts;

  const _DanGroup({
    required this.digits,
    required this.counts,
  });
}

class _RouteGroup {
  final Set<int> routes;
  final Set<int> counts;

  const _RouteGroup({
    required this.routes,
    required this.counts,
  });
}

class CalculationPanelState extends State<CalculationPanel> {
  static const String _storageKey = 'calculation_panel_config_v1';
  static const int _maxDanGroups = 4;
  static const int _maxRouteGroups = 4;

  final List<_DanGroup> _danGroups = [];
  final Set<int> _draftDanDigits = {};
  final Set<int> _draftDanCounts = {};
  final List<_RouteGroup> _routeGroups = [];
  final Set<int> _draftRouteRemainders = {};
  final Set<int> _draftRouteCounts = {};
  final Set<int> _mod3Remainders = {};
  final Set<int> _sumTailDigits = {};
  final Set<_SizePattern> _sizePatterns = {};
  final Set<_ParityPattern> _parityPatterns = {};
  final Set<int> _spanDiffs = {};
  final Set<_ShapePattern> _shapePatterns = {};
  final Set<_ConsecutivePattern> _consecutivePatterns = {};
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

  void _toggleDanDigit(int digit) {
    setState(() {
      if (_draftDanDigits.contains(digit)) {
        _draftDanDigits.remove(digit);
      } else {
        _draftDanDigits.add(digit);
      }
    });
  }

  void _toggleDanCount(int count) {
    setState(() {
      if (_draftDanCounts.contains(count)) {
        _draftDanCounts.remove(count);
      } else {
        _draftDanCounts.add(count);
      }
    });
  }

  void _addDanGroup() {
    if (_draftDanDigits.isEmpty || _draftDanCounts.isEmpty) return;
    if (_danGroups.length >= _maxDanGroups) return;
    setState(() {
      _danGroups.add(
        _DanGroup(
          digits: Set<int>.from(_draftDanDigits),
          counts: Set<int>.from(_draftDanCounts),
        ),
      );
      _draftDanDigits.clear();
      _draftDanCounts.clear();
    });
    unawaited(_saveConfig());
  }

  void _removeLastDanGroup() {
    if (_danGroups.isEmpty) return;
    setState(() {
      _danGroups.removeLast();
    });
    unawaited(_saveConfig());
  }

  void _toggleRouteRemainder(int remainder) {
    setState(() {
      if (_draftRouteRemainders.contains(remainder)) {
        _draftRouteRemainders.remove(remainder);
      } else {
        _draftRouteRemainders.add(remainder);
      }
    });
  }

  void _toggleRouteCount(int count) {
    setState(() {
      if (_draftRouteCounts.contains(count)) {
        _draftRouteCounts.remove(count);
      } else {
        _draftRouteCounts.add(count);
      }
    });
  }

  void _addRouteGroup() {
    if (_draftRouteRemainders.isEmpty || _draftRouteCounts.isEmpty) return;
    if (_routeGroups.length >= _maxRouteGroups) return;
    setState(() {
      _routeGroups.add(
        _RouteGroup(
          routes: Set<int>.from(_draftRouteRemainders),
          counts: Set<int>.from(_draftRouteCounts),
        ),
      );
      _draftRouteRemainders.clear();
      _draftRouteCounts.clear();
    });
    unawaited(_saveConfig());
  }

  void _removeLastRouteGroup() {
    if (_routeGroups.isEmpty) return;
    setState(() {
      _routeGroups.removeLast();
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

  Set<int> _danDigitsFrom(dynamic data) {
    final digits = _intSetFrom(data);
    digits.removeWhere((value) => value < 0 || value > 9);
    return digits;
  }

  Set<int> _danCountsFrom(dynamic data) {
    final counts = _intSetFrom(data);
    counts.removeWhere((value) => value < 1 || value > 3);
    return counts;
  }

  List<_DanGroup> _danGroupsFrom(dynamic data) {
    final result = <_DanGroup>[];
    if (data is! List) return result;
    for (final entry in data) {
      if (entry is! Map) continue;
      final digits = _danDigitsFrom(entry['digits']);
      final counts = _danCountsFrom(entry['counts']);
      if (digits.isEmpty || counts.isEmpty) continue;
      result.add(
        _DanGroup(
          digits: Set<int>.from(digits),
          counts: Set<int>.from(counts),
        ),
      );
      if (result.length >= _maxDanGroups) break;
    }
    return result;
  }

  Set<int> _routeRemaindersFrom(dynamic data) {
    final routes = _intSetFrom(data);
    routes.removeWhere((value) => value < 0 || value > 2);
    return routes;
  }

  Set<int> _routeCountsFrom(dynamic data) {
    final counts = _intSetFrom(data);
    counts.removeWhere((value) => value < 1 || value > 3);
    return counts;
  }

  List<_RouteGroup> _routeGroupsFrom(dynamic data) {
    final result = <_RouteGroup>[];
    if (data is! List) return result;
    for (final entry in data) {
      if (entry is! Map) continue;
      final routes = _routeRemaindersFrom(entry['routes']);
      final counts = _routeCountsFrom(entry['counts']);
      if (routes.isEmpty || counts.isEmpty) continue;
      result.add(
        _RouteGroup(
          routes: Set<int>.from(routes),
          counts: Set<int>.from(counts),
        ),
      );
      if (result.length >= _maxRouteGroups) break;
    }
    return result;
  }

  List<_RouteGroup> _routeGroupsFromLegacyFilters(dynamic data) {
    final result = <_RouteGroup>[];
    if (data is! List) return result;
    for (int index = 0; index < 3; index++) {
      if (index >= data.length) break;
      final counts = _routeCountsFrom(data[index]);
      if (counts.isEmpty) continue;
      result.add(
        _RouteGroup(
          routes: {index},
          counts: Set<int>.from(counts),
        ),
      );
      if (result.length >= _maxRouteGroups) break;
    }
    return result;
  }

  List<_RouteGroup> _routeGroupsFromLegacyValues(
    List<dynamic> values,
  ) {
    final result = <_RouteGroup>[];
    for (int index = 0; index < 3; index++) {
      if (index >= values.length) break;
      final value = values[index];
      if (value is num) {
        final count = value.toInt().clamp(0, 3);
        if (count >= 1 && count <= 3) {
          result.add(
            _RouteGroup(
              routes: {index},
              counts: {count},
            ),
          );
        }
      }
      if (result.length >= _maxRouteGroups) break;
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

    final danGroups = _danGroupsFrom(decoded['danGroups']);
    final mod3 = _intSetFrom(decoded['mod3']);
    final sumTail = _intSetFrom(decoded['sumTail']);
    final span = _intSetFrom(decoded['span']);
    final size = _enumSetFromNames(_SizePattern.values, decoded['size']);
    final parity = _enumSetFromNames(_ParityPattern.values, decoded['parity']);
    final shape = _enumSetFromNames(_ShapePattern.values, decoded['shape']);
    final consecutive =
        _enumSetFromNames(_ConsecutivePattern.values, decoded['consecutive']);
    var routeGroups = _routeGroupsFrom(decoded['routeGroups']);
    if (routeGroups.isEmpty) {
      routeGroups = _routeGroupsFromLegacyFilters(decoded['routeFilters']);
    }
    if (routeGroups.isEmpty) {
      routeGroups = _routeGroupsFromLegacyValues([
        decoded['route0'],
        decoded['route1'],
        decoded['route2'],
      ]);
    }
    final distanceFilters = _distanceFiltersFrom(decoded['distanceFilters']);

    if (!mounted) return;
    setState(() {
      _danGroups
        ..clear()
        ..addAll(danGroups);
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
      _routeGroups
        ..clear()
        ..addAll(routeGroups);
      for (int index = 0; index < _distanceFilters.length; index++) {
        _distanceFilters[index] = distanceFilters[index];
      }
    });
    _notifyDistanceFilters();
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'danGroups': _danGroups
          .map(
            (group) => {
              'digits': _sortedInts(group.digits),
              'counts': _sortedInts(group.counts),
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
      'routeGroups': _routeGroups
          .map(
            (group) => {
              'routes': _sortedInts(group.routes),
              'counts': _sortedInts(group.counts),
            },
          )
          .toList(),
      'distanceFilters':
          _distanceFilters.map((value) => value.name).toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  void _clearAllFilters() {
    setState(() {
      _danGroups.clear();
      _draftDanDigits.clear();
      _draftDanCounts.clear();
      _routeGroups.clear();
      _draftRouteRemainders.clear();
      _draftRouteCounts.clear();
      _mod3Remainders.clear();
      _sumTailDigits.clear();
      _sizePatterns.clear();
      _parityPatterns.clear();
      _spanDiffs.clear();
      _shapePatterns.clear();
      _consecutivePatterns.clear();
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
    final hasDistanceFilter =
        _distanceFilters.any((filter) => filter != DistanceFilter.none);
    return _danGroups.isEmpty &&
        _mod3Remainders.isEmpty &&
        _sumTailDigits.isEmpty &&
        _sizePatterns.isEmpty &&
        _parityPatterns.isEmpty &&
        _spanDiffs.isEmpty &&
        _shapePatterns.isEmpty &&
        _consecutivePatterns.isEmpty &&
        _routeGroups.isEmpty &&
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

  String _danGroupLabel(_DanGroup group) {
    final digits = group.digits.toList()..sort();
    final counts = group.counts.toList()..sort();
    final digitLabel = digits.join(',');
    final countLabel = counts.join(',');
    return '$digitLabel-$countLabel';
  }

  String _routeGroupLabel(_RouteGroup group) {
    final routes = group.routes.toList()..sort();
    final counts = group.counts.toList()..sort();
    final routeLabel = routes.join(',');
    final countLabel = counts.join(',');
    return '$routeLabel路-$countLabel';
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
    if (_danGroups.isNotEmpty) {
      for (final group in _danGroups) {
        var hitCount = 0;
        for (final digit in digits) {
          if (group.digits.contains(digit)) {
            hitCount++;
          }
        }
        if (!group.counts.contains(hitCount)) {
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

    if (_routeGroups.isNotEmpty) {
      for (final group in _routeGroups) {
        var hitCount = 0;
        for (final digit in digits) {
          if (group.routes.contains(digit % 3)) {
            hitCount++;
          }
        }
        if (!group.counts.contains(hitCount)) {
          return false;
        }
      }
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

  Widget _staticChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kSelectionFillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kSelectionColor.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: kSelectionColor,
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
      _Option(_SizePattern.big3, '3大'),
    ];
    const parityOptions = [
      _Option(_ParityPattern.odd3, '3奇'),
      _Option(_ParityPattern.odd2even1, '2奇'),
      _Option(_ParityPattern.odd1even2, '1奇'),
      _Option(_ParityPattern.even3, '3偶'),
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
    final canAddDanGroup = _draftDanDigits.isNotEmpty &&
        _draftDanCounts.isNotEmpty &&
        _danGroups.length < _maxDanGroups;
    final canRemoveDanGroup = _danGroups.isNotEmpty;
    final canAddRouteGroup = _draftRouteRemainders.isNotEmpty &&
        _draftRouteCounts.isNotEmpty &&
        _routeGroups.length < _maxRouteGroups;
    final canRemoveRouteGroup = _routeGroups.isNotEmpty;

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
          title: '胆码组',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _scrollRow(
                List.generate(
                  10,
                  (index) => _toggleChip(
                    selected: _draftDanDigits.contains(index),
                    label: index.toString(),
                    onTap: () => _toggleDanDigit(index),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _scrollRow(
                      List.generate(
                        3,
                        (index) => _toggleChip(
                          selected: _draftDanCounts.contains(index + 1),
                          label: '${index + 1}',
                          onTap: () => _toggleDanCount(index + 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: canAddDanGroup ? _addDanGroup : null,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('添加一组'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                canRemoveDanGroup ? _removeLastDanGroup : null,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('删除最近一组'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_danGroups.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _danGroups
                      .map((group) => _staticChip(_danGroupLabel(group)))
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _scrollRow(
                List.generate(
                  3,
                  (index) => _toggleChip(
                    selected: _draftRouteRemainders.contains(index),
                    label: '${index}路',
                    onTap: () => _toggleRouteRemainder(index),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _scrollRow(
                      List.generate(
                        3,
                        (index) => _toggleChip(
                          selected: _draftRouteCounts.contains(index + 1),
                          label: '${index + 1}',
                          onTap: () => _toggleRouteCount(index + 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                canAddRouteGroup ? _addRouteGroup : null,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('添加一组'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: canRemoveRouteGroup
                                ? _removeLastRouteGroup
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('删除最近一组'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_routeGroups.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _routeGroups
                      .map((group) => _staticChip(_routeGroupLabel(group)))
                      .toList(),
                ),
              ],
            ],
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
