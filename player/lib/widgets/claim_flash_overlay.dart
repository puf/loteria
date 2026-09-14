import 'package:flutter/material.dart';

/// Wraps [child] with a flashing white layer on top (spec.md section 3:
/// "the player screen flashes white") -- purely additive, [child] keeps
/// rendering and receiving input exactly as it would without this wrapper,
/// so the board, beans, and Loteria button stay visible and usable while
/// this player's own claim is active.
class ClaimFlashOverlay extends StatefulWidget {
  const ClaimFlashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<ClaimFlashOverlay> createState() => _ClaimFlashOverlayState();
}

class _ClaimFlashOverlayState extends State<ClaimFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Opacity(
                  opacity: _controller.value,
                  child: const ColoredBox(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
