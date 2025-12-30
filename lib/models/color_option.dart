import 'package:flutter/material.dart';

class ColorOption {
  final String name;
  final Color color;

  const ColorOption(this.name, this.color);
}

const List<ColorOption> kColorOptions = [
  ColorOption('白色', Color(0xFFF8F8F8)),
  ColorOption('浅灰', Color(0xFFE0E0E0)),
  ColorOption('灰色', Color(0xFFBDBDBD)),
  ColorOption('黑色', Color(0xFF424242)),
  ColorOption('红色', Color(0xFFE53935)),
  ColorOption('蓝色', Color(0xFF1E88E5)),
  ColorOption('绿色', Color(0xFF43A047)),
  ColorOption('黄色', Color(0xFFFDD835)),
  ColorOption('橙色', Color(0xFFFB8C00)),
  ColorOption('青色', Color(0xFF00ACC1)),
  ColorOption('棕色', Color(0xFF6D4C41)),
];
