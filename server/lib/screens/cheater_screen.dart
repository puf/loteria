import 'dart:async';

import 'package:flutter/material.dart';

import '../services/resolution_engine.dart' show cheaterCountdownDuration;
import '../widgets/stage_background.dart';

/// `game_state == cheater` (spec.md: "shows a 'false bingo' animation";
/// implementation-plan.md "Screen: cheater": "false-bingo / cheater
/// animation, countdown for the rejection timeout, clear indication that
/// the claim was rejected"). Countdown display state is local-only
/// (implementation-plan.md's data contract lists "in-memory timer state"
/// as local-only) -- this just runs its own visual countdown of
/// [cheaterCountdownDuration], the same duration `ResolutionEngine` (the
/// actual authority) counts down server-side before returning to
/// `drawing`; the two aren't synced over Firebase, but they start from the
/// same value the moment each mounts on entering `cheater`.
class CheaterScreen extends StatefulWidget {
  const CheaterScreen({super.key});

  @override
  State<CheaterScreen> createState() => _CheaterScreenState();
}

class _CheaterScreenState extends State<CheaterScreen> {
  late int _secondsLeft = cheaterCountdownDuration.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
              'FALSE ¡LOTERÍA!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'That claim was rejected.',
              style: TextStyle(color: Colors.white70, fontSize: 28),
            ),
            const SizedBox(height: 40),
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_secondsLeft',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
