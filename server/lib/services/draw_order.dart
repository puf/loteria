import 'dart:math';

import 'package:loteria_shared/loteria_shared.dart';

/// The full 54-card draw order for a round, deterministically derived from
/// `game_id` alone (implementation-plan.md: "the card sequence must be
/// derived from the current `game_id` as the PRNG seed"). Combined with
/// `game/draw_count` (the authoritative cursor), this is all that's needed
/// to know the current card (`drawOrderFor(gameId)[drawCount - 1]`) and the
/// full drawn-so-far history -- nothing about *which* cards were drawn is
/// separately stored in Firebase, only the count.
///
/// `game_id` is stored as a genuine number specifically so it can seed
/// `Random` directly here, with no string-hashing step needed (unlike
/// `Tabla`'s seed, which must also fold in a player's UID -- always a
/// string -- so it can't avoid one).
///
/// Admin-only (server-app-local, not in `shared/`): unlike `Tabla`, no
/// other app independently recomputes this to cross-check it against
/// something -- only this app ever generates or reads the draw sequence.
List<LoteriaCard> drawOrderFor(int gameId) {
  return List<LoteriaCard>.of(loteriaDeck)..shuffle(Random(gameId));
}
