import 'dart:math';

import 'loteria_card.dart';

/// SHARED: this whole class -- the seed formula in [_seedFrom], the
/// `'$gameId:$tablaId'` combination, and the shuffle-then-take-16 logic in
/// [_generate] -- is a cross-app contract between the player app and the
/// stage/admin app. The admin process reproduces this exact algorithm, over
/// the exact same [loteriaDeck] order, to independently know a player's
/// tabla -- both to render it while dealing and (later) to validate a
/// claim. Any change here is a breaking change to that contract.
///
/// A player's 4x4 tabla: 16 cards deterministically derived from `game_id`
/// and `tabla_id` together.
///
/// The only things ever written to the database for a player's tabla are
/// `game/game_id` and `players/<uid>/tabla_id` (spec.md section 4) -- there
/// is no separate path carrying the actual 16 cards. Mirroring how
/// implementation-plan.md derives the card *draw order* from `game_id` as a
/// PRNG seed, this derives the tabla *layout* the same way, purely from
/// those two IDs: a seeded shuffle of the 54-card deck, taking the first
/// 16, filled row-major into a 4x4 grid. Both IDs feed the seed (not
/// `tabla_id` alone) so that a `tabla_id` reused across games (the admin
/// app uses each player's own UID as their `tabla_id` -- see
/// `server/lib/services/game_repository.dart`) still produces a different
/// board each game.
class Tabla {
  Tabla({required this.gameId, required this.tablaId})
    : cards = _generate(gameId, tablaId);

  final String gameId;
  final String tablaId;

  /// 16 cards, row-major (index 0..3 is row 0, 4..7 is row 1, etc).
  final List<LoteriaCard> cards;

  LoteriaCard cardAt(int row, int col) => cards[row * 4 + col];

  static List<LoteriaCard> _generate(String gameId, String tablaId) {
    final shuffled = List<LoteriaCard>.of(loteriaDeck)
      ..shuffle(Random(_seedFrom('$gameId:$tablaId')));
    return shuffled.take(16).toList(growable: false);
  }

  /// A deterministic seed for [combined], independent of Dart's unspecified
  /// `Object.hashCode` (a simple polynomial hash over the string's UTF-16
  /// code units).
  static int _seedFrom(String combined) {
    var hash = 0;
    for (final codeUnit in combined.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    return hash;
  }
}
