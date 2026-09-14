import 'dart:async';

import 'package:flutter/material.dart';

import '../services/game_repository.dart';
import '../widgets/stage_background.dart';

/// `game_state == winner` (implementation-plan.md "Screen: winner"):
/// "winner banner or winner announcement, winner player identity". A brief
/// beat of its own -- `ResolutionEngine` automatically moves on to
/// `celebrate` a few seconds after entering this state (spec.md doesn't
/// specify a duration for `winner` itself, unlike cheater's explicit
/// countdown).
class WinnerScreen extends StatefulWidget {
  const WinnerScreen({super.key, required this.gameRepository});

  final GameRepository gameRepository;

  @override
  State<WinnerScreen> createState() => _WinnerScreenState();
}

class _WinnerScreenState extends State<WinnerScreen> {
  StreamSubscription<String?>? _claimingUidSub;
  String? _claimingUid;

  @override
  void initState() {
    super.initState();
    // Streamed (like `CheckingScreen`), not a one-time fetch -- the UID is
    // already known from the moment `checking` started, so this should
    // resolve on its very first event, not race the few-second window
    // before `ResolutionEngine` moves on to `celebrate`.
    _claimingUidSub = widget.gameRepository.watchClaimingUid().listen((uid) {
      if (mounted) setState(() => _claimingUid = uid);
    });
  }

  @override
  void dispose() {
    _claimingUidSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StageBackground(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¡LOTERÍA!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 24),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'WINNER',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _claimingUid ?? '...',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
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
