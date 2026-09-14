import 'dart:ui';

/// Shared intrinsic-pixel layout for a 4x4 tabla grid. Both the static
/// (dealing) and interactive (drawing) tabla widgets use this same geometry
/// -- and the same FittedBox-scaling approach -- so cards line up in the
/// same place either way, and bean positions recorded against one apply
/// identically to the other.
const double tablaCellWidth = 100;
const double tablaCellHeight = 150;
const double tablaSpacing = 4;
const double tablaGridWidth = 4 * tablaCellWidth + 3 * tablaSpacing;
const double tablaGridHeight = 4 * tablaCellHeight + 3 * tablaSpacing;

Rect tablaCellRect(int row, int col) {
  return Rect.fromLTWH(
    col * (tablaCellWidth + tablaSpacing),
    row * (tablaCellHeight + tablaSpacing),
    tablaCellWidth,
    tablaCellHeight,
  );
}

/// The row-major index (0..15) of the cell containing [position], or null
/// if [position] falls in the spacing between cells.
int? tablaCellIndexAt(Offset position) {
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 4; col++) {
      if (tablaCellRect(row, col).contains(position)) return row * 4 + col;
    }
  }
  return null;
}
