import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Decodes and caches sprite sheet images once per asset path, so many
/// [SpriteCrop]s cropping the same sheet share one decoded image instead of
/// each re-decoding it.
class _SpriteSheetCache {
  static final Map<String, Future<ui.Image>> _futures = {};

  static Future<ui.Image> load(String assetPath) {
    return _futures.putIfAbsent(assetPath, () => _decode(assetPath));
  }

  static Future<ui.Image> _decode(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

/// Renders one region ([sourceRect]) cropped directly out of the sprite
/// sheet at [assetPath], rather than shipping (or generating) a separate
/// image file per sprite.
class SpriteCrop extends StatelessWidget {
  const SpriteCrop({
    super.key,
    required this.assetPath,
    required this.sourceRect,
  });

  final String assetPath;
  final Rect sourceRect;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _SpriteSheetCache.load(assetPath),
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) return const SizedBox.shrink();
        return CustomPaint(
          painter: _SpriteCropPainter(image: image, sourceRect: sourceRect),
        );
      },
    );
  }
}

class _SpriteCropPainter extends CustomPainter {
  _SpriteCropPainter({required this.image, required this.sourceRect});

  final ui.Image image;
  final Rect sourceRect;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      sourceRect,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_SpriteCropPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.sourceRect != sourceRect;
  }
}
