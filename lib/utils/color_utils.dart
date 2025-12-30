import 'package:flutter/material.dart';

import '../models/color_option.dart';

const Color kBaseCellColor = Color(0xFFE0E0E0);

Color bestTextColor(List<Color> colors) {
  final filtered = colors
      .where((color) => color.value != kBaseCellColor.value)
      .toList();
  final palette = filtered.isEmpty ? colors : filtered;
  var total = 0.0;
  for (final color in palette) {
    total += color.computeLuminance();
  }
  final avg = total / palette.length;
  return avg > 0.6 ? Colors.black87 : Colors.white;
}

String colorName(Color color) {
  for (final option in kColorOptions) {
    if (option.color.value == color.value) {
      return option.name;
    }
  }
  return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}
