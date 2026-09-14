import 'dart:async';

import 'package:loteria_shared/loteria_shared.dart';

import 'game_repository.dart';

/// How long the `winner` state lingers -- implementation-plan.md's stage
/// screen inventory expects it to be its own distinct "winner banner"
/// moment, not an instant pass-through to `celebrate` -- before
/// automatically finalizing. spec.md doesn't give this one an explicit
/// duration (unlike cheater's "5 or 10"), so this is a judgment call: long
/// enough to register as its own beat, short enough not to stall the show.
const Duration winnerDisplayDuration = Duration(seconds: 3);

/// spec.md: "counts down from 5 or 10". Picked the shorter end to keep a
/// live room's pace up -- the cheater flow doesn't need host banter time
/// the way pause/resume does. Exported so the stage's cheater screen can
/// run the identical countdown for display, without duplicating the
/// number.
const Duration cheaterCountdownDuration = Duration(seconds: 5);

/// Owns the two purely-automatic post-`checking` transitions -- spec.md's
/// own transition table marks both `finalize_winner` and `timeout_elapsed`
/// as triggered by "admin process (stage)", not a host action, unlike
/// `resolve` itself (the single host action that picks `winner` or
/// `cheater`, handled in `AdminEngine`): `winner -> celebrate` and
/// `cheater -> drawing`.
/// Continuous, state-triggered background behavior -- same shape as
/// `DrawLoopEngine`, including its cancelable-via-generation pattern.
class ResolutionEngine {
  ResolutionEngine(this._repository);

  final GameRepository _repository;
  StreamSubscription<GameState?>? _sub;
  int _generation = 0;

  /// Attaches the `game_state` watcher. Safe to call once; repeat calls are
  /// no-ops.
  void start() {
    if (_sub != null) return;
    _sub = _repository.watchGameState().listen(_onGameStateChanged);
  }

  void _onGameStateChanged(GameState? state) {
    final myGeneration = ++_generation;
    if (state == GameState.winner) {
      unawaited(_runWinnerFinalization(myGeneration));
    } else if (state == GameState.cheater) {
      unawaited(_runCheaterCountdown(myGeneration));
    }
    // Any other state needs no action: the generation bump alone abandons
    // whichever of the two waits above might still be in flight.
  }

  Future<void> _runWinnerFinalization(int generation) async {
    await Future<void>.delayed(winnerDisplayDuration);
    if (generation != _generation) return;

    final gameId = await _repository.fetchGameId();
    final uid = await _repository.fetchClaimingUid();
    if (gameId == null || uid == null) return;
    final tablaId = await _repository.fetchTablaId(uid);
    if (tablaId == null) return;
    final drawCount = await _repository.fetchDrawCount();
    if (generation != _generation) return;

    await _repository.appendWinnerLog(
      gameId: gameId,
      tablaId: tablaId,
      playerUid: uid,
      drawCount: drawCount,
    );
    if (generation != _generation) return;
    await _repository.beginCelebrate();
  }

  Future<void> _runCheaterCountdown(int generation) async {
    await Future<void>.delayed(cheaterCountdownDuration);
    if (generation != _generation) return;

    final uid = await _repository.fetchClaimingUid();
    if (uid != null) {
      await _repository.blockPlayer(uid);
      if (generation != _generation) return;
    }
    await _repository.clearClaimingUid();
    if (generation != _generation) return;
    await _repository.resumeDrawing();
  }

  void dispose() {
    _generation++;
    _sub?.cancel();
    _sub = null;
  }
}
