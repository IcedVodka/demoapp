enum CompareMode { horizontal, vertical, diagonalDownRight, diagonalDownLeft }

extension CompareModeLabel on CompareMode {
  String get label {
    switch (this) {
      case CompareMode.horizontal:
        return '横向比较';
      case CompareMode.vertical:
        return '纵向比较';
      case CompareMode.diagonalDownRight:
        return '左上-右下斜向';
      case CompareMode.diagonalDownLeft:
        return '右下-左上斜向';
    }
  }
}
