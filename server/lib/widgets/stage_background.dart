import 'package:flutter/material.dart';

/// The warm, festive gradient shared by every stage screen -- in the spirit
/// of the original Loteria doodle's promo art (maxresdefault.webp), but
/// darker throughout so white text and high-contrast panels read clearly
/// under bright conference lighting rather than fading into a pale cream
/// top. Used across screens (not just the lobby) so the stage keeps one
/// consistent visual identity as the game progresses.
class StageBackground extends StatelessWidget {
  const StageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3B1220), Color(0xFF9A2B1E), Color(0xFFE07A29)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
