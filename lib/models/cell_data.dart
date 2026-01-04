import 'package:flutter/material.dart';

class CellData {
  int? value;
  List<Color> colors;
  bool locked;

  CellData({
    required this.value,
    required this.colors,
    this.locked = false,
  });
}
