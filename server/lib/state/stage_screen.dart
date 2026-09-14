/// Screens the stage router can be on -- one per `game_state` value, plus
/// `connecting` for before the first snapshot arrives. Unlike the player
/// app's screen enum, no derived sub-states are needed here: which screen
/// to show is a direct function of `game_state` alone. Each screen's real
/// content is built out in its own later phase (A3 onward); for A2 they're
/// placeholders that prove the routing decisions.
enum StageScreen {
  connecting,
  lobby,
  dealing,
  drawing,
  paused,
  claiming,
  checking,
  cheater,
  winner,
  celebrate,
}
