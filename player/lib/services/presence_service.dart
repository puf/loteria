import 'package:firebase_database/firebase_database.dart';

/// SHARED: the `lobby/<uid>` path is part of the database schema contract
/// the host/admin process also reads (spec.md section 4) when it copies
/// player IDs out of the lobby to start a game.
///
/// Writes and maintains this player's presence at `lobby/<uid>`.
///
/// Per spec.md section 4 / implementation-plan.md: write `true` on connect,
/// and register an `onDisconnect` handler so the database removes the entry
/// if the player's connection drops.
class PresenceService {
  PresenceService(this._database);

  final FirebaseDatabase _database;

  Future<void> markPresent(String uid) async {
    final ref = _database.ref('lobby/$uid');
    await ref.onDisconnect().remove();
    await ref.set(true);
  }
}
