/// The literal `game_state` variant names, straight from spec.md sections
/// 3-4 plus the explicit `paused` addition for this project: "No persisted
/// `paused` field in `game`, a paused game is in `game_state` = `paused`"
/// (not a `game.paused` flag).
///
/// This is a cross-app contract: the stage/admin app is the only writer,
/// but the player app and the stage app both read these exact strings.
/// Living in this shared package (rather than being copy-defined in both
/// apps) is what keeps them from drifting apart -- which already happened
/// once (the player app's copy didn't have `paused`) before this package
/// existed.
enum GameState {
  lobby,
  dealing,
  drawing,
  paused,
  claiming,
  checking,
  cheater,
  winner,
  celebrate;

  static GameState? fromRaw(Object? raw) {
    if (raw is! String) return null;
    for (final value in GameState.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
