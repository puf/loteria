import 'dart:async';

import 'package:flutter/material.dart';

import '../services/game_repository.dart';
import '../widgets/stage_background.dart';

/// `game_state == checking` (implementation-plan.md "Screen: checking"):
/// "the current claimant being held up for verification... a waiting state
/// while the host resolves the claim... large instruction to the player to
/// hold up their phone and show it." No accepted/rejected verdict is shown
/// here -- that's the host/remote-control app's own view
/// (implementation-plan.md line 231 distinguishes "in the host/admin
/// flow" from the stage); this screen's only job is to build tension for
/// the room while the host looks.
class CheckingScreen extends StatefulWidget {
  const CheckingScreen({super.key, required this.gameRepository});

  final GameRepository gameRepository;

  @override
  State<CheckingScreen> createState() => _CheckingScreenState();
}

class _CheckingScreenState extends State<CheckingScreen> {
  StreamSubscription<String?>? _claimingUidSub;
  String? _claimingUid;

  @override
  void initState() {
    super.initState();
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
              'Checking claim...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hold up your phone!',
              style: TextStyle(color: Colors.white, fontSize: 32),
            ),
            if (_claimingUid != null) ...[
              const SizedBox(height: 40),
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
                  _claimingUid!,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
