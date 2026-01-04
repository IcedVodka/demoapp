import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalculationPanel extends StatefulWidget {
  const CalculationPanel({
    super.key,
    required this.baseCombinationsBuilder,
  });

  final List<String> Function() baseCombinationsBuilder;

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

  final Set<int> _mustHaveDigits = {};
  final Set<int> _mod3Remainders = {};
  final Set<int> _sumTailDigits = {};
  final Set<_SizePattern> _sizePatterns = {};
  final Set<_ParityPattern> _parityPatterns = {};
  final Set<int> _spanDiffs = {};
  final Set<_ShapePattern> _shapePatterns = {};
  final Set<_ConsecutivePattern> _consecutivePatterns = {};

  final TextEditingController _route0Controller = TextEditingController();
  final TextEditingController _route1Controller = TextEditingController();
  final TextEditingController _route2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _route0Controller.dispose();
    _route1Controller.dispose();
    _route2Controller.dispose();
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

    final mustHave = _intSetFrom(decoded['mustHave']);
    final mod3 = _intSetFrom(decoded['mod3']);
    final sumTail = _intSetFrom(decoded['sumTail']);
    final span = _intSetFrom(decoded['span']);
    final size = _enumSetFromNames(_SizePattern.values, decoded['size']);
    final parity = _enumSetFromNames(_ParityPattern.values, decoded['parity']);
    final shape = _enumSetFromNames(_ShapePattern.values, decoded['shape']);
    final consecutive =
        _enumSetFromNames(_ConsecutivePattern.values, decoded['consecutive']);

    if (!mounted) return;
    setState(() {
      _mustHaveDigits
        ..clear()
        ..addAll(mustHave);
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
      _route0Controller.text = decoded['route0']?.toString() ?? '';
      _route1Controller.text = decoded['route1']?.toString() ?? '';
      _route2Controller.text = decoded['route2']?.toString() ?? '';
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'mustHave': _sortedInts(_mustHaveDigits),
      'mod3': _sortedInts(_mod3Remainders),
      'sumTail': _sortedInts(_sumTailDigits),
      'size': _sizePatterns.map((value) => value.name).toList(),
      'parity': _parityPatterns.map((value) => value.name).toList(),
      'span': _sortedInts(_spanDiffs),
      'shape': _shapePatterns.map((value) => value.name).toList(),
      'consecutive':
          _consecutivePatterns.map((value) => value.name).toList(),
      'route0': _route0Controller.text.trim(),
      'route1': _route1Controller.text.trim(),
      'route2': _route2Controller.text.trim(),
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  void _clearAllFilters() {
    setState(() {
      _mustHaveDigits.clear();
      _mod3Remainders.clear();
      _sumTailDigits.clear();
      _sizePatterns.clear();
      _parityPatterns.clear();
      _spanDiffs.clear();
      _shapePatterns.clear();
      _consecutivePatterns.clear();
      _route0Controller.clear();
      _route1Controller.clear();
      _route2Controller.clear();
    });
    unawaited(_saveConfig());
  }

  bool _hasRouteInput() {
    return _route0Controller.text.trim().isNotEmpty ||
        _route1Controller.text.trim().isNotEmpty ||
        _route2Controller.text.trim().isNotEmpty;
  }

  _RouteRequirement? _parseRouteRequirement() {
    if (!_hasRouteInput()) return null;
    final texts = [
      _route0Controller.text.trim(),
      _route1Controller.text.trim(),
      _route2Controller.text.trim(),
    ];
    if (texts.any((text) => text.isEmpty)) return null;
    final values = texts.map(int.tryParse).toList();
    if (values.any((value) => value == null)) return null;
    final route0 = values[0]!;
    final route1 = values[1]!;
    final route2 = values[2]!;
    if (route0 + route1 + route2 != 3) return null;
    return _RouteRequirement(route0: route0, route1: route1, route2: route2);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1600),
      ),
    );
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

  List<String>? buildFilteredCombinations() {
    final routeRequirement = _parseRouteRequirement();
    if (routeRequirement == null && _hasRouteInput()) {
      return null;
    }

    final baseCombinations = widget.baseCombinationsBuilder();
    if (_noFiltersSelected() && routeRequirement == null) {
      return baseCombinations;
    }

    final results = <String>[];
    for (final combination in baseCombinations) {
      final digits = _digitsFrom(combination);
      if (!_matchesFilters(digits, routeRequirement)) continue;
      results.add(combination);
    }
    return results;
  }

  void _onCalculate() {
    final results = buildFilteredCombinations();
    if (results == null) {
      _showSnack('012路需填写3个数字且数字之和为3');
      return;
    }
    _showResultDialog(results);
  }

  bool _noFiltersSelected() {
    return _mustHaveDigits.isEmpty &&
        _mod3Remainders.isEmpty &&
        _sumTailDigits.isEmpty &&
        _sizePatterns.isEmpty &&
        _parityPatterns.isEmpty &&
        _spanDiffs.isEmpty &&
        _shapePatterns.isEmpty &&
        _consecutivePatterns.isEmpty;
  }

  List<int> _digitsFrom(String combination) {
    if (combination.length != 3) return const [0, 0, 0];
    return [
      combination.codeUnitAt(0) - 48,
      combination.codeUnitAt(1) - 48,
      combination.codeUnitAt(2) - 48,
    ];
  }

  bool _matchesFilters(List<int> digits, _RouteRequirement? routeRequirement) {
    if (_mustHaveDigits.isNotEmpty &&
        !digits.any(_mustHaveDigits.contains)) {
      return false;
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

    if (routeRequirement != null) {
      final counts = _routeCountsFor(digits);
      if (counts.route0 != routeRequirement.route0 ||
          counts.route1 != routeRequirement.route1 ||
          counts.route2 != routeRequirement.route2) {
        return false;
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
    final borderColor =
        selected ? const Color(0xFF2A9D8F) : Colors.black26;
    final backgroundColor =
        selected ? const Color(0x142A9D8F) : Colors.transparent;
    final textColor = selected ? const Color(0xFF2A9D8F) : Colors.black87;
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

  Widget _routeField(String label, TextEditingController controller) {
    return SizedBox(
      width: 54,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => unawaited(_saveConfig()),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const divider = Divider(height: 20, color: Colors.black12);
    const sizeOptions = [
      _Option(_SizePattern.big3, '3大'),
      _Option(_SizePattern.small1big2, '1小2大'),
      _Option(_SizePattern.small2big1, '2小1大'),
      _Option(_SizePattern.small3, '3小'),
    ];
    const parityOptions = [
      _Option(_ParityPattern.odd3, '3奇'),
      _Option(_ParityPattern.odd1even2, '1奇2偶'),
      _Option(_ParityPattern.odd2even1, '2奇1偶'),
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
      _Option(_ConsecutivePattern.two, '两联'),
      _Option(_ConsecutivePattern.three, '三联'),
      _Option(_ConsecutivePattern.none, '无联'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('一键清空配置'),
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
                label: const Text('计算'),
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
        const SizedBox(height: 16),
        _section(
          title: '必选',
          subtitle: '组合需包含任意勾选数字',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              10,
              (index) => _toggleChip(
                selected: _mustHaveDigits.contains(index),
                label: index.toString(),
                onTap: () => _toggleSelection(_mustHaveDigits, index),
              ),
            ),
          ),
        ),
        divider,
        _section(
          title: '除3余数',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
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
          subtitle: '0-4为小，5-9为大',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sizeOptions
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
          subtitle: '填写后要求三个数字之和为3',
          child: Row(
            children: [
              _routeField('0路', _route0Controller),
              const SizedBox(width: 10),
              _routeField('1路', _route1Controller),
              const SizedBox(width: 10),
              _routeField('2路', _route2Controller),
            ],
          ),
        ),
        divider,
        _section(
          title: '奇偶',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: parityOptions
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shapeOptions
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
          title: '联数',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: consecutiveOptions
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
