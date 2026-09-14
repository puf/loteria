import 'package:flutter/material.dart';

import 'sprite_crop.dart';

const String _initialSpriteAsset = 'assets/loteria_assets/initial-sprite.png';

// Coordinates read from the original Google Doodle's source (loteria19.js),
// same as the card sprite rects -- exact, not estimated. This is the tan
// kidney bean on the right-hand side of initial-sprite.png.
const Rect _beanSourceRect = Rect.fromLTWH(103, 0, 60, 70);

/// A single bean token, cropped out of `initial-sprite.png`, with a drop
/// shadow so it stays visible against any card's background color.
class BeanImage extends StatelessWidget {
  const BeanImage({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final height = size * (_beanSourceRect.height / _beanSourceRect.width);
    return SizedBox(
      width: size,
      height: height,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: SpriteCrop(
          assetPath: _initialSpriteAsset,
          sourceRect: _beanSourceRect,
        ),
      ),
    );
  }
}
