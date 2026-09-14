import 'package:flutter/material.dart';

import '../services/admin_engine.dart';
import '../services/claim_engine.dart';
import '../services/draw_loop_engine.dart';
import '../services/game_repository.dart';
import '../services/resolution_engine.dart';
import '../state/stage_screen.dart';
import '../state/stage_state_controller.dart';
import 'celebrate_screen.dart';
import 'cheater_screen.dart';
import 'checking_screen.dart';
import 'dealing_screen.dart';
import 'drawing_screen.dart';
import 'lobby_screen.dart';
import 'winner_screen.dart';

/// Shown once the auth gate confirms admin access. Owns the `game_state`
/// listener/router (display) and the [AdminEngine] (action processing) --
/// both start together here since both only make sense once this session
/// is confirmed to be an authorized admin.
class StageRouter extends StatefulWidget {
  const StageRouter({super.key, required this.gameRepository});

  final GameRepository gameRepository;

  @override
  State<StageRouter> createState() => _StageRouterState();
}

class _StageRouterState extends State<StageRouter> {
  late final StageStateController _controller;
  late final AdminEngine _adminEngine;
  late final DrawLoopEngine _drawLoopEngine;
  late final ClaimEngine _claimEngine;
  late final ResolutionEngine _resolutionEngine;

  @override
  void initState() {
    super.initState();
    // All created and started explicitly here, not via `late final ... =`
    // field initializers -- those only run on first *read*, and most of
    // these are never read anywhere except `dispose()`, so a field-
    // initializer version of `start()` would never actually run during the
    // widget's active lifetime.
    _controller = StageStateController(widget.gameRepository)..start();
    _adminEngine = AdminEngine(widget.gameRepository)..start();
    _drawLoopEngine = DrawLoopEngine(widget.gameRepository)..start();
    _claimEngine = ClaimEngine(widget.gameRepository)..start();
    _resolutionEngine = ResolutionEngine(widget.gameRepository)..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _adminEngine.dispose();
    _drawLoopEngine.dispose();
    _claimEngine.dispose();
    _resolutionEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        switch (_controller.screen) {
          case StageScreen.connecting:
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          case StageScreen.lobby:
            return LobbyScreen(gameRepository: widget.gameRepository);
          case StageScreen.dealing:
            return DealingScreen(gameRepository: widget.gameRepository);
          case StageScreen.drawing:
          case StageScreen.paused:
          case StageScreen.claiming:
            // Same widget for all three -- returning it from every case
            // (rather than separate `DrawingScreen(...)` return statements)
            // keeps Flutter's reconciliation treating this as the *same*
            // element across pause/resume/claim transitions, so its State
            // (the audio player, its stream subscriptions) survives instead
            // of being torn down and recreated every time. `claiming`
            // reusing this view (rather than a dedicated screen) is also
            // the explicit call in implementation-plan.md's decisions.
            return DrawingScreen(gameRepository: widget.gameRepository);
          case StageScreen.checking:
            return CheckingScreen(gameRepository: widget.gameRepository);
          case StageScreen.cheater:
            return const CheaterScreen();
          case StageScreen.winner:
            return WinnerScreen(gameRepository: widget.gameRepository);
          case StageScreen.celebrate:
            return CelebrateScreen(gameRepository: widget.gameRepository);
        }
      },
    );
  }
}
