/// Screens the player-app router can be on. This is purely a function of
/// `game_state` (plus tabla-readiness) -- unlike `game_state`, it does NOT
/// depend on `claiming_uid` matching this player. Whether *this* player's
/// screen should flash (spec.md section 3: "while the player's ID is in
/// claiming_uid, the player screen flashes white") is a separate, additive
/// concern layered on top of whichever screen is chosen here -- see
/// `AppStateController.isMyActiveClaim` -- not a distinct screen of its own,
/// so claiming your own Loteria doesn't hide the board, beans, or button
/// underneath.
enum AppScreen {
  /// Anonymous auth hasn't resolved to a UID yet.
  connecting,

  /// `game_state == lobby`.
  lobby,

  /// `game_state != lobby` and this player's `tabla_id`/`game_id` haven't
  /// both arrived yet -- normally that's specifically `dealing` before
  /// `tabla_id` is assigned, but the same screen also covers a reconnect
  /// landing mid-game before those two listeners have caught up (see
  /// `AppStateController.screen`).
  dealingWaitingForTabla,

  /// `game_state == dealing` and `players/<uid>/tabla_id` is present.
  dealingTablaReceived,

  /// `game_state == drawing`.
  drawing,

  /// `game_state == claiming`.
  claiming,

  /// `game_state == checking`.
  checking,

  /// `game_state == cheater`. Not called out separately in the player
  /// screen-state table (implementation-plan.md); treated like the other
  /// "someone else is being resolved, just show my tabla" states.
  cheater,

  /// `game_state == winner` or `game_state == celebrate`.
  winnerOrCelebrate,
}
