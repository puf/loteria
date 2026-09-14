import 'dart:async';

import 'package:loteria_shared/loteria_shared.dart';

import 'game_repository.dart';

/// Owns the continuous "keep drawing cards every N seconds while
/// `game_state == drawing`" behavior (spec.md: "In `drawing`, the admin
/// process emits a timed `draw_tick` while not paused and while cards
/// remain") -- a background loop, not a response to one-shot actions like
/// `AdminEngine`. `pause`/`resume` (handled by `AdminEngine`) just flip
/// `game_state` to/from `paused`; this engine reacts to that by stopping/
/// restarting its own loop, no direct coupling between the two classes
/// needed.
///
/// The pace itself (`settings/draw_interval`, implementation-plan.md v2
/// TODO -- default 5s, spec.md: "Each N seconds (5 or so)") is fetched
/// fresh every tick via [GameRepository.fetchDrawInterval] rather than
/// cached once, so a host changing it mid-round takes effect on the very
/// next card. The user's note added to A5's original scope still applies:
/// this interval is the *whole* gap between cards, including however long
/// that card's name audio takes to play -- the stage reveal animation and
/// audio playback both start the moment a card arrives and finish well
/// within the default 5s (the longest clip is ~2.2s), so no separate
/// accounting for audio length is needed here.
///
/// Only writes `game/draw_count` (an incrementing cursor) -- never which
/// card was drawn. The current card and drawn-so-far history are always
/// recomputed from `draw_count` + `game_id` (see `draw_order.dart`), so
/// there's nothing here to reconcile after a reload/restart beyond reading
/// that one number back.
class DrawLoopEngine {
  DrawLoopEngine(this._repository);

  final GameRepository _repository;
  StreamSubscription<GameState?>? _sub;

  /// Bumped on every `game_state` change; a loop iteration checks this
  /// after each `await` and abandons itself if it's gone stale (state moved
  /// on while it was mid-wait) -- the simplest way to make an in-flight
  /// `Future.delayed`-based loop cancelable without reaching for `Timer`
  /// bookkeeping.
  int _generation = 0;

  /// Attaches the `game_state` watcher. Safe to call once; repeat calls are
  /// no-ops.
  void start() {
    if (_sub != null) return;
    _sub = _repository.watchGameState().listen(_onGameStateChanged);
  }

  void _onGameStateChanged(GameState? state) {
    final myGeneration = ++_generation;
    if (state == GameState.drawing) {
      unawaited(_runLoop(myGeneration));
    }
    // Any other state (paused, claiming, ...) needs no action here: the
    // generation bump alone stops a previously-running loop from doing
    // anything further.
  }

  Future<void> _runLoop(int generation) async {
    final gameId = await _repository.fetchGameId();
    if (generation != _generation || gameId == null) return;

    while (true) {
      final drawCount = await _repository.fetchDrawCount();
      if (generation != _generation) return;
      if (drawCount >= loteriaDeck.length) return; // deck exhausted

      // The very first card of the round appears immediately on entering
      // `drawing`; every subsequent one (including the first after a
      // `resume`) waits a full fresh interval first -- pausing mid-wait
      // and resuming restarts the wait rather than picking up a partial
      // remainder, matching "the screen shows the same content as before"
      // (implementation-plan.md) during a pause: nothing was progressing.
      if (drawCount > 0) {
        final interval = await _repository.fetchDrawInterval();
        if (generation != _generation) return;
        await Future<void>.delayed(interval);
        if (generation != _generation) return;
      }

      await _repository.incrementDrawCount();
      if (generation != _generation) return;
    }
  }

  void dispose() {
    _generation++;
    _sub?.cancel();
    _sub = null;
  }
}
