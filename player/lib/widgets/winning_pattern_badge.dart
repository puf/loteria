import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

/// Tells the player what shape to watch for this round -- otherwise they
/// have no way to know whether to chase a row, the corners, or a 2x2 block
/// (beans are placed purely on the player's own judgment; spec.md says
/// nothing is validated client-side, so without this there'd be no way to
/// even guess what counts as a win).
class WinningPatternBadge extends StatelessWidget {
  const WinningPatternBadge({super.key, required this.pattern});

  final WinningPattern pattern;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WinningPatternDiagram(
            pattern: pattern,
            size: 36,
            highlightColor: colorScheme.primary,
            cellColor: colorScheme.outlineVariant,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pattern.displayName,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (pattern.qualifier != null)
                Text(
                  pattern.qualifier!,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
