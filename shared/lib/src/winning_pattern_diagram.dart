import 'package:flutter/material.dart';

import 'winning_pattern.dart';

/// A small 4x4 grid highlighting a [WinningPattern]'s
/// [WinningPattern.exampleCells] -- shared (unlike the rest of each app's
/// visual chrome) so the player app and the stage draw the exact same
/// shape, just recolored to fit each app's own look via [highlightColor]/
/// [cellColor].
class WinningPatternDiagram extends StatelessWidget {
  const WinningPatternDiagram({
    super.key,
    required this.pattern,
    required this.size,
    this.highlightColor = const Color(0xFFFFD54F),
    this.cellColor = const Color(0x40808080),
  });

  final WinningPattern pattern;
  final double size;
  final Color highlightColor;
  final Color cellColor;

  @override
  Widget build(BuildContext context) {
    final cells = pattern.exampleCells;
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        // Both this Column and each Row below need `stretch`: without it,
        // a leaf with no intrinsic size (like the plain DecoratedBox cells
        // here) collapses to zero in the cross axis instead of filling its
        // share of the grid.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(4, (row) {
          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(4, (col) {
                final highlighted = cells.contains((row, col));
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: highlighted ? highlightColor : cellColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
