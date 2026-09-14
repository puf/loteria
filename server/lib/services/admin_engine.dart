import 'dart:async';
import 'dart:math';

import 'package:loteria_shared/loteria_shared.dart';

import 'game_repository.dart';

/// The whole dealing phase should take roughly this long start to finish,
/// regardless of player count: about [_minDealDuration] for a handful of
/// players, ramping up to about [_maxDealDuration] once the lobby is as
/// large as [_dealDurationRampPlayers] -- a room shouldn't stand around for
/// a minute-plus watching a 100-player deal, but a 2-player deal shouldn't
/// blink by instantly either. Per-player pace is this total divided by
/// player count (see [_dealPaceFor]), so at high counts tablas are dealt
/// faster than any one flying-tabla animation takes to play -- overlapping
/// animations are fine, spec.md only asks for "a quick animation", not that
/// each one finishes before the next starts.
///
/// That target total is only a target, though: [_maxFirstDealWait] and
/// [_maxDealPace] below are hard ceilings on top of it, so a small lobby
/// never has to sit through a long wait for its first (or only) tabla just
/// to hit the target -- lowering the *minimum* possible total dealing time
/// versus letting the ramp alone decide it, by design.
const Duration _minDealDuration = Duration(seconds: 10);
const Duration _maxDealDuration = Duration(seconds: 15);
const int _dealDurationRampPlayers = 100;

/// Hard ceiling on the wait before the *first* tabla is dealt, overriding
/// [_dealPaceFor] whenever the ramped pace would exceed it (always true for
/// small lobbies, since the ramp alone would otherwise stretch a single
/// player's "deal" out to nearly [_minDealDuration]).
const Duration _maxFirstDealWait = Duration(seconds: 2);

/// Hard ceiling on the wait between each *subsequent* tabla -- slightly
/// tighter than [_maxFirstDealWait] so the round visibly picks up pace
/// right after the first card lands.
const Duration _maxDealPace = Duration(milliseconds: 1500);

Duration _dealPaceFor(int playerCount) {
  if (playerCount <= 0) return Duration.zero;
  final rampT = (playerCount / _dealDurationRampPlayers).clamp(0.0, 1.0);
  final totalMs =
      _minDealDuration.inMilliseconds +
      rampT *
          (_maxDealDuration.inMilliseconds - _minDealDuration.inMilliseconds);
  return Duration(milliseconds: (totalMs / playerCount).round());
}

/// Owns the authoritative admin state machine: reacts to actions written
/// to `actions/<push-id>` by the remote-control app (the only action
/// source in v1 -- implementation-plan.md) and executes the corresponding
/// Firebase writes. This is backend logic, not display -- the stage screens
/// only ever read `game_state`/`game`, never trigger transitions.
///
/// Each action is just `{push-id}: "<action name>"` -- no actor_uid or
/// request_id (there's only ever one host, and the push ID already is a
/// unique id), no timestamp (push IDs already sort chronologically, so
/// processing in key order is enough).
///
/// Each phase adds its own action handling as it's built; unhandled
/// actions (either an unrecognized name, or a recognized one that doesn't
/// apply to the current `game_state` yet) are silently ignored, matching
/// spec.md's "reject" semantics -- there's no host-facing error surface in
/// v1 to report back to.
class AdminEngine {
  AdminEngine(this._repository);

  final GameRepository _repository;
  StreamSubscription<MapEntry<String, String>>? _sub;

  /// Attaches the action listener. Safe to call once; repeat calls are
  /// no-ops.
  void start() {
    if (_sub != null) return;
    _sub = _repository.watchNewActionNames().listen(_handleAction);
  }

  Future<void> _handleAction(MapEntry<String, String> event) async {
    final name = event.value;
    // A genuinely unrecognized action name is silently ignored -- it's
    // consumed below regardless: a one-shot command, handled or rejected,
    // not a log to keep around.
    if (name == 'next_game') {
      await _handleNextGame();
    } else if (name == 'start_drawing') {
      await _handleStartDrawing();
    } else if (name == 'pause') {
      await _handlePause();
    } else if (name == 'resume') {
      await _handleResume();
    } else if (name == 'check') {
      await _handleCheck();
    } else if (name == 'resolve') {
      await _handleResolve();
    } else if (name == 'clear_blocked') {
      await _handleClearBlocked();
    }
    await _repository.deleteAction(event.key);
  }

