enum RowPattern {
  red3,
  red2blue1,
  red1blue2,
  blue3,
}

extension RowPatternX on RowPattern {
  int get redCount {
    switch (this) {
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

  int get blueCount => 3 - redCount;

  String get label {
    switch (this) {
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
