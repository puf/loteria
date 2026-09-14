import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/game_repository.dart';
import '../widgets/stage_background.dart';

LoteriaCard _cardBySlug(String slug) =>
    loteriaDeck.firstWhere((c) => c.slug == slug);

/// The URL players scan/type to open the player app. This can't be derived
/// automatically -- the stage and player apps are deployed independently
/// (e.g. player app on the conference LAN at a different address) -- so
/// update this constant to match the actual deployment before an event.
const String kPlayerJoinUrl = 'http://localhost:8765';

/// `game_state == lobby` (spec.md section 3 stage-view requirements):
/// explanation of the game, join instructions (URL and QR code), and the
/// live player count. No start-game control here -- that's the
/// remote-control app's job (implementation-plan.md: "Stage-only control
/// surface: none is needed in v1; all game control happens in the remote
/// control app").
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key, required this.gameRepository});

  final GameRepository gameRepository;

  @override
  Widget build(BuildContext context) {
    return StageBackground(
      child: Stack(
        children: [
          // The doodle's own fanned-cards-and-beans art, anchored along
          // the bottom edge -- cta.png is already a transparent-background
          // composition, so it sits directly on the gradient with no
          // extra framing needed.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/loteria_assets/cta.png',
                fit: BoxFit.fitWidth,
                width: double.infinity,
              ),
            ),
          ),
          // Cards cropped live from cards-sprite.png, gently bobbing/
          // rotating in otherwise-open background space -- motion the
          // static cta.png banner alone doesn't provide. A big idle lobby
          // screen (projector, room full of people waiting) reads as
          // "frozen" without enough of this, so there's a full half-dozen
          // now, spread wide, at a livelier pace than the original three.
          Positioned(
            top: 28,
            right: 420,
            child: FloatingCard(
              card: _cardBySlug('estrella'),
              width: 90,
              duration: const Duration(milliseconds: 3000),
            ),
          ),
          Positioned(
            top: 180,
            right: 550,
            child: FloatingCard(
              card: _cardBySlug('sol'),
              width: 76,
              duration: const Duration(milliseconds: 2500),
              bobPixels: 10,
            ),
          ),
          Positioned(
            bottom: 300,
            left: 40,
            child: FloatingCard(
              card: _cardBySlug('corazon'),
              width: 84,
              duration: const Duration(milliseconds: 2900),
              maxRotation: 0.08,
            ),
          ),
          Positioned(
            top: 48,
            left: 60,
            child: FloatingCard(
              card: _cardBySlug('luna'),
              width: 72,
              duration: const Duration(milliseconds: 2700),
              bobPixels: 12,
              maxRotation: 0.07,
            ),
          ),
          Positioned(
            top: 90,
            right: 90,
            child: FloatingCard(
              card: _cardBySlug('bandera'),
              width: 80,
              duration: const Duration(milliseconds: 3200),
              bobPixels: 16,
            ),
          ),
          Positioned(
            bottom: 260,
            right: 130,
            child: FloatingCard(
              card: _cardBySlug('arbol'),
              width: 70,
              duration: const Duration(milliseconds: 2600),
              maxRotation: 0.09,
            ),
          ),
          // implementation-plan.md v2 TODO: the "¡LOTERÍA!" label sits over
          // the cta.png artwork at the bottom, rather than in a panel at the
          // top -- same semi-translucent black38 pill as every other label
          // on this screen, for a consistent look against the busy artwork.
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '¡LOTERÍA!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'A live card-matching game for the whole room.\nGrab your phone and join in!',
                            style: TextStyle(color: Colors.white, fontSize: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    // implementation-plan.md v2 TODO: URL above the QR code,
                    // player count below it (was the reverse).
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          kPlayerJoinUrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 16),
                          ],
                        ),
                        child: QrImageView(
                          data: kPlayerJoinUrl,
                          version: QrVersions.auto,
                          size: 340,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      StreamBuilder<int>(
                        stream: gameRepository.watchLobbyCount(),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count player${count == 1 ? '' : 's'} joined',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
