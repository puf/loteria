import 'package:flutter/material.dart';

import 'loteria_card.dart';
import 'sprite_crop.dart';

const String _cardsSpriteAsset = 'assets/loteria_assets/cards-sprite.png';

/// A single Lotería card that gently bobs and rotates in place --
/// decorative motion for otherwise-static stage screens. Reuses the player
/// app's sprite-cropping technique (now shared as `SpriteCrop`/
/// `LoteriaCard`) rather than shipping separate per-card image files.
class FloatingCard extends StatefulWidget {
  const FloatingCard({
    super.key,
    required this.card,
    required this.width,
    this.duration = const Duration(seconds: 4),
    this.bobPixels = 14,
    this.maxRotation = 0.06,
  });

  final LoteriaCard card;
  final double width;
  final Duration duration;
  final double bobPixels;
  final double maxRotation;

  @override
  State<FloatingCard> createState() => _FloatingCardState();
}

class _FloatingCardState extends State<FloatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value) - 0.5;
        return Transform.translate(
          offset: Offset(0, t * 2 * widget.bobPixels),
          child: Transform.rotate(
            angle: t * 2 * widget.maxRotation,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: widget.width,
        child: AspectRatio(
          aspectRatio: 250 / 375,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SpriteCrop(
              assetPath: _cardsSpriteAsset,
              sourceRect: widget.card.spriteRect,
            ),
          ),
        ),
      ),
    );
  }
}
