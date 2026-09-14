import 'package:firebase_auth/firebase_auth.dart';

/// Signs the player in anonymously and exposes the current Firebase UID.
///
/// Player auth is anonymous-only (spec.md section 4): there is no
/// email/password or provider sign-in flow to build for v1.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> get userChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Ensures an anonymous user exists, signing one in if needed.
  Future<User> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous sign-in returned a null user.');
    }
    return user;
  }
}
