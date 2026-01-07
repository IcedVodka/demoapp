enum RowPattern {
  none,
  red3,
  red2blue1,
  red1blue2,
  blue3,
}

extension RowPatternX on RowPattern {
  int get redCount {
    switch (this) {
      case RowPattern.none:
        return 0;
      case RowPattern.red3:
        return 3;
      case RowPattern.red2blue1:
        return 2;
      case RowPattern.red1blue2:
        return 1;
      case RowPattern.blue3:
        return 0;
    }
  }

  int get blueCount {
    switch (this) {
      case RowPattern.none:
        return 0;
      default:
        return 3 - redCount;
    }
  }

  bool get isNone => this == RowPattern.none;

  String get label {
    switch (this) {
      case RowPattern.none:
        return '无色';
      case RowPattern.red3:
        return '3红';
      case RowPattern.red2blue1:
        return '2红1蓝';
      case RowPattern.red1blue2:
        return '1红2蓝';
      case RowPattern.blue3:
        return '3蓝';
    }
  }
}
