import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

LoteriaCard _cardBySlug(String slug) =>
    loteriaDeck.firstWhere((c) => c.slug == slug);

/// `game_state == lobby`: "waiting for next game to start" (spec.md section 3).
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // implementation-plan.md v2 TODO: "cards flying over the screen,
            // similar to the stage view" -- same FloatingCard widget the
            // stage lobby uses (now shared), just scattered around this
            // screen's plain background instead of over stage artwork.
            Positioned(
              top: 60,
              left: 24,
              child: FloatingCard(
                card: _cardBySlug('estrella'),
                width: 80,
                duration: const Duration(milliseconds: 3000),
              ),
            ),
            Positioned(
              top: 40,
              right: 28,
              child: FloatingCard(
                card: _cardBySlug('sol'),
                width: 70,
                duration: const Duration(milliseconds: 2500),
                bobPixels: 10,
              ),
            ),
            Positioned(
              bottom: 90,
              left: 36,
              child: FloatingCard(
                card: _cardBySlug('corazon'),
                width: 72,
                duration: const Duration(milliseconds: 2900),
                maxRotation: 0.08,
              ),
            ),
            Positioned(
              bottom: 70,
              right: 24,
              child: FloatingCard(
                card: _cardBySlug('luna'),
                width: 66,
                duration: const Duration(milliseconds: 2700),
                bobPixels: 12,
                maxRotation: 0.07,
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Waiting for next game to start...',
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your ID: $uid',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
