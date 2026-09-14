/// spec.md section 3 (`dealing` state): "The admin process determines the
/// winning pattern for the game (from the seed). The options are: Four in a
/// row (horizontal, vertical, or diagonal). Four Corners: The four outer
/// corner squares of the board. El Pozo (Square): A tight 2x2 square block
/// of four adjacent tokens."
///
/// SHARED: the admin app picks one of these five and writes [raw] verbatim
/// to `game/winning_pattern`; both the player app and the stage need to
/// interpret that same value the same way, to show players (and the
/// audience) what they're playing for this round.
enum WinningPattern {
  fourInARowHorizontal('four_in_a_row_horizontal', 'Four in a Row', 'any row'),
  fourInARowVertical('four_in_a_row_vertical', 'Four in a Row', 'any column'),
  fourInARowDiagonal(
    'four_in_a_row_diagonal',
    'Four in a Row',
    'either diagonal',
  ),
  fourCorners('four_corners', 'Four Corners', null),
  elPozo('el_pozo', 'El Pozo', 'any 2×2 block');

  const WinningPattern(this.raw, this.displayName, this.qualifier);

  /// The exact string stored at `game/winning_pattern`.
  final String raw;

  /// Short human-readable name.
  final String displayName;

  /// Clarifies that a *shape* -- not one fixed position -- is what counts:
  /// each player's 16 cards are independently shuffled (see `Tabla`), so
  /// "row 0" is a different four cards on every tabla. Null where the shape
  /// is unambiguous (there's only one set of four corners).
  final String? qualifier;

  /// One illustrative (row, col) example of the shape, 0-indexed, for a
  /// small diagram -- not the *only* cells that would count; see
  /// [qualifier].
  List<(int row, int col)> get exampleCells {
    switch (this) {
      case WinningPattern.fourInARowHorizontal:
        return const [(0, 0), (0, 1), (0, 2), (0, 3)];
      case WinningPattern.fourInARowVertical:
        return const [(0, 0), (1, 0), (2, 0), (3, 0)];
      case WinningPattern.fourInARowDiagonal:
        return const [(0, 0), (1, 1), (2, 2), (3, 3)];
      case WinningPattern.fourCorners:
        return const [(0, 0), (0, 3), (3, 0), (3, 3)];
      case WinningPattern.elPozo:
        return const [(1, 1), (1, 2), (2, 1), (2, 2)];
    }
  }

  static WinningPattern? fromRaw(Object? raw) {
    if (raw is! String) return null;
    for (final value in WinningPattern.values) {
      if (value.raw == raw) return value;
    }
    return null;
  }

  /// Every possible cell-index set (0-15, row-major -- `Tabla.cards`' own
  /// indexing) that would satisfy this pattern's shape -- e.g. all 4 rows
  /// for a horizontal four-in-a-row, all 9 possible 2x2 blocks for El Pozo.
  /// [isSatisfiedBy] and [satisfyingCellSets] both build on this single
  /// definition of each shape's geometry.
  List<Set<int>> get _candidateCellSets {
    switch (this) {
      case WinningPattern.fourInARowHorizontal:
        return [
          for (var row = 0; row < 4; row++)
            {for (var col = 0; col < 4; col++) row * 4 + col},
        ];
      case WinningPattern.fourInARowVertical:
        return [
          for (var col = 0; col < 4; col++)
            {for (var row = 0; row < 4; row++) row * 4 + col},
        ];
      case WinningPattern.fourInARowDiagonal:
        return [
          {0, 5, 10, 15},
          {3, 6, 9, 12},
        ];
      case WinningPattern.fourCorners:
        return [
          {0, 3, 12, 15},
        ];
      case WinningPattern.elPozo:
        return [
          for (var row = 0; row < 3; row++)
            for (var col = 0; col < 3; col++)
              {
                row * 4 + col,
                row * 4 + col + 1,
                row * 4 + col + 4,
                row * 4 + col + 5,
              },
        ];
    }
  }

  /// Whether [drawnCellIndices] contains a complete instance of this
  /// pattern's shape anywhere on the 4x4 grid. Row/column/diagonal
  /// patterns accept *any* matching line (see [qualifier]), not just the
  /// one [exampleCells] illustrates; El Pozo accepts any of the nine
  /// possible 2x2 blocks.
  bool isSatisfiedBy(Set<int> drawnCellIndices) {
    return _candidateCellSets.any(
      (cells) => cells.every(drawnCellIndices.contains),
    );
  }

  /// Every candidate cell-index set that's fully drawn -- i.e. every
  /// distinct completed instance of this pattern's shape the player
  /// actually has, not just whether *any* one exists (see
  /// [isSatisfiedBy]). Used by the celebrate screen to highlight every
  /// winning line/shape at once (implementation-plan.md v2 TODO: "if there
  /// are multiple such lines/shapes, put beans on all of them"). Empty if
  /// [isSatisfiedBy] would return false.
  List<Set<int>> satisfyingCellSets(Set<int> drawnCellIndices) {
    return _candidateCellSets
        .where((cells) => cells.every(drawnCellIndices.contains))
        .toList();
  }
}
