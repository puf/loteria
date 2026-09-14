import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

/// A small always-visible indicator of the round's winning pattern -- shown
/// on both the dealing and drawing screens so the room knows what shape to
/// watch for. Neither spec.md/implementation-plan.md nor the original
/// Google Doodle's assets have a ready-made image for this (the doodle only
/// ships generic win/lose overlays, no per-pattern art), so the diagram is
/// drawn live via the shared `WinningPatternDiagram`.
class WinningPatternBadge extends StatelessWidget {
  const WinningPatternBadge({super.key, required this.pattern});

  final WinningPattern pattern;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WinningPatternDiagram(pattern: pattern, size: 44),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pattern.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (pattern.qualifier != null)
                Text(
                  pattern.qualifier!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
