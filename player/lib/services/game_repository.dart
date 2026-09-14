import 'package:firebase_database/firebase_database.dart';

import 'package:loteria_shared/loteria_shared.dart';

/// SHARED: the path strings and field names below (`game_state`, `game`,
/// `game_id`, `claiming_uid`, `players/<uid>/tabla_id`, `blocked_uids/<uid>`)
/// are the database schema contract with whatever writes them -- the
/// host/admin process -- straight from spec.md section 4 /
/// implementation-plan.md "Firebase read paths". They can't be renamed here
/// without a matching change on the writing side.
class GameRepository {
  GameRepository(this._database);

  final FirebaseDatabase _database;

  Stream<GameState?> watchGameState() {
    return _database.ref('game_state').onValue.map((event) {
      return GameState.fromRaw(event.snapshot.value);
    });
  }

  /// The single active `game` object. Player v1 only needs `claiming_uid`
  /// out of it, but the whole node is exposed in case later slices need
  /// other fields (e.g. pause flag).
  Stream<Map<Object?, Object?>?> watchGame() {
    return _database.ref('game').onValue.map((event) {
      final value = event.snapshot.value;
      return value is Map ? value.cast<Object?, Object?>() : null;
    });
  }

  Stream<String?> watchTablaId(String uid) {
    return _database.ref('players/$uid/tabla_id').onValue.map((event) {
      final value = event.snapshot.value;
      return value?.toString();
    });
  }

  Stream<bool> watchBlocked(String uid) {
    return _database.ref('blocked_uids/$uid').onValue.map((event) {
      return event.snapshot.value != null;
    });
  }

  /// Claims Loteria for [uid]. Per spec.md section 4, the database rules
  /// only accept this write when `claiming_uid` is currently empty, the
  /// game state is `drawing`, and `uid` isn't in `blocked_uids` -- so this
  /// can be, and often will be, legitimately rejected. Callers must not
  /// surface that rejection as an error (implementation-plan.md: "keep UI
  /// stable and do not show extra error in v1"); this method just lets the
  /// exception propagate for the caller to swallow.
  Future<void> writeClaim(String uid) {
    return _database.ref('game/claiming_uid').set(uid);
  }
}
