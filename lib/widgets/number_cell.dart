import 'package:flutter/material.dart';

import '../models/cell_data.dart';
import '../utils/color_utils.dart';

class NumberCell extends StatelessWidget {
  const NumberCell({
    super.key,
    required this.cell,
    required this.onTap,
    required this.radius,
  });

  final CellData cell;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final textColor = bestTextColor(cell.colors);
    final effectiveRadius = radius > 0 ? radius : 0.0;
    final clipRadius = effectiveRadius > 1 ? effectiveRadius - 1 : 0.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(clipRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                _Quadrants(colors: cell.colors),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final fontSize = constraints.maxWidth * 0.42;
                      final label = cell.value?.toString() ?? '';
                      return Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.25),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (cell.locked)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Icon(
                      Icons.lock,
                      size: 14,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Quadrants extends StatelessWidget {
  const _Quadrants({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _Quadrant(color: colors[0])),
              Expanded(child: _Quadrant(color: colors[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _Quadrant(color: colors[2])),
              Expanded(child: _Quadrant(color: colors[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _Quadrant extends StatelessWidget {
  const _Quadrant({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(color: color),
    );
  }
}
