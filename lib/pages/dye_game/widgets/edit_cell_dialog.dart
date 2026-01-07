import 'package:flutter/material.dart';

import '../../../models/cell_data.dart';
import '../../../utils/color_utils.dart';

class EditCellDialog extends StatefulWidget {
  const EditCellDialog({
    super.key,
    required this.cell,
    required this.row,
    required this.col,
    this.title = '编辑格子',
    required this.hitColor,
    required this.missColor,
    required this.baseColor,
    required this.onValueChanged,
    required this.onColorChanged,
    this.onToggleLock,
    this.showLockToggle = true,
  });

  final CellData cell;
  final int row;
  final int col;
  final String title;
  final Color hitColor;
  final Color missColor;
  final Color baseColor;
  final ValueChanged<int?> onValueChanged;
  final ValueChanged<Color> onColorChanged;
  final Future<bool> Function(bool shouldLock)? onToggleLock;
  final bool showLockToggle;

  @override
  State<EditCellDialog> createState() => _EditCellDialogState();
}

class _EditCellDialogState extends State<EditCellDialog> {
  late int? _value;
  late bool _locked;
  late List<Color> _colors;

  @override
  void initState() {
    super.initState();
    _value = widget.cell.value;
    _locked = widget.cell.locked;
    _colors = List<Color>.from(widget.cell.colors);
  }

  void _updateValue(int? nextValue) {
    setState(() => _value = nextValue);
    widget.onValueChanged(nextValue);
  }

  void _updateColors(Color nextColor) {
    final nextColors = List<Color>.filled(4, nextColor);
    setState(() => _colors = nextColors);
    widget.onColorChanged(nextColor);
  }

  Future<void> _updateLocked() async {
    final handler = widget.onToggleLock;
    if (handler == null) return;
    final updated = await handler(!_locked);
    if (!updated) return;
    if (!mounted) return;
    setState(() => _locked = widget.cell.locked);
  }

  bool _isColorSelected(Color color) {
    return _colors.every((item) => item.value == color.value);
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
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
  }) {
    final borderColor = selected ? kSelectionColor : Colors.black26;
    final backgroundColor =
        selected ? kSelectionFillColor : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w600),
          child: child,
        ),
      ),
    );
  }

  Widget _colorIcon(Color color, {bool showClear = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
          ),
        ),
        if (showClear)
          const Icon(
            Icons.close,
            size: 12,
            color: Colors.black54,
          ),
      ],
    );
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
                      '${widget.title}（${widget.row + 1}, ${widget.col + 1}）',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _withSpacing(
                        [
                          Expanded(
                            child: _optionButton(
                              selected: _value == null,
                              onTap: () => _updateValue(null),
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                              child: const Text(
                                '空',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          ...List.generate(
                            10,
                            (index) => Expanded(
                              child: _optionButton(
                                selected: _value == index,
                                onTap: () => _updateValue(index),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  index.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                        4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _withSpacing(
                        [
                          Expanded(
                            child: _optionButton(
                              selected: _isColorSelected(widget.hitColor),
                              onTap: () => _updateColors(widget.hitColor),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _colorIcon(widget.hitColor),
                                  const SizedBox(width: 4),
                                  const Text('红', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _optionButton(
                              selected: _isColorSelected(widget.missColor),
                              onTap: () => _updateColors(widget.missColor),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _colorIcon(widget.missColor),
                                  const SizedBox(width: 4),
                                  const Text('蓝', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _optionButton(
                              selected: _isColorSelected(widget.baseColor),
                              onTap: () => _updateColors(widget.baseColor),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _colorIcon(widget.baseColor, showClear: true),
                                  const SizedBox(width: 4),
                                  const Text('清空', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          if (widget.showLockToggle &&
                              widget.onToggleLock != null)
                            Expanded(
                              child: _optionButton(
                                selected: _locked,
                                onTap: _updateLocked,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _locked ? Icons.lock : Icons.lock_open,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('锁定',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        6,
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
