class DiffMarker {
  final int rowA;
  final int colA;
  final int rowB;
  final int colB;
  final int value;

  const DiffMarker({
    required this.rowA,
    required this.colA,
    required this.rowB,
    required this.colB,
    required this.value,
  });
}
