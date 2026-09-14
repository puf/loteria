import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'package:loteria_shared/loteria_shared.dart';

/// Read/write access to the Firebase paths the stage/admin app needs. The
/// admin app has unrestricted database access in v1
/// (implementation-plan.md), so this isn't a security boundary the way the
/// player app's repository is -- it's just scoped to what each phase
/// actually uses, growing incrementally as later phases (dealing, draw
/// loop, claims, ...) need more.
class GameRepository {
  GameRepository(this._database);

  final FirebaseDatabase _database;

  Stream<GameState?> watchGameState() {
    return _database.ref('game_state').onValue.map((event) {
      return GameState.fromRaw(event.snapshot.value);
    });
  }

  Future<GameState?> fetchGameState() async {
    final snapshot = await _database.ref('game_state').get();
    return GameState.fromRaw(snapshot.value);
  }

  /// The current round's winning pattern -- fixed for the whole round once
  /// [applyNextGameFromLobby] sets it, so a one-time fetch (not a stream) is
  /// enough for callers that just need it once at mount.
  Future<WinningPattern?> fetchWinningPattern() async {
    final snapshot = await _database.ref('game/winning_pattern').get();
    return WinningPattern.fromRaw(snapshot.value);
  }

  Stream<int> watchLobbyCount() {
    return _database.ref('lobby').onValue.map((event) {
      final value = event.snapshot.value;
      return value is Map ? value.length : 0;
    });
  }

  Future<List<String>> fetchLobbyUids() async {
    final snapshot = await _database.ref('lobby').get();
    final value = snapshot.value;
    if (value is! Map) return const [];
    return value.keys.map((key) => key.toString()).toList();
  }

