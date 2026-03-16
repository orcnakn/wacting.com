String formatWac(dynamic value) {
  double v;
  if (value is String) {
    v = double.tryParse(value) ?? 0.0;
  } else if (value is num) {
    v = value.toDouble();
  } else {
    return '0';
  }

  // Floor at 6th decimal
  v = (v * 1000000).floorToDouble() / 1000000;

  String fixed = v.toStringAsFixed(6);
  // Remove trailing zeros after decimal
  if (fixed.contains('.')) {
    fixed = fixed.replaceAll(RegExp(r'0+$'), '');
    fixed = fixed.replaceAll(RegExp(r'\.$'), '');
  }
  return fixed;
}