  /// `lobby -> next_game -> dealing` (spec.md / implementation-plan.md
  /// admin state machine), followed by dealing each player's tabla in turn.
  /// From every *other* state, `next_game` instead aborts back to `lobby`
  /// (see [GameRepository.abortToLobby]) -- a host needs to be able to bail
  /// out and reset from wherever the game currently is (spec.md's own
  /// example: an exhausted deck with no winner), not just from `celebrate`.
  Future<void> _handleNextGame() async {
    // A missing `game_state` (e.g. a never-yet-initialized database) is
    // treated as `lobby` everywhere else (see `StageStateController`); this
    // needs to match, or a first-ever `next_game` would be misread as an
    // abort with nothing to abort.
    final state = await _repository.fetchGameState() ?? GameState.lobby;
    if (state != GameState.lobby) {
      await _repository.abortToLobby();
      return;
    }

    // implementation-plan.md v2 TODO: `settings/max_player_count` caps how
    // many lobby players get copied into the new round -- an arbitrary
    // (stable) subset, not a random sample, since the lobby's own key
    // order has no meaningful bias to correct for here.
    final lobbyUids = await _repository.fetchLobbyUids();
    final maxPlayerCount = await _repository.fetchMaxPlayerCount();
    final playerUids = lobbyUids.length > maxPlayerCount
        ? lobbyUids.take(maxPlayerCount).toList()
        : lobbyUids;
    final newGameId = DateTime.now().millisecondsSinceEpoch;
    // spec.md: "determines the winning pattern for the game (from the
    // seed)" -- `WinningPattern` (shared/lib/src/winning_pattern.dart) is
    // the full set of five options; stored verbatim (`.raw`) so both apps
    // read the identical value back to show players what they're playing
    // for.
    final winningPattern =
        WinningPattern.values[Random(newGameId)
            .nextInt(WinningPattern.values.length)];
    await _repository.applyNextGameFromLobby(
      newGameId: newGameId,
      winningPattern: winningPattern.raw,
      playerCount: playerUids.length,
    );

    // Each write's own network round-trip is NOT awaited here: awaiting it
    // would add that latency on top of the wait on every single iteration,
    // compounding into many extra seconds across a large lobby (measured:
    // a 100-player deal target of 15s actually took 22s+ with a blocking
    // await here). The pacing loop's timing should depend only on the
    // waits computed below.
    final rampedPace = _dealPaceFor(playerUids.length);
    final firstWait = rampedPace < _maxFirstDealWait
        ? rampedPace
        : _maxFirstDealWait;
    final subsequentPace = rampedPace < _maxDealPace
        ? rampedPace
        : _maxDealPace;
    for (var i = 0; i < playerUids.length; i++) {
      await Future<void>.delayed(i == 0 ? firstWait : subsequentPace);
      unawaited(_repository.dealTablaToPlayer(playerUids[i]));
    }
  }

  /// `dealing -> start_drawing -> drawing` (spec.md: "Once all tablas are
  /// dealt, the host can start the drawing of cards"). Rejects (silently,
  /// same as every other inapplicable action) unless every registered
  /// player already has a `tabla_id`.
  Future<void> _handleStartDrawing() async {
    final state = await _repository.fetchGameState();
    if (state != GameState.dealing) return;

    final progress = await _repository.fetchDealingProgress();
    if (progress.total == 0 || progress.dealt < progress.total) return;

    await _repository.startDrawing();
  }

  /// `drawing -> pause -> paused` (spec.md: "the host can `pause` and
  /// `resume` the drawing"; implementation-plan.md's admin state machine:
  /// "only possible while the draw loop is active"). `DrawLoopEngine`
  /// reacts to the resulting `game_state` change on its own -- this just
  /// flips the flag.
  Future<void> _handlePause() async {
    final state = await _repository.fetchGameState();
    if (state != GameState.drawing) return;

    await _repository.pauseDrawing();
  }

  /// `paused -> resume -> drawing` -- "only possible while the draw loop is
  /// paused".
  Future<void> _handleResume() async {
    final state = await _repository.fetchGameState();
    if (state != GameState.paused) return;

    await _repository.resumeDrawing();
  }

  /// `claiming -> check -> checking` (spec.md: "the Host view can trigger a
  /// `check` action, for which the admin process then changes the state to
  /// `checking`"). `ClaimEngine` has already decided by this point whether
  /// the claim was eligible to reach `claiming` at all -- ineligible claims
  /// never get this far (auto-rejected straight back to `drawing`), so this
  /// is just the state flip.
  Future<void> _handleCheck() async {
    final state = await _repository.fetchGameState();
    if (state != GameState.claiming) return;

    await _repository.setChecking();
  }

  /// `checking -> resolve -> winner or cheater` (patch-plans/001: a single
  /// `resolve` action replaces the earlier `resolve_winner`/
  /// `resolve_cheater` split -- spec.md: "the admin process finalizes the
  /// claim as either `winner` or `cheater` based on the host decision").
  /// There's no separate host input for *which* outcome: `ClaimEngine`
  /// already decided that the moment the claim came in and logged it to
  /// `claim_log`, so this just looks that up. `ResolutionEngine` takes it
  /// from here automatically either way (winner: writes `winner_log`,
  /// moves on to `celebrate`; cheater: runs the countdown, returns to
  /// `drawing`).
  Future<void> _handleResolve() async {
    final state = await _repository.fetchGameState();
    if (state != GameState.checking) return;

    final gameId = await _repository.fetchGameId();
    final uid = await _repository.fetchClaimingUid();
    if (gameId == null || uid == null) return;

    final accepted = await _repository.fetchLatestClaimAccepted(
      gameId: gameId,
      playerUid: uid,
    );
    if (accepted) {
      await _repository.resolveWinner();
    } else {
      await _repository.resolveCheater();
    }
  }

  /// Manual `blocked_uids` reset (implementation-plan.md parking-lot item),
  /// independent of `game_state` -- unlike every other action here, this
  /// isn't a state-machine transition, just a standing list the host can
  /// clear whenever, e.g. after resolving a mistaken block mid-round.
  Future<void> _handleClearBlocked() async {
    await _repository.clearBlockedUids();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
