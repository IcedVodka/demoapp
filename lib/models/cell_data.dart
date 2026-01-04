import 'package:flutter/material.dart';

class CellData {
  int? value;
  List<Color> colors;
  bool locked;
  int? lockOrder;

  CellData({
    required this.value,
    required this.colors,
    this.locked = false,
    this.lockOrder,
  });
}
