import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

const String cardsSpriteAsset = 'assets/loteria_assets/cards-sprite.png';

/// Renders a single [LoteriaCard] cropped out of `cards-sprite.png`.
class CardSpriteImage extends StatelessWidget {
  const CardSpriteImage({super.key, required this.card});

  final LoteriaCard card;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 250 / 375,
      child: SpriteCrop(
        assetPath: cardsSpriteAsset,
        sourceRect: card.spriteRect,
      ),
    );
  }
}
