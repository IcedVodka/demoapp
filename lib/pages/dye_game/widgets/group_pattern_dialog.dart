import 'package:flutter/material.dart';

import '../../../utils/color_utils.dart';
import '../game_models.dart';

class GroupPatternDialog extends StatefulWidget {
  const GroupPatternDialog({
    super.key,
    required this.row,
    required this.group,
    required this.selection,
    required this.hitColor,
    required this.missColor,
    required this.onSelectionChanged,
  });

  final int row;
  final int group;
  final Set<RowPattern> selection;
  final Color hitColor;
  final Color missColor;
  final ValueChanged<Set<RowPattern>> onSelectionChanged;

  @override
  State<GroupPatternDialog> createState() => _GroupPatternDialogState();
}

class _GroupPatternDialogState extends State<GroupPatternDialog> {
  late final Set<RowPattern> _selection;

  @override
  void initState() {
    super.initState();
    _selection = Set<RowPattern>.from(widget.selection);
  }

  void _togglePattern(RowPattern pattern) {
    setState(() {
      if (_selection.contains(pattern)) {
        _selection.remove(pattern);
      } else {
        _selection.add(pattern);
      }
    });
    widget.onSelectionChanged(Set<RowPattern>.from(_selection));
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

  Widget _optionButton({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final borderColor = selected ? kSelectionColor : Colors.black26;
    final backgroundColor =
        selected ? kSelectionFillColor : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: child,
      ),
    );
  }

  Widget _patternSwatch(RowPattern pattern) {
    final colors = List<Color>.generate(
      3,
      (index) => index < pattern.redCount ? widget.hitColor : widget.missColor,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _withSpacing(
        colors
            .map(
              (color) => Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.black26),
                ),
              ),
            )
            .toList(),
        2,
      ),
    );
  }

  Widget _patternButton(RowPattern pattern) {
    final selected = _selection.contains(pattern);
    return Expanded(
      child: _optionButton(
        selected: selected,
        onTap: () => _togglePattern(pattern),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _patternSwatch(pattern),
            const SizedBox(height: 4),
            Text(
              pattern.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _groupLabel() {
    return widget.group == 0 ? '左侧' : '右侧';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 16,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '自定义配置（第${widget.row + 1}行 ${_groupLabel()}）',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '可多选',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _withSpacing(
                        [
                          _patternButton(RowPattern.red2blue1),
                          _patternButton(RowPattern.red1blue2),
                        ],
                        8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _withSpacing(
                        [
                          _patternButton(RowPattern.red3),
                          _patternButton(RowPattern.blue3),
                        ],
                        8,
                      ),
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