  /// The current lobby membership as a set of UIDs, re-emitted on every
  /// change -- implementation-plan.md v2 TODO: cross-referenced against
  /// `players`/`blocked_uids` to derive "active"/"blocked" counts that only
  /// include currently-connected players.
  Stream<Set<String>> watchLobbyUids() {
    return _database.ref('lobby').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const {};
      return value.keys.map((key) => key.toString()).toSet();
    });
  }

  /// The full blocklist as a set of UIDs, re-emitted on every change -- see
  /// [watchLobbyUids].
  Stream<Set<String>> watchBlockedUids() {
    return _database.ref('blocked_uids').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const {};
      return value.keys.map((key) => key.toString()).toSet();
    });
  }

  /// Every `actions/<push-id>` entry as it becomes known, as a `MapEntry`
  /// of (key, action name) -- each entry is just `{push-id}: "<action
  /// name>"` (e.g. `"next_game"`), nothing else. The key comes along so the
  /// caller can remove the entry once handled (see [deleteAction]) --
  /// actions are one-shot commands, not a persisted log.
  ///
  /// Deliberately unfiltered: this doesn't try to skip whatever was already
  /// sitting in `actions/` before the listener attached (an earlier version
  /// did, via `orderByKey().startAfter(<last key at attach time>)`, to
  /// avoid "replaying" old entries on reload). That filtering turned out to
  /// actively cause a real bug -- and buys nothing, because every action
  /// handler already re-validates the current `game_state` before doing
  /// anything (spec.md's own "reject inapplicable actions" rule), so
  /// reprocessing something that was already handled (or manually retried
  /// by writing a fresh value into an old, un-deleted key -- Firebase
  /// reports that as `onChildChanged`, which a `startAfter`-filtered
  /// `onChildAdded` alone would silently miss) is a harmless no-op: it
  /// fails its own state check and gets deleted like anything else. Simpler
  /// and more self-healing than the filtered version -- any stuck action
  /// now gets swept up the next time this reloads, with no extra app code
  /// needed to specifically detect that case.
  Stream<MapEntry<String, String>> watchNewActionNames() {
    return _database
        .ref('actions')
        .orderByKey()
        .onChildAdded
        .map((event) {
          final key = event.snapshot.key;
          final value = event.snapshot.value;
          if (key == null || value is! String) return null;
          return MapEntry(key, value);
        })
        .where((event) => event != null)
        .cast<MapEntry<String, String>>();
  }

  /// Removes a handled action. Actions are one-shot commands: once this
  /// admin engine has decided what to do about one (applied it, or
  /// rejected it as inapplicable to the current state), it's done -- there
  /// is no retry/replay mechanism that would need it to stick around.
  Future<void> deleteAction(String key) {
    return _database.ref('actions/$key').remove();
  }


  /// The `lobby -> next_game -> dealing` transition (spec.md section 3 /
  /// implementation-plan.md admin state machine): picks a new `game_id`,
  /// the game's winning pattern (spec.md: "determines the winning pattern
  /// for the game (from the seed)"), and records how many players are
  /// registered for this round (`game/player_count`) -- the stage needs
  /// that fixed total to show "Dealing tabla %d of %d" progress, since
  /// `players/<uid>` entries themselves don't exist yet: a player's node is
  /// only created once their tabla is actually dealt (see
  /// [dealTablaToPlayer]), rather than pre-created as an empty
  /// participation placeholder. `players` is explicitly cleared here too --
  /// every *normal* round-end path already clears it (`abortToLobby`), but
  /// nothing enforces that before a round can start, so any leftover
  /// entries (a manually-poked test UID, a future bug in some other reset
  /// path) would otherwise silently carry into the new round, inflating the
  /// stage's dealt-count past the real `player_count` for this round. One
  /// atomic multi-path update, so no client ever observes a
  /// partially-applied transition.
  Future<void> applyNextGameFromLobby({
    required int newGameId,
    required String winningPattern,
    required int playerCount,
  }) {
    final updates = <String, Object?>{
      'game_state': GameState.dealing.name,
      'game/game_id': newGameId,
      'game/claiming_uid': null,
      'game/winning_pattern': winningPattern,
      'game/player_count': playerCount,
      'players': null,
    };
    return _database.ref().update(updates);
  }

  /// Deals one player's tabla (spec.md: "generates a tabla card ... and
  /// writes that `tabla_id` to the player's part of the database"). A
  /// player's own UID is used as their `tabla_id` -- simplest scheme that
  /// needs no separate ID generation, and matches the shared `Tabla`
  /// seeding design (`shared/lib/src/tabla.dart`), which already assumes
  /// `tabla_id` reused across games (as a stable per-player value like a
  /// UID would be) still yields a different board per game because
  /// `game_id` is also part of the seed.
  ///
  /// This is what actually creates `players/<uid>` -- there's no separate
  /// "joined" placeholder written earlier, so a player's node existing at
  /// all means their tabla has been dealt.
  Future<void> dealTablaToPlayer(String uid) {
    return _database.ref('players/$uid/tabla_id').set(uid);
  }

  /// The current game's `game_id` -- stored as a genuine number (spec.md:
  /// "picks a random game id (the seed)"), not a string, since it *is* a
  /// PRNG seed (`Random(int)` takes one directly -- see `draw_order.dart`).
  /// Needed, together with a player's own UID as their `tabla_id`, to
  /// reconstruct their dealt tabla via `Tabla` -- e.g. to render it while
  /// dealing.
  Future<int?> fetchGameId() async {
    final snapshot = await _database.ref('game/game_id').get();
    return (snapshot.value as num?)?.toInt();
  }

  /// How many of the current game's registered players have a `tabla_id`
  /// yet (a `players/<uid>` node existing at all means dealt -- see
  /// [dealTablaToPlayer]), out of how many are registered total
  /// (`game/player_count`) -- the `start_drawing` action's "all tablas
  /// assigned" validation.
  Future<({int dealt, int total})> fetchDealingProgress() async {
    final results = await Future.wait([
      _database.ref('game/player_count').get(),
      _database.ref('players').get(),
    ]);
    final total = results[0].value as int? ?? 0;
    final playersValue = results[1].value;
    final dealt = playersValue is Map ? playersValue.length : 0;
    return (dealt: dealt, total: total);
  }

  /// The full set of dealt player UIDs, re-emitted on every `players`
  /// change -- the stage's "Dealing tabla %d of %d" progress counter uses
  /// its length directly, and its per-player flying-tabla animation diffs
  /// each new snapshot against the previous one to catch just the new
  /// arrivals. Deliberately `onValue`, not `onChildAdded`: an
  /// `onChildAdded` listener replays its *entire* backlog as "just added"
  /// the moment it attaches, so a screen reload (or any stale/leftover
  /// `players` entry that somehow wasn't cleared) gets miscounted as
  /// freshly dealt. `onValue` always reflects the true current set.
  Stream<List<String>> watchDealtPlayerUids() {
    return _database.ref('players').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const [];
      return value.keys.map((key) => key.toString()).toList();
    });
  }

  /// The `dealing -> start_drawing -> drawing` transition: flips the state
  /// and starts `game/draw_count` at 0 -- the single authoritative cursor
  /// [DrawLoopEngine] advances every draw, and everything else (the current
  /// card, the drawn-so-far history) is deterministically recomputed from
  /// it plus `game_id` (see `draw_order.dart`), never separately stored.
  /// One atomic multi-path update, so no client ever observes a
  /// partially-applied transition.
  Future<void> startDrawing() {
    final updates = <String, Object?>{
      'game_state': GameState.drawing.name,
      'game/draw_count': 0,
    };
    return _database.ref().update(updates);
  }

  /// How many cards have been drawn so far this round -- see
  /// [startDrawing].
  Future<int> fetchDrawCount() async {
    final snapshot = await _database.ref('game/draw_count').get();
    return snapshot.value as int? ?? 0;
  }

  /// Live version of [fetchDrawCount], for the stage display.
  Stream<int> watchDrawCount() {
    return _database.ref('game/draw_count').onValue.map((event) {
      return event.snapshot.value as int? ?? 0;
    });
  }

  /// Advances the draw cursor by one -- [DrawLoopEngine]'s per-tick write.
  /// Read-then-write (not a Firebase transaction): safe because this admin
  /// app is the sole writer of `game/draw_count`, same "only one host"
  /// assumption the rest of this class already relies on.
  Future<void> incrementDrawCount() async {
    final current = await fetchDrawCount();
    await _database.ref('game/draw_count').set(current + 1);
  }

  /// `pause`/`resume` (spec.md: "the host can pause and resume the
  /// drawing"). Implemented as a `game_state` flip to/from `paused` (not a
  /// `game.paused` flag) -- see `GameState`'s own doc comment for why.
  Future<void> pauseDrawing() {
    return _database.ref('game_state').set(GameState.paused.name);
  }

  Future<void> resumeDrawing() {
    return _database.ref('game_state').set(GameState.drawing.name);
  }

  /// The claiming player's UID, or null/empty when no claim is pending
  /// (spec.md: players write their own UID here; only ever cleared by the
  /// admin). [ClaimEngine] watches this to detect new claims.
  Stream<String?> watchClaimingUid() {
    return _database.ref('game/claiming_uid').onValue.map((event) {
      final value = event.snapshot.value;
      return value is String && value.isNotEmpty ? value : null;
    });
  }

  /// One-time version of [watchClaimingUid] -- who's being resolved at
  /// `winner`/`cheater` time ([ResolutionEngine]), or shown on the
  /// checking/winner/celebrate stage screens at mount.
  Future<String?> fetchClaimingUid() async {
    final snapshot = await _database.ref('game/claiming_uid').get();
    final value = snapshot.value;
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<String?> fetchTablaId(String uid) async {
    final snapshot = await _database.ref('players/$uid/tabla_id').get();
    return snapshot.value as String?;
  }

  Future<bool> isBlocked(String uid) async {
    final snapshot = await _database.ref('blocked_uids/$uid').get();
    return snapshot.value != null;
  }

  /// `drawing -> claiming` (spec.md: a valid claim "pauses card drawing" by
  /// moving out of `drawing`; [DrawLoopEngine] already stops on any
  /// non-`drawing` state, so this state flip alone is the pause).
  Future<void> beginClaiming() {
    return _database.ref('game_state').set(GameState.claiming.name);
  }

  /// `claiming -> check -> checking`. Just the state flip.
  Future<void> setChecking() {
    return _database.ref('game_state').set(GameState.checking.name);
  }

  /// `checking -> resolve -> winner`. Just the state flip -- called by
  /// [AdminEngine]'s single `resolve` handler once it's looked up the
  /// already-known claim outcome (see [fetchLatestClaimAccepted]).
  /// [ResolutionEngine] writes the actual `winner_log` entry and moves on
  /// to `celebrate` automatically shortly after (spec.md's transition
  /// table: `finalize_winner` is a separate trigger, from "admin process
  /// (stage)", not the host).
  Future<void> resolveWinner() {
    return _database.ref('game_state').set(GameState.winner.name);
  }

  /// `checking -> resolve -> cheater`. Just the state flip -- the other
  /// branch of the same `resolve` handler as [resolveWinner].
  /// [ResolutionEngine] runs the countdown and does the actual
  /// block/clear/resume afterward (spec.md: "counts down from 5 or 10").
  Future<void> resolveCheater() {
    return _database.ref('game_state').set(GameState.cheater.name);
  }

  /// Appends one entry to the append-only `winner_log` (spec.md section 4:
  /// "game_id, tabla_id, player_uid"). `draw_count` (see [appendClaimLog])
  /// is the same value the winning claim itself was checked against --
  /// `draw_count` is frozen the moment `game_state` leaves `drawing`, so
  /// it's still accurate to fetch fresh here rather than threading it
  /// through from the original claim.
  Future<void> appendWinnerLog({
    required int gameId,
    required String tablaId,
    required String playerUid,
    required int drawCount,
  }) {
    return _database.ref('winner_log').push().set({
      'game_id': gameId,
      'tabla_id': tablaId,
      'player_uid': playerUid,
      'draw_count': drawCount,
    });
  }

  /// `winner -> finalize_winner -> celebrate`. Just the state flip; the
  /// `winner_log` write itself is [appendWinnerLog].
  Future<void> beginCelebrate() {
    return _database.ref('game_state').set(GameState.celebrate.name);
  }

  /// `<any in-progress state> -> next_game -> lobby`: the host's universal
  /// bail-out, not just the `celebrate -> lobby` round-reset path (spec.md
  /// originally only describes that one explicitly, but the same "clear the
  /// round and go back to lobby" effect is what a host needs from *any*
  /// stuck or unwanted state -- e.g. an exhausted deck with no winner,
  /// mid-dealing, or a claim gone sideways). Clears `players` and
  /// `blocked_uids` (implementation-plan.md: "cleared every round") and any
  /// lingering `claiming_uid`. `claim_log`/`winner_log` are untouched --
  /// spec.md: "continuous streams across sessions". One atomic multi-path
  /// update.
  Future<void> abortToLobby() {
    final updates = <String, Object?>{
      'game_state': GameState.lobby.name,
      'players': null,
      'blocked_uids': null,
      'game/claiming_uid': null,
    };
    return _database.ref().update(updates);
  }

  /// Appends one entry to the append-only `claim_log` (spec.md section 4:
  /// "game_id, tabla_id, player_uid, result"), written once per claim
  /// regardless of outcome. `draw_count` (how many cards were on the board
  /// at claim time -- beyond spec.md's own field list) supports later
  /// analysis of how many cards it typically takes to reach a win/claim at
  /// different player counts.
  Future<void> appendClaimLog({
    required int gameId,
    required String tablaId,
    required String playerUid,
    required bool accepted,
    required int drawCount,
  }) {
    return _database.ref('claim_log').push().set({
      'game_id': gameId,
      'tabla_id': tablaId,
      'player_uid': playerUid,
      'result': accepted ? 'accepted' : 'rejected',
      'draw_count': drawCount,
    });
  }

  /// Whether any claim has already been rejected this round -- the "first
  /// invalid claim in the game" grace (spec.md: only the first invalid
  /// claim gets a stage-visible false-claim flow; later ones are silently
  /// rejected). `claim_log` spans every round ever played (spec.md:
  /// "continuous streams across sessions"), so this fetches the whole node
  /// and filters to [gameId] in Dart rather than needing an indexed
  /// `orderByChild` query (and the `.indexOn` rule that would require).
  Future<bool> hasAnyRejectedClaimThisGame(int gameId) async {
    final snapshot = await _database.ref('claim_log').get();
    final value = snapshot.value;
    if (value is! Map) return false;
    return value.values.whereType<Map>().any(
      (entry) => entry['game_id'] == gameId && entry['result'] == 'rejected',
    );
  }

  /// Whether the current claim (matching [gameId] and [playerUid]) was
  /// found valid when it came in. `ClaimEngine` already computed and logged
  /// this the moment the claim arrived (patch-plans/001: the single
  /// `resolve` action has no separate winner/cheater input from the host,
  /// so the admin engine re-derives the outcome from here instead of being
  /// told it directly). Push IDs sort chronologically, so the
  /// lexicographically greatest matching key is the most recent claim.
  Future<bool> fetchLatestClaimAccepted({
    required int gameId,
    required String playerUid,
  }) async {
    final snapshot = await _database.ref('claim_log').get();
    final value = snapshot.value;
    if (value is! Map) return false;

    String? latestKey;
    Object? latestResult;
    for (final entry in value.entries) {
      final data = entry.value;
      if (data is! Map) continue;
      if (data['game_id'] != gameId || data['player_uid'] != playerUid) {
        continue;
      }
      final key = entry.key as String;
      if (latestKey == null || key.compareTo(latestKey) > 0) {
        latestKey = key;
        latestResult = data['result'];
      }
    }
    return latestResult == 'accepted';
  }

  Future<void> blockPlayer(String uid) {
    return _database.ref('blocked_uids/$uid').set(true);
  }

  /// Host-triggered manual reset of `blocked_uids` (implementation-plan.md
  /// parking-lot item) -- independent of `game_state`/[abortToLobby], which
  /// already clears the blocklist every round automatically; this just lets
  /// the host also do it mid-round, e.g. after resolving a mistaken block.
  Future<void> clearBlockedUids() {
    return _database.ref('blocked_uids').remove();
  }

  Future<void> clearClaimingUid() {
    return _database.ref('game/claiming_uid').remove();
  }

  // implementation-plan.md v2 TODO: `settings/*`, written by the remote
  // control app, read here with the TODO's own stated defaults so an
  // absent/never-configured settings node behaves exactly like v1 always
  // did.

  /// Whether the stage should play card-name audio (`settings/sound`,
  /// default `"on"`). Live so a change takes effect on the very next draw,
  /// not just the next round.
  Stream<bool> watchSoundEnabled() {
    return _database.ref('settings/sound').onValue.map((event) {
      return event.snapshot.value != 'off';
    });
  }

  /// How many lobby players get copied into a new round
  /// (`settings/max_player_count`, default 1000).
  Future<int> fetchMaxPlayerCount() async {
    final snapshot = await _database.ref('settings/max_player_count').get();
    final value = snapshot.value;
    return value is num ? value.toInt() : 1000;
  }

  /// The pace between card draws (`settings/draw_interval`, milliseconds,
  /// default 5000). Fetched fresh on every draw tick (see
  /// `DrawLoopEngine`) so a change takes effect on the very next card.
  Future<Duration> fetchDrawInterval() async {
    final snapshot = await _database.ref('settings/draw_interval').get();
    final value = snapshot.value;
    final ms = value is num ? value.toInt() : 5000;
    return Duration(milliseconds: ms);
  }
}
