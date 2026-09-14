import 'dart:async';

import 'package:loteria_shared/loteria_shared.dart';

import 'draw_order.dart';
import 'game_repository.dart';

/// Reacts to a player writing `game/claiming_uid` (spec.md section 3:
/// "A player can claim ¡Loteria!, which writes their player ID to the
/// global `claiming_uid` property... The admin process then puts the game
/// state into `claiming`"). This is a *player*-initiated write, not a
/// one-shot host action, so -- like [DrawLoopEngine] watching `game_state`
/// -- it needs its own continuous watcher rather than living in
/// `AdminEngine`'s action-response loop.
///
/// Validation happens immediately here, not on the host's `check` action:
/// spec.md's `claiming` state description says "the Host view *can
/// trigger* a `check` action" only when the claim is eligible (valid, or
/// the first invalid claim this game) -- implying the admin has already
/// decided eligibility by the time the host would look. Ineligible claims
/// (invalid and not the first) are silently auto-rejected right away, no
/// host action involved at all.
class ClaimEngine {
  ClaimEngine(this._repository);

  final GameRepository _repository;
  StreamSubscription<String?>? _sub;

  /// The last claiming_uid value seen, so a duplicate/unchanged event
  /// (Firebase's `onValue` always replays the current value to a fresh
  /// listener) isn't reprocessed as if it were a brand new claim.
  String? _lastSeenClaimingUid;

  /// Attaches the `claiming_uid` watcher. Safe to call once; repeat calls
  /// are no-ops.
  void start() {
    if (_sub != null) return;
    _sub = _repository.watchClaimingUid().listen(_onClaimingUidChanged);
  }

  void _onClaimingUidChanged(String? uid) {
    final previous = _lastSeenClaimingUid;
    _lastSeenClaimingUid = uid;
    if (uid == null || uid == previous) return;
    unawaited(_handleNewClaim(uid));
  }

  Future<void> _handleNewClaim(String uid) async {
    // spec.md / implementation-plan.md: "verify game_state == drawing,
    // claiming_uid empty, UID not in blocked_uids". The empty-before check
    // is implicit -- a genuinely new value just arrived. `isBlocked` is
    // defensive: Firebase security rules (not this app) are the real
    // enforcement for that, but the admin doesn't blindly trust client
    // writes either.
    final state = await _repository.fetchGameState();
    if (state != GameState.drawing) return;
    if (await _repository.isBlocked(uid)) return;

    await _repository.beginClaiming();

    final gameId = await _repository.fetchGameId();
    final tablaId = await _repository.fetchTablaId(uid);
    final winningPattern = await _repository.fetchWinningPattern();
    if (gameId == null || tablaId == null || winningPattern == null) {
      return;
    }

    final drawCount = await _repository.fetchDrawCount();
    final order = drawOrderFor(gameId);
    final drawnSlugs = order.take(drawCount).map((c) => c.slug).toSet();

    final tabla = Tabla(gameId: gameId.toString(), tablaId: tablaId);
    final drawnCellIndices = <int>{
      for (var i = 0; i < tabla.cards.length; i++)
        if (drawnSlugs.contains(tabla.cards[i].slug)) i,
    };
    final isValid = winningPattern.isSatisfiedBy(drawnCellIndices);

    // Must be checked *before* appending this claim's own log entry below,
    // or it would always see itself and never treat any claim as "first".
    final alreadyHadAnInvalidClaim =
        !isValid && await _repository.hasAnyRejectedClaimThisGame(gameId);

    await _repository.appendClaimLog(
      gameId: gameId,
      tablaId: tablaId,
      playerUid: uid,
      accepted: isValid,
      drawCount: drawCount,
    );

    if (isValid || !alreadyHadAnInvalidClaim) {
      // Eligible: stays in `claiming`, waiting for the host's `check`
      // action (handled by `AdminEngine`).
      return;
    }

    // Invalid, and not the first invalid claim this round: silent
    // auto-reject, no stage-visible false-claim flow.
    await _repository.blockPlayer(uid);
    await _repository.clearClaimingUid();
    await _repository.resumeDrawing();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
